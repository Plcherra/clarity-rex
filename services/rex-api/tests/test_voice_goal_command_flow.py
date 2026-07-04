from datetime import datetime
from zoneinfo import ZoneInfo

import pytest
from httpx_ws import aconnect_ws

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService
from voice_stream_async_client import async_receive_until, async_voice_client
from voice_stream_fakes import (
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
    override_services,
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


@pytest.mark.asyncio
async def test_voice_stream_creates_goal_without_llm():
    async with async_voice_client() as client:
        ai_service = FakeAIService()
        memory_service = FakeMemoryService()
        chat = _real_chat_service(ai_service, memory_service)
        deepgram = FakeDeepgramStreamingService(
            transcript="Track send her $200 on the 10th as a goal",
            partial_transcript="Track send her",
        )
        tts = FakeGoogleTTSService()
        override_services(deepgram, chat, tts)

        async with aconnect_ws("http://testserver/voice/stream", client) as websocket:
            await websocket.send_json({"event": "session.start"})
            await websocket.receive_json()
            await websocket.send_bytes(b"pcm-frame")
            await websocket.receive_json()
            await websocket.send_json({"event": "utterance.end"})

            messages = await async_receive_until(websocket, "messages.updated")
            assert messages["memory_changes"]["confirmation_required"] == 1
            assert messages["memory_changes"]["write_proposals"][0]["write_kind"] == (
                "plan"
            )

            done = await async_receive_until(websocket, "assistant.done")
            assert done["memory_changes"]["confirmation_required"] == 1
            assert done["memory_changes"]["write_proposals"][0]["write_kind"] == "plan"
            assert done["memory_changes"]["write_proposals"][0]["title"]

        assert ai_service.generate_calls == 0
        assert ai_service.stream_calls == 0
        assert memory_service.created_plans == []
