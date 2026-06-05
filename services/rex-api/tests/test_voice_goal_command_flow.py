from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient

from app.main import app
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService
from voice_stream_fakes import (
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
    override_services,
    receive_until,
)


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


def _real_chat_service(ai_service, memory_service):
    return ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )


def test_voice_stream_creates_commitment_without_llm():
    app.dependency_overrides.clear()
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat = _real_chat_service(ai_service, memory_service)
    deepgram = FakeDeepgramStreamingService(
        transcript="Set a reminder to send her $200 on the 10th",
        partial_transcript="Set a reminder",
    )
    tts = FakeGoogleTTSService()
    override_services(deepgram, chat, tts)

    with TestClient(app) as client:
        with client.websocket_connect("/voice/stream") as websocket:
            websocket.send_json({"event": "session.start"})
            websocket.receive_json()
            websocket.send_bytes(b"pcm-frame")
            websocket.receive_json()
            websocket.send_json({"event": "utterance.end"})

            messages = receive_until(websocket, "messages.updated")
            assert messages["memory_changes"]["created"] == 1
            assert messages["memory_changes"]["records"][0]["kind"] == "commitment"

            done = receive_until(websocket, "assistant.done")
            assert done["response_text"] == (
                "Got it, I saved that commitment: Send her $200 on the 10th."
            )
            assert done["memory_changes"]["created"] == 1

    app.dependency_overrides.clear()
    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 0
    assert memory_service.created_commitments[0]["commitment_text"] == (
        "send her $200 on the 10th"
    )
    assert memory_service.created_commitments[0]["due_at"] == "June 10"
