import asyncio
import time

import pytest

from app.services.voice_stream_response_writer import VoiceStreamResponseWriterMixin


class _ChunkProbe(VoiceStreamResponseWriterMixin):
    pass


class _StreamingWriterProbe(VoiceStreamResponseWriterMixin):
    def __init__(self, *, tts_delay: float = 0.02):
        self.chat_service = _FakeStreamingChatService()
        self.google_tts_service = _DelayedTTSService(tts_delay)
        self.conversation_id = "conversation-1"
        self.financial_context = None
        self.input_mime_type = "audio/linear16"
        self._session_id = "session-1"
        self.sent_events = []
        self.usage_tracking_service = None
        self.user_id = None

    async def _send_event(self, event: str, **payload):
        self.sent_events.append({"event": event, **payload})

    def _elapsed_ms(self, started):
        return int((time.perf_counter() - started) * 1000)


class _FakeStreamingChatService:
    async def stream_message(self, *args, **kwargs):
        yield {"event": "conversation", "conversation_id": "conversation-1"}
        text = (
            "Capital One savings has monthly interest as the last May activity. "
            "No other recent transactions are showing in the data. "
            "Your checking account has groceries as the latest purchase. "
            "That is all I can see right now."
        )
        for token in text.split(" "):
            await asyncio.sleep(0)
            yield {"event": "token", "token": f"{token} "}
        yield {
            "event": "done",
            "conversation_id": "conversation-1",
            "messages": [],
            "memory_changes": None,
        }

    async def save_voice_turn_metadata(self, **kwargs):
        return {"id": "voice-turn-1"}


class _DelayedTTSService:
    def __init__(self, delay: float):
        self.delay = delay
        self.started = []
        self.finished = []

    async def synthesize_speech(self, text: str):
        self.started.append((text, time.perf_counter()))
        await asyncio.sleep(self.delay)
        self.finished.append((text, time.perf_counter()))
        return {
            "audio_content_type": "audio/mpeg",
            "audio_base64": f"audio:{len(self.started)}",
            "audio_encoding": "MP3",
            "voice_name": "test",
            "language_code": "en-US",
            "metadata": {},
        }


def test_voice_chunker_does_not_split_short_sentence_fragments():
    probe = _ChunkProbe()

    chunk, rest = probe._next_speakable_chunk("Cool. I can help with that. ")

    assert chunk is None
    assert rest == "Cool. I can help with that. "


def test_voice_chunker_splits_at_substantial_sentence_boundary():
    probe = _ChunkProbe()
    text = (
        "Got it, you are canceling the movie because money is tight tonight. "
        "I can help you keep the evening simple."
    )

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk == (
        "Got it, you are canceling the movie because money is tight tonight."
    )
    assert rest.strip() == "I can help you keep the evening simple."


def test_voice_chunker_uses_word_boundary_for_long_text_without_punctuation():
    probe = _ChunkProbe()
    text = " ".join(["steady"] * 45)

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk is not None
    assert 36 <= len(chunk) <= 140
    assert rest.strip().startswith("steady")


def test_voice_chunker_starts_audio_after_short_voice_sentence():
    probe = _ChunkProbe()
    text = "Yes, I can help you with that. Tell me what changed."

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk == "Yes, I can help you with that. Tell me what changed."
    assert rest == ""


def test_voice_chunker_uses_fewer_chunks_for_short_two_sentence_reply():
    probe = _ChunkProbe()
    text = (
        "Capital One savings has monthly interest as the last May activity. "
        "No other recent transactions are showing in the data."
    )

    chunks = []
    buffer = ""
    for token in text.split(" "):
        buffer += f"{token} "
        chunk, buffer = probe._next_speakable_chunk(buffer)
        if chunk:
            chunks.append(chunk)
    if buffer.strip():
        chunks.append(buffer.strip())

    assert chunks == [text]


@pytest.mark.asyncio
async def test_voice_stream_prefetches_tts_chunks_before_previous_audio_finishes():
    writer = _StreamingWriterProbe(tts_delay=0.03)
    timings = {}

    response = await writer._stream_chat_and_audio(
        "What is recent on my Capital One savings?",
        {"confidence": 0.95, "duration_seconds": 1.2},
        timings,
    )

    audio_events = [
        event for event in writer.sent_events if event["event"] == "assistant.audio_chunk"
    ]
    assert response.startswith("Capital One savings")
    assert len(audio_events) >= 2
    assert timings["tts_chunk_count"] == len(audio_events)
    assert "tts_first_audio_turn_ms" in timings
    first_finished_at = writer.google_tts_service.finished[0][1]
    second_started_at = writer.google_tts_service.started[1][1]
    assert second_started_at < first_finished_at
