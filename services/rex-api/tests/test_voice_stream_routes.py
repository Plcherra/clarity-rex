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
from app.services.rex_brain_contracts import RexBrainChannel
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService
from app.services.voice_stream_session import (
    VOICE_DEEP_RESPONSE_MAX_TOKENS,
    VOICE_RESPONSE_INSTRUCTIONS,
    VOICE_RESPONSE_MAX_TOKENS,
    VoiceStreamSession,
    voice_response_max_tokens,
)
from voice_stream_fakes import (
    FakeChatService,
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
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


def test_voice_stream_completes_streaming_turn(client, caplog):
    caplog.set_level(logging.INFO, logger="rex.voice_stream")
    deepgram = FakeDeepgramStreamingService()
    chat = FakeChatService()
    tts = FakeGoogleTTSService()
    override_services(deepgram, chat, tts)

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
        assert messages["voice_metadata"]["record"]["id"] == "voice-turn-stream"

        done = receive_until(websocket, "assistant.done")
        assert done["conversation_id"] == "conversation-existing"
        assert done["response_text"] == "Rex streaming response."
        assert "stt_ms" in done["timings"]
        assert "turn_ms" in done["timings"]
        assert done["timings"]["tts_chunk_count"] == 1
        assert any(
            "voice_turn_timing" in record.message
            and "stt_ms=" in record.message
            and "turn_ms=" in record.message
            and "intent=casual" in record.message
            and "memory_action=none" in record.message
            and "tts_chunk_count=1" in record.message
            for record in caplog.records
        )

        websocket.send_json({"event": "session.end"})
        ended = websocket.receive_json()
        assert ended["event"] == "session.ended"

    assert deepgram.calls == [
        {
            "audio_chunks": [b"pcm-frame-1", b"pcm-frame-2"],
            "content_type": "audio/linear16",
            "sample_rate": 16000,
        }
    ]
    assert chat.stream_calls == [
        {
            "message": "Hey Rex",
            "conversation_id": "conversation-existing",
            "file": None,
            "response_instructions": VOICE_RESPONSE_INSTRUCTIONS,
            "max_response_tokens": VOICE_RESPONSE_MAX_TOKENS,
            "financial_context": None,
            "channel": RexBrainChannel.VOICE,
            "include_turn_trace": True,
        }
    ]
    assert tts.calls == ["Rex streaming response."]
    assert chat.metadata_calls[0]["conversation_id"] == "conversation-existing"
    assert chat.metadata_calls[0]["user_message_id"] == "user-message-1"
    assert chat.metadata_calls[0]["assistant_message_id"] == "assistant-message-1"


def test_voice_stream_saves_direct_memory_through_real_chat_service(client, caplog):
    caplog.set_level(logging.INFO, logger="rex.voice_stream")
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat = _real_chat_service(ai_service, memory_service)
    deepgram = FakeDeepgramStreamingService(
        transcript="My mom's birthday is June 18",
        partial_transcript="My mom",
    )
    tts = FakeGoogleTTSService()
    override_services(deepgram, chat, tts)

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        websocket.receive_json()
        websocket.send_bytes(b"pcm-frame")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        final = receive_until(websocket, "transcript.final")
        assert final["transcript"] == "My mom's birthday is June 18"

        token = receive_until(websocket, "assistant.token")
        assert token["token"] == "Got it, your mom's birthday is June 18."

        messages = receive_until(websocket, "messages.updated")
        assert messages["memory_changes"]["created"] == 1
        assert messages["memory_changes"]["records"][0]["action"] == "direct_saved"

        done = receive_until(websocket, "assistant.done")
        assert done["response_text"] == "Got it, your mom's birthday is June 18."
        assert done["memory_changes"]["created"] == 1
        assert done["timings"]["tts_chunk_count"] == 1

    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 0
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert tts.calls == ["Got it, your mom's birthday is June 18."]
    assert any(
        "voice_turn_timing" in record.message
        and "intent=memory_save" in record.message
        and "memory_action=direct_saved" in record.message
        and "tts_chunk_count=1" in record.message
        for record in caplog.records
    )


def test_voice_stream_updates_memory_through_real_chat_service(client):
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
    deepgram = FakeDeepgramStreamingService(
        transcript=(
            "Can you change my location? It's Somerville with one o and one m."
        ),
        partial_transcript="Can you change my location?",
    )
    override_services(deepgram_streaming_service=deepgram, chat_service=chat)

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json(
            {
                "event": "session.start",
                "conversation_id": "conversation-existing",
            }
        )
        websocket.receive_json()
        websocket.send_bytes(b"pcm-frame")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        messages = receive_until(websocket, "messages.updated")
        assert messages["memory_changes"]["updated"] == 1

        done = receive_until(websocket, "assistant.done")
        assert done["response_text"] == (
            "Got it, I updated that: you live in Somerville, Massachusetts."
        )
        assert done["memory_changes"]["updated"] == 1

    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 0
    assert len(memory_service.long_term_memory) == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )


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
def test_voice_stream_recall_loads_saved_memory_context(
    client,
    transcript,
    memory_content,
    answer,
):
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

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        websocket.receive_json()
        websocket.send_bytes(b"pcm-frame")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        done = receive_until(websocket, "assistant.done")
        assert done["response_text"] == answer
        assert done["timings"]["tts_chunk_count"] == 1

    prompt_text = "\n".join(str(message["content"]) for message in ai_service.messages)
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

    assert delays == [1.1]


@pytest.mark.asyncio
async def test_voice_stream_native_ios_waits_for_explicit_utterance_end(monkeypatch):
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
    session.client = "ios_native"
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


def test_voice_response_max_tokens_keeps_normal_turns_short_and_deep_turns_larger():
    assert (
        voice_response_max_tokens("How much did I spend today?")
        == VOICE_RESPONSE_MAX_TOKENS
    )
    assert (
        voice_response_max_tokens("Deep think and analyze thoroughly my budget")
        == VOICE_DEEP_RESPONSE_MAX_TOKENS
    )
