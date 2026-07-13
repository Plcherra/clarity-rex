import asyncio
import logging
from datetime import datetime
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient

import app.services.voice_stream_session as voice_stream_session_module
from app.main import app
from app.services.deepgram_service import DeepgramServiceError
from app.services.google_tts_service import GoogleTTSServiceError
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_channel import RexBrainChannel
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService
from app.services.voice_stream_session import VoiceStreamSession
from durable_write_test_helpers import (
    assert_mom_birthday_person_entity,
    assert_self_location_person_entity,
)
from voice_stream_async_client import (
    async_confirm_voice_proposal,
    async_voice_client,
    async_voice_websocket_turn,
)
from voice_stream_fakes import (
    FakeChatService,
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
    FakeUsageTrackingService,
    FakeLiveDeepgramStreamingService,
    FakeLiveTranscription,
    FakeWebSocket,
    SlowDeepgramStreamingService,
    override_services,
    receive_until,
)


@pytest.fixture
def client():
    app.dependency_overrides.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def _fixed_time_context_service():
    return TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: datetime(
            2026,
            6,
            1,
            12,
            0,
            tzinfo=ZoneInfo("America/New_York"),
        ),
    )


def _real_chat_service(ai_service=None, memory_service=None):
    return ChatService(
        ai_service or FakeAIService(),
        FileService(),
        memory_service or FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )


@pytest.mark.asyncio
async def test_voice_stream_saves_direct_memory_through_real_chat_service(
    caplog,
):
    async with async_voice_client() as client:
        caplog.set_level(logging.INFO, logger="rex.voice_stream")
        ai_service = FakeAIService()
        memory_service = FakeMemoryService()
        chat = _real_chat_service(ai_service, memory_service)
        tts = FakeGoogleTTSService()

        proposed, _ = await async_voice_websocket_turn(
            client,
            chat,
            "My mom's birthday is June 18",
            deepgram=FakeDeepgramStreamingService(
                transcript="My mom's birthday is June 18",
                partial_transcript="My mom",
            ),
            tts=tts,
        )
        assert proposed["memory_changes"]["confirmation_required"] == 1
        assert memory_service.long_term_memory == []

        saved = await async_confirm_voice_proposal(client, chat, proposed)
        assert saved["memory_changes"]["created"] == 1
        assert saved["timings"]["tts_chunk_count"] == 1

        assert ai_service.generate_calls == 1
        assert ai_service.stream_calls == 0
        assert_mom_birthday_person_entity(memory_service, "June 18")
        assert any(
            "voice_turn_timing" in record.message
            and "intent=memory_save" in record.message
            and "memory_action=none" in record.message
            for record in caplog.records
        )
        assert any(
            "voice_turn_timing" in record.message
            and "memory_action=direct_saved" in record.message
            and "tts_chunk_count=1" in record.message
            for record in caplog.records
        )


@pytest.mark.asyncio
async def test_voice_stream_updates_memory_through_real_chat_service():
    async with async_voice_client() as client:
        ai_service = FakeAIService()
        memory_service = FakeMemoryService()
        memory_service.conversations.add("conversation-existing")
        memory_service.long_term_memory.append(
            {
                "id": "memory-existing",
                "memory_type": "fact",
                "content": "User lives in Summerville, Massachusetts.",
                "importance": 4,
                "metadata": {},
                "active": True,
            }
        )
        chat = _real_chat_service(ai_service, memory_service)

        proposed, _ = await async_voice_websocket_turn(
            client,
            chat,
            "Can you change my location? It's Somerville with one o and one m.",
            "conversation-existing",
            deepgram=FakeDeepgramStreamingService(
                transcript=(
                    "Can you change my location? It's Somerville with one o and one m."
                ),
                partial_transcript="Can you change my location?",
            ),
        )
        assert proposed["memory_changes"]["confirmation_required"] == 1

        updated = await async_confirm_voice_proposal(client, chat, proposed)
        assert updated["memory_changes"]["updated"] == 1
        assert updated["response_text"] == "Rex response"

        assert ai_service.generate_calls == 1
        assert ai_service.stream_calls == 0
        assert_self_location_person_entity(
            memory_service,
            "Somerville, Massachusetts",
        )


