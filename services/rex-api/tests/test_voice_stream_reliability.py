import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.ai_service import AIServiceError
from app.services.deepgram_service import DeepgramServiceError
from app.services.google_tts_service import GoogleTTSServiceError
from voice_stream_fakes import (
    FakeChatService,
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
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


def test_voice_stream_rejects_duplicate_turn_start(client):
    deepgram = SlowDeepgramStreamingService()
    chat = FakeChatService()
    override_services(deepgram_streaming_service=deepgram, chat_service=chat)

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        assert websocket.receive_json()["event"] == "session.started"
        websocket.send_bytes(b"pcm-frame")
        assert websocket.receive_json()["event"] == "audio.received"

        websocket.send_json({"event": "utterance.end"})
        websocket.send_json({"event": "utterance.end"})

        event = receive_until(websocket, "error")
        assert event["code"] == "turn_in_progress"
        assert event["status_code"] == 409
        assert event["detail"] == "Rex is still answering the previous voice turn."


@pytest.mark.parametrize(
    ("deepgram_error", "tts_error", "expected_code", "expected_status"),
    [
        (
            DeepgramServiceError("Voice transcription is not configured.", 503),
            None,
            "transcription_failed",
            503,
        ),
        (
            None,
            GoogleTTSServiceError("Voice playback is not configured.", 503),
            "tts_failed",
            503,
        ),
    ],
)
def test_voice_stream_sends_typed_dependency_errors(
    client,
    deepgram_error,
    tts_error,
    expected_code,
    expected_status,
):
    override_services(
        deepgram_streaming_service=FakeDeepgramStreamingService(error=deepgram_error),
        google_tts_service=FakeGoogleTTSService(error=tts_error),
    )

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        websocket.receive_json()
        websocket.send_bytes(b"pcm-frame")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        event = receive_until(websocket, "error")
        assert event["code"] == expected_code
        assert event["status_code"] == expected_status


def test_voice_stream_sends_typed_planning_error(client):
    chat = FakeChatService(error=AIServiceError("Rex planning failed.", 503))
    override_services(chat_service=chat)

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        websocket.receive_json()
        websocket.send_bytes(b"pcm-frame")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        event = receive_until(websocket, "error")
        assert event["code"] == "assistant_planning_failed"
        assert event["status_code"] == 503
        assert event["detail"] == "Rex planning failed."
