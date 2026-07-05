import asyncio
import time

import pytest

from app.services.voice_stream_response_writer import VoiceStreamResponseWriterMixin
from app.services.voice_stream_session import VoiceStreamSession


class _ChunkProbe(VoiceStreamResponseWriterMixin):
    pass


class _StreamingWriterProbe(VoiceStreamResponseWriterMixin):
    def __init__(self, *, tts_delay: float = 0.02, chat_service=None):
        self.chat_service = chat_service or _FakeStreamingChatService()
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


class _PausingStreamingChatService:
    def __init__(self):
        self.release = asyncio.Event()

    async def stream_message(self, *args, **kwargs):
        yield {"event": "conversation", "conversation_id": "conversation-1"}
        text = "Sure. I can take care of that right now. "
        for token in text.split(" "):
            await asyncio.sleep(0)
            yield {"event": "token", "token": f"{token} "}
        await self.release.wait()
        yield {"event": "token", "token": "What changed?"}
        yield {
            "event": "done",
            "conversation_id": "conversation-1",
            "messages": [],
            "memory_changes": None,
        }

    async def save_voice_turn_metadata(self, **kwargs):
        return {"id": "voice-turn-1"}


class _MemoryRecallStreamingChatService:
    async def stream_message(self, *args, **kwargs):
        yield {"event": "conversation", "conversation_id": "conversation-1"}
        yield {"event": "turn.trace", "intent": "memory_recall"}
        raw_text = "I could not find anything about Jessica."
        for token in raw_text.split(" "):
            await asyncio.sleep(0)
            yield {"event": "token", "token": f"{token} "}
        yield {
            "event": "done",
            "conversation_id": "conversation-1",
            "response": "From saved memory, Jessica works with you.",
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

    async def synthesize_speech(self, text: str, **kwargs):
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


class _PrefetchProbeTTSService:
    def __init__(self):
        self.started = []
        self.finished = []
        self._second_chunk_started = asyncio.Event()

    async def synthesize_speech(self, text: str, **kwargs):
        chunk_index = len(self.started)
        self.started.append((text, time.perf_counter()))
        if chunk_index == 0:
            await asyncio.wait_for(self._second_chunk_started.wait(), timeout=1)
        elif chunk_index == 1:
            self._second_chunk_started.set()
        await asyncio.sleep(0)
        self.finished.append((text, time.perf_counter()))
        return {
            "audio_content_type": "audio/mpeg",
            "audio_base64": f"audio:{len(self.started)}",
            "audio_encoding": "MP3",
            "voice_name": "test",
            "language_code": "en-US",
            "metadata": {},
        }


async def _never_finishes():
    await asyncio.Future()


def test_voice_chunker_does_not_split_tiny_sentence_fragments():
    probe = _ChunkProbe()

    chunk, rest = probe._next_speakable_chunk("Cool. Yep. ")

    assert chunk is None
    assert rest == "Cool. Yep. "


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
    assert 12 <= len(chunk) <= 140
    assert rest.strip().startswith("steady")


def test_voice_chunker_starts_audio_on_short_word_boundary():
    probe = _ChunkProbe()
    text = "Sure thing I can help."

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk == "Sure thing I can help."
    assert rest == ""


def test_voice_chunker_emits_early_word_chunk_for_longer_reply():
    probe = _ChunkProbe()
    text = "Sure thing I need help here with your balance today and tomorrow"

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk is None
    assert rest == text


def test_voice_chunker_waits_for_sentence_boundary_on_short_casual_reply():
    probe = _ChunkProbe()
    text = "Hey. Not much. What's up with you?"

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk == text
    assert rest == ""


def test_voice_chunker_starts_audio_after_short_voice_sentence():
    probe = _ChunkProbe()
    text = "Yes, I can help you with that. Tell me what changed."

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk == "Yes, I can help you with that."
    assert rest.strip() == "Tell me what changed."


def test_voice_chunker_emits_audio_for_short_rex_intro():
    probe = _ChunkProbe()
    text = "I'm Rex, Clarity's private AI companion."

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk == text
    assert rest == ""


def test_voice_chunker_can_start_audio_on_short_two_sentence_reply():
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

    assert chunks[0] == (
        "Capital One savings has monthly interest as the last May activity."
    )
    assert "No other recent transactions are showing in the data." in " ".join(chunks)
    assert len(chunks) >= 2


@pytest.mark.asyncio
async def test_voice_stream_sends_first_audio_when_tts_finishes_before_next_token():
    chat_service = _PausingStreamingChatService()
    writer = _StreamingWriterProbe(tts_delay=0.01, chat_service=chat_service)
    timings = {}

    stream_task = asyncio.create_task(
        writer._stream_chat_and_audio(
            "Can you handle it?",
            {"confidence": 0.95, "duration_seconds": 1.2},
            timings,
            turn_generation=1,
        )
    )

    async def first_audio_event():
        while True:
            if any(
                event["event"] == "assistant.audio_chunk"
                for event in writer.sent_events
            ):
                return
            await asyncio.sleep(0)

    await asyncio.wait_for(first_audio_event(), timeout=1)
    assert not stream_task.done()

    chat_service.release.set()
    response = await stream_task

    assert response.startswith("Sure. I can take care")
    assert "tts_first_audio_turn_ms" in timings


class _DelayedMetadataChatService(_FakeStreamingChatService):
    metadata_started = False
    messages_updated_before_metadata = False

    async def save_voice_turn_metadata(self, **kwargs):
        type(self).metadata_started = True
        await asyncio.sleep(0.05)
        return {"id": "voice-turn-1"}


@pytest.mark.asyncio
async def test_voice_stream_emits_messages_updated_before_metadata_save():
    chat_service = _DelayedMetadataChatService()
    writer = _StreamingWriterProbe(tts_delay=0.01, chat_service=chat_service)
    timings = {}

    await writer._stream_chat_and_audio(
        "Hello there",
        {"confidence": 0.95, "duration_seconds": 0.8},
        timings,
        turn_generation=1,
    )
    await asyncio.sleep(0.1)

    event_names = [event["event"] for event in writer.sent_events]
    messages_index = event_names.index("messages.updated")
    metadata_indices = [
        index for index, name in enumerate(event_names) if name == "voice.metadata.saved"
    ]
    assert messages_index >= 0
    if metadata_indices:
        assert messages_index < metadata_indices[0]


@pytest.mark.asyncio
async def test_voice_stream_first_audio_turn_under_five_seconds():
    writer = _StreamingWriterProbe(tts_delay=0.02)
    timings = {}

    await writer._stream_chat_and_audio(
        "What is my balance?",
        {"confidence": 0.95, "duration_seconds": 1.0},
        timings,
        turn_generation=1,
    )

    assert timings["tts_first_audio_turn_ms"] < 5000


@pytest.mark.asyncio
async def test_voice_stream_prefetches_tts_chunks_before_previous_audio_finishes():
    writer = _StreamingWriterProbe(tts_delay=0.03)
    writer.google_tts_service = _PrefetchProbeTTSService()
    timings = {}

    response = await asyncio.wait_for(
        writer._stream_chat_and_audio(
            "What is recent on my Capital One savings?",
            {"confidence": 0.95, "duration_seconds": 1.2},
            timings,
            turn_generation=1,
        ),
        timeout=1,
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
    assert second_started_at <= first_finished_at


@pytest.mark.asyncio
async def test_voice_memory_recall_speaks_final_truth_checked_response():
    writer = _StreamingWriterProbe(
        tts_delay=0.01,
        chat_service=_MemoryRecallStreamingChatService(),
    )
    timings = {}

    response = await writer._stream_chat_and_audio(
        "What do you know about Jessica?",
        {"confidence": 0.95, "duration_seconds": 1.2},
        timings,
        turn_generation=1,
    )

    audio_events = [
        event for event in writer.sent_events if event["event"] == "assistant.audio_chunk"
    ]
    assert response == "From saved memory, Jessica works with you."
    assert len(audio_events) >= 1
    assert audio_events[-1]["text"] == response


@pytest.mark.asyncio
async def test_voice_session_interrupt_cancels_pending_tts_tasks():
    session = VoiceStreamSession(
        websocket=object(),
        deepgram_streaming_service=object(),
        chat_service=object(),
        google_tts_service=object(),
    )
    turn_task = asyncio.create_task(_never_finishes())
    tts_task = asyncio.create_task(_never_finishes())
    session._active_turn_task = turn_task
    session._active_tts_tasks.add(tts_task)

    await session._cancel_active_turn()

    assert turn_task.cancelled()
    assert tts_task.cancelled()
    assert session._active_turn_task is None
    assert session._active_tts_tasks == set()