def test_voice_stream_completes_streaming_turn(client, caplog):
    caplog.set_level(logging.INFO, logger="rex.voice_stream")
    deepgram = FakeDeepgramStreamingService()
    chat = FakeChatService()
    tts = FakeGoogleTTSService()
    usage = FakeUsageTrackingService()
    override_services(deepgram, chat, tts, usage)

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json(
            {
                "event": "session.start",
                "conversation_id": "conversation-existing",
                "input_mime_type": "audio/linear16",
                "sample_rate": 16000,
            }
        )
        started = websocket.receive_json()
        assert started["event"] == "session.started"
        assert started["conversation_id"] == "conversation-existing"

        websocket.send_bytes(b"pcm-frame-1")
        received = websocket.receive_json()
        assert received["event"] == "audio.received"
        assert received["chunk_count"] == 1

        websocket.send_bytes(b"pcm-frame-2")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        partial = receive_until(websocket, "transcript.partial")
        assert partial["transcript"] == "Hey"

        final = receive_until(websocket, "transcript.final")
        assert final["transcript"] == "Hey Rex"
        assert final["confidence"] == 0.96

        token = receive_until(websocket, "assistant.token")
        assert token["token"] == "Rex "

        audio_chunk = receive_until(websocket, "assistant.audio_chunk")
        assert audio_chunk["text"] == "Rex streaming response."
        assert audio_chunk["audio_base64"] == "bXAzLWJ5dGVz"

        messages = receive_until(websocket, "messages.updated")
        assert messages["conversation_id"] == "conversation-existing"
        assert "voice_metadata" not in messages
        assert [message["conversation_id"] for message in messages["messages"]] == [
            "conversation-existing",
            "conversation-existing",
        ]
        assert [message["role"] for message in messages["messages"]] == [
            "user",
            "assistant",
        ]
        assert [message["content"] for message in messages["messages"]] == [
            "Hey Rex",
            "Rex streaming response.",
        ]

        done = receive_until(websocket, "assistant.done")
        assert done["conversation_id"] == "conversation-existing"
        assert done["response_text"] == "Rex streaming response."
        assert "stt_ms" in done["timings"]
        assert "turn_ms" in done["timings"]
        assert done["timings"]["tts_chunk_count"] >= 1
        assert any(
            "voice_turn_timing" in record.message
            and "stt_ms=" in record.message
            and "turn_ms=" in record.message
            and "intent=casual" in record.message
            and "memory_action=none" in record.message
            and "tts_chunk_count=" in record.message
            for record in caplog.records
        )

        websocket.send_json({"event": "session.end"})
        ended = receive_until(websocket, "session.ended")
        assert ended["event"] == "session.ended"

    assert deepgram.calls == [
        {
            "audio_chunks": [b"pcm-frame-1", b"pcm-frame-2"],
            "content_type": "audio/linear16",
            "sample_rate": 16000,
        }
    ]
    assert chat.stream_calls[0]["message"] == "Hey Rex"
    assert chat.stream_calls[0]["conversation_id"] == "conversation-existing"
    assert chat.stream_calls[0]["response_instructions"] is None
    assert chat.stream_calls[0]["max_response_tokens"] is None
    assert chat.stream_calls[0]["channel"] == RexBrainChannel.VOICE
    assert chat.stream_calls[0]["include_turn_trace"] is True
    assert tts.calls == ["Rex streaming response."]
    assert chat.metadata_calls[0]["conversation_id"] == "conversation-existing"
    assert chat.metadata_calls[0]["user_message_id"] == "user-message-1"
    assert chat.metadata_calls[0]["assistant_message_id"] == "assistant-message-1"
    assert [event["event_type"] for event in usage.events] == [
        "stt",
        "tts",
        "voice_session",
    ]
    assert usage.events[0]["duration_ms"] == 1400
    assert usage.events[1]["status"] == "success"
    assert usage.events[2]["status"] == "completed"


