"""WebSocket turn contract for /voice/stream: events, timings, and error paths."""

from __future__ import annotations

import logging

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.deepgram_service import DeepgramServiceError
from app.services.google_tts_service import GoogleTTSServiceError
from app.services.rex_channel import RexBrainChannel
from voice_stream_fakes import (
    FakeChatService,
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
    FakeUsageTrackingService,
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