@pytest.mark.parametrize(
    ("transcript", "memory_content", "answer"),
    [
        (
            "Do you know where I'm located?",
            "User lives in Somerville, Massachusetts.",
            "You live in Somerville, Massachusetts.",
        ),
        (
            "What are my plans tonight?",
            "User plans to watch Masters of the Universe tonight.",
            "You plan to watch Masters of the Universe tonight.",
        ),
        (
            "Do you know my mom's birthday?",
            "User's mom's birthday is June 18.",
            "Your mom's birthday is June 18.",
        ),
    ],
)
@pytest.mark.asyncio
async def test_voice_stream_recall_loads_saved_memory_context(
    transcript,
    memory_content,
    answer,
):
    async with async_voice_client() as client:
        ai_service = FakeAIService(stream_tokens=[answer])
        memory_service = FakeMemoryService()
        memory_service.long_term_memory.append(
            {
                "id": "memory-existing",
                "memory_type": "fact",
                "content": memory_content,
                "importance": 4,
                "metadata": {},
                "active": True,
            }
        )
        chat = _real_chat_service(ai_service, memory_service)
        deepgram = FakeDeepgramStreamingService(transcript=transcript)
        override_services(deepgram_streaming_service=deepgram, chat_service=chat)

        done, _ = await async_voice_websocket_turn(client, chat, transcript)

        assert done["response_text"] == answer
        assert done["timings"]["tts_chunk_count"] == 1

        prompt_text = "\n".join(
            str(message["content"]) for message in ai_service.messages
        )
        assert ai_service.stream_calls == 1
        assert memory_content in prompt_text
        assert memory_service.relevant_memory_queries[0]["query"] == transcript


@pytest.mark.asyncio
async def test_voice_stream_live_transcript_idle_starts_turn(monkeypatch):
    async def instant_sleep(_delay):
        return None

    monkeypatch.setattr(voice_stream_session_module.asyncio, "sleep", instant_sleep)
    websocket = FakeWebSocket()
    chat = FakeChatService()
    session = VoiceStreamSession(
        websocket=websocket,
        deepgram_streaming_service=FakeLiveDeepgramStreamingService(),
        chat_service=chat,
        google_tts_service=FakeGoogleTTSService(),
    )
    session.conversation_id = "conversation-existing"
    session._live_transcription = FakeLiveTranscription()
    transcript_timestamp = 10.0
    session._last_live_transcript_at = transcript_timestamp

    await session._process_live_utterance_after_transcript_idle(
        transcript_timestamp,
    )
    assert session._active_turn_task is not None
    await session._active_turn_task

    assert chat.stream_calls[0]["message"] == "Hey Rex"
    assert any(event["event"] == "assistant.done" for event in websocket.events)


@pytest.mark.asyncio
async def test_voice_stream_live_blank_transcription_recovers_as_empty_audio():
    class BlankLiveTranscription:
        async def finish(self):
            return {
                "transcript": "   ",
                "confidence": 0.2,
                "duration_seconds": 0.1,
                "metadata": {"transport": "websocket-live"},
            }

    websocket = FakeWebSocket()
    chat = FakeChatService()
    tts = FakeGoogleTTSService()
    session = VoiceStreamSession(
        websocket=websocket,
        deepgram_streaming_service=FakeLiveDeepgramStreamingService(),
        chat_service=chat,
        google_tts_service=tts,
    )
    session._live_transcription = BlankLiveTranscription()

    await session._process_live_utterance()

    assert websocket.events[-1]["event"] == "error"
    assert websocket.events[-1]["code"] == "empty_audio"
    assert chat.stream_calls == []
    assert tts.calls == []


@pytest.mark.asyncio
async def test_voice_stream_live_transcript_idle_uses_timing_contract(monkeypatch):
    delays = []

    async def capture_sleep(delay):
        delays.append(delay)

    monkeypatch.setattr(voice_stream_session_module.asyncio, "sleep", capture_sleep)
    session = VoiceStreamSession(
        websocket=FakeWebSocket(),
        deepgram_streaming_service=FakeLiveDeepgramStreamingService(),
        chat_service=FakeChatService(),
        google_tts_service=FakeGoogleTTSService(),
    )
    session._live_transcription = FakeLiveTranscription()
    session._last_live_transcript_at = 10.0

    await session._process_live_utterance_after_transcript_idle(10.0)

    assert delays == [1.8]


@pytest.mark.asyncio
@pytest.mark.parametrize("client_name", ["ios_native", "flutter_streaming"])
async def test_voice_stream_client_waits_for_explicit_utterance_end(
    monkeypatch,
    client_name,
):
    async def instant_sleep(_delay):
        return None

    monkeypatch.setattr(voice_stream_session_module.asyncio, "sleep", instant_sleep)
    websocket = FakeWebSocket()
    chat = FakeChatService()
    session = VoiceStreamSession(
        websocket=websocket,
        deepgram_streaming_service=FakeLiveDeepgramStreamingService(),
        chat_service=chat,
        google_tts_service=FakeGoogleTTSService(),
    )
    session.client = client_name
    session.conversation_id = "conversation-existing"
    session._live_transcription = FakeLiveTranscription()

    await session._handle_live_transcript_event(
        {
            "event": "transcript.final",
            "transcript": "what if we change the whole app actually",
            "confidence": 0.9,
            "speech_final": True,
            "metadata": {"vendor": "deepgram"},
        }
    )
    assert session._active_turn_task is None

    session._last_live_transcript_at = 10.0
    await session._process_live_utterance_after_transcript_idle(10.0)
    assert session._active_turn_task is None
    assert chat.stream_calls == []

    await session._receive_text_event('{"event":"utterance.end"}')
    assert session._active_turn_task is not None
    await session._active_turn_task

    assert chat.stream_calls[0]["message"] == "Hey Rex"
    assert any(event["event"] == "assistant.done" for event in websocket.events)


def test_voice_stream_creates_conversation_when_missing_id(client):
    chat = FakeChatService()
    override_services(chat_service=chat)

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        assert websocket.receive_json()["event"] == "session.started"
        websocket.send_bytes(b"pcm-frame")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        done = receive_until(websocket, "assistant.done")
        assert done["conversation_id"] == "conversation-stream"

    assert chat.stream_calls[0]["conversation_id"] is None


@pytest.mark.parametrize(
    ("error", "expected_code", "expected_status", "expected_detail"),
    [
        (
            DeepgramServiceError("Voice transcription is not configured.", 503),
            "transcription_failed",
            503,
            "Voice transcription is not configured.",
        ),
        (
            GoogleTTSServiceError("Voice playback is not configured.", 503),
            "tts_failed",
            503,
            "Voice playback is not configured.",
        ),
    ],
)
def test_voice_stream_sends_error_events(
    client,
    error,
    expected_code,
    expected_status,
    expected_detail,
):
    deepgram = FakeDeepgramStreamingService()
    tts = FakeGoogleTTSService()
    if isinstance(error, DeepgramServiceError):
        deepgram = FakeDeepgramStreamingService(error=error)
    else:
        tts = FakeGoogleTTSService(error=error)
    override_services(deepgram_streaming_service=deepgram, google_tts_service=tts)

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        websocket.receive_json()
        websocket.send_bytes(b"pcm-frame")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        event = receive_until(websocket, "error")
        assert event["code"] == expected_code
        assert event["status_code"] == expected_status
        assert event["detail"] == expected_detail


def test_voice_stream_rejects_empty_utterance(client):
    override_services()

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        event = websocket.receive_json()
        assert event["event"] == "error"
        assert event["code"] == "empty_audio"
        assert event["detail"] == "I did not catch any audio."


def test_voice_stream_rejects_blank_transcription_as_empty_audio(client):
    deepgram = FakeDeepgramStreamingService(transcript="   ", partial_transcript="")
    chat = FakeChatService()
    tts = FakeGoogleTTSService()
    override_services(
        deepgram_streaming_service=deepgram,
        chat_service=chat,
        google_tts_service=tts,
    )

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        websocket.receive_json()
        websocket.send_bytes(b"pcm-frame")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        event = receive_until(websocket, "error")
        assert event["code"] == "empty_audio"
        assert event["detail"] == "I did not catch any audio."

    assert chat.stream_calls == []
    assert tts.calls == []


def test_voice_stream_interrupts_active_turn(client):
    deepgram = SlowDeepgramStreamingService()
    chat = FakeChatService()
    override_services(deepgram_streaming_service=deepgram, chat_service=chat)

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        assert websocket.receive_json()["event"] == "session.started"
        websocket.send_bytes(b"pcm-frame")
        assert websocket.receive_json()["event"] == "audio.received"
        websocket.send_json({"event": "utterance.end"})
        websocket.send_json({"event": "user.interrupt"})

        interrupted = receive_until(websocket, "session.interrupted")
        assert interrupted["event"] == "session.interrupted"

    assert chat.stream_calls == []


@pytest.mark.asyncio
async def test_voice_stream_ignores_trailing_audio_before_assistant_audio():
    websocket = FakeWebSocket()
    session = VoiceStreamSession(
        websocket=websocket,
        deepgram_streaming_service=FakeDeepgramStreamingService(),
        chat_service=FakeChatService(),
        google_tts_service=FakeGoogleTTSService(),
    )
    session._active_turn_task = asyncio.create_task(asyncio.sleep(2))
    session._assistant_audio_started = False

    await session._receive_audio_chunk(b"late-capture-frame")

    assert websocket.events == []
    assert session._audio_chunks == []
    assert session._audio_bytes == 0
    assert session._audio_chunks_received == 0

    await session._cancel_active_turn()


class SequencedDeepgramStreamingService:
    def __init__(self, transcripts):
        self.transcripts = transcripts
        self.calls = []

    async def transcribe_audio_stream(
        self,
        audio_chunks,
        content_type: str,
        sample_rate: int = 16000,
        on_transcript=None,
    ):
        chunks = []
        async for chunk in audio_chunks:
            chunks.append(chunk)
        self.calls.append(
            {
                "audio_chunks": chunks,
                "content_type": content_type,
                "sample_rate": sample_rate,
            }
        )
        transcript = self.transcripts[len(self.calls) - 1]
        if on_transcript is not None:
            await on_transcript(
                {
                    "event": "transcript.partial",
                    "transcript": transcript["partial"],
                    "confidence": 0.7,
                    "metadata": {"vendor": "deepgram"},
                }
            )
        return {
            "transcript": transcript["transcript"],
            "confidence": 0.94,
            "duration_seconds": 0.8,
            "metadata": {"request_id": f"stream-request-{len(self.calls)}"},
        }


class PausingFirstTurnChatService:
    def __init__(self):
        self.stream_calls = []
        self.metadata_calls = []

    async def stream_message(
        self,
        message,
        conversation_id=None,
        file=None,
        response_instructions=None,
        max_response_tokens=None,
        financial_context=None,
        channel=None,
        user_requested_deep_thinking=False,
        include_turn_trace=False,
        locale=None,
        write_confirmation=None,
        user_enabled_proactive_insights=False,
    ):
        self.stream_calls.append(
            {
                "message": message,
                "conversation_id": conversation_id,
                "file": file,
                "response_instructions": response_instructions,
                "max_response_tokens": max_response_tokens,
                "financial_context": financial_context,
                "channel": channel,
                "include_turn_trace": include_turn_trace,
            }
        )
        yield {"event": "conversation", "conversation_id": "conversation-barge-in"}
        if include_turn_trace:
            yield {
                "event": "turn.trace",
                "intent": "casual",
                "channel": "voice",
                "loaded_context": {},
            }
        if len(self.stream_calls) == 1:
            yield {
                "event": "token",
                "token": "Old response is still being spoken now while Rex continues.",
            }
            await asyncio.sleep(2)
            return

        yield {"event": "token", "token": "Fresh "}
        yield {"event": "token", "token": "response."}
        yield {
            "event": "done",
            "conversation_id": "conversation-barge-in",
            "response": "Fresh response.",
            "messages": [
                {
                    "id": "user-message-2",
                    "conversation_id": "conversation-barge-in",
                    "role": "user",
                    "content": message,
                    "timestamp": "2026-05-17T00:00:02Z",
                },
                {
                    "id": "assistant-message-2",
                    "conversation_id": "conversation-barge-in",
                    "role": "assistant",
                    "content": "Fresh response.",
                    "timestamp": "2026-05-17T00:00:03Z",
                },
            ],
        }

    async def save_voice_turn_metadata(self, **kwargs):
        self.metadata_calls.append(kwargs)
        return {"id": "voice-turn-barge-in", **kwargs}


class LongTokenChatService:
    def __init__(self):
        self.stream_calls = []
        self.metadata_calls = []

    async def stream_message(
        self,
        message,
        conversation_id=None,
        file=None,
        response_instructions=None,
        max_response_tokens=None,
        financial_context=None,
        channel=None,
        user_requested_deep_thinking=False,
        include_turn_trace=False,
        locale=None,
        write_confirmation=None,
        user_enabled_proactive_insights=False,
    ):
        self.stream_calls.append(
            {
                "message": message,
                "conversation_id": conversation_id,
                "file": file,
                "response_instructions": response_instructions,
                "max_response_tokens": max_response_tokens,
                "financial_context": financial_context,
                "channel": channel,
                "include_turn_trace": include_turn_trace,
            }
        )
        yield {"event": "conversation", "conversation_id": "conversation-interrupt"}
        if include_turn_trace:
            yield {
                "event": "turn.trace",
                "intent": "casual",
                "channel": "voice",
                "loaded_context": {},
            }
        yield {
            "event": "token",
            "token": "This response will be interrupted before audio can be sent.",
        }
        yield {
            "event": "done",
            "conversation_id": "conversation-interrupt",
            "response": "This response will be interrupted before audio can be sent.",
            "messages": [],
        }

    async def save_voice_turn_metadata(self, **kwargs):
        self.metadata_calls.append(kwargs)
        return {"id": "voice-turn-interrupt", **kwargs}


class SlowGoogleTTSService:
    def __init__(self):
        self.calls = []
        self.started = asyncio.Event()

    async def synthesize_speech(self, text, *, language_code=None):
        self.calls.append(text)
        self.started.set()
        await asyncio.sleep(2)
        return {
            "audio_content_type": "audio/mpeg",
            "audio_base64": "bXAzLWJ5dGVz",
            "audio_encoding": "MP3",
            "voice_name": "en-US-Neural2-J",
            "language_code": "en-US",
            "metadata": {"vendor": "google_tts"},
        }


@pytest.mark.asyncio
async def test_voice_stream_interrupt_cancels_pending_tts_audio():
    websocket = FakeWebSocket()
    tts = SlowGoogleTTSService()
    session = VoiceStreamSession(
        websocket=websocket,
        deepgram_streaming_service=FakeDeepgramStreamingService(),
        chat_service=LongTokenChatService(),
        google_tts_service=tts,
    )

    await session._receive_audio_chunk(b"pcm-frame")
    await session._receive_text_event('{"event":"utterance.end"}')
    await asyncio.wait_for(tts.started.wait(), timeout=1)

    await session._receive_text_event('{"event":"user.interrupt"}')

    assert [event["event"] for event in websocket.events].count(
        "assistant.audio_chunk"
    ) == 0
    assert any(event["event"] == "session.interrupted" for event in websocket.events)
    assert session._active_tts_tasks == set()
    assert session._active_audio_flush_tasks == set()


def test_voice_stream_audio_barge_in_cancels_active_turn_and_starts_next(client):
    deepgram = SequencedDeepgramStreamingService(
        [
            {"transcript": "First turn", "partial": "First"},
            {"transcript": "Second turn", "partial": "Second"},
        ]
    )
    chat = PausingFirstTurnChatService()
    tts = FakeGoogleTTSService()
    override_services(
        deepgram_streaming_service=deepgram,
        chat_service=chat,
        google_tts_service=tts,
    )

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        assert websocket.receive_json()["event"] == "session.started"

        websocket.send_bytes(b"first-audio")
        assert websocket.receive_json()["event"] == "audio.received"
        websocket.send_json({"event": "utterance.end"})
        token = receive_until(websocket, "assistant.token")
        assert token["token"] == (
            "Old response is still being spoken now while Rex continues."
        )
        old_audio = receive_until(websocket, "assistant.audio_chunk")
        assert old_audio["text"] == (
            "Old response is still being spoken now while Rex continues."
        )

        websocket.send_bytes(b"barge-in-audio")
        interrupted = receive_until(websocket, "session.interrupted")
        assert interrupted["reason"] == "barge_in_audio"
        received = receive_until(websocket, "audio.received")
        assert received["chunk_count"] == 1

        websocket.send_json({"event": "utterance.end"})
        final = receive_until(websocket, "transcript.final")
        assert final["transcript"] == "Second turn"
        done = receive_until(websocket, "assistant.done")
        assert done["response_text"] == "Fresh response."

    assert [call["message"] for call in chat.stream_calls] == [
        "First turn",
        "Second turn",
    ]
    assert deepgram.calls == [
        {
            "audio_chunks": [b"first-audio"],
            "content_type": "audio/linear16",
            "sample_rate": 16000,
        },
        {
            "audio_chunks": [b"barge-in-audio"],
            "content_type": "audio/linear16",
            "sample_rate": 16000,
        },
    ]
    assert len(chat.metadata_calls) == 1
    assert chat.metadata_calls[0]["user_message_id"] == "user-message-2"
    assert tts.calls == [
        "Old response is still being spoken now while Rex continues.",
        "Fresh response.",
    ]

