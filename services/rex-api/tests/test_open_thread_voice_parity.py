from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.open_thread_turn_service import THREAD_OFFER_PHRASE
from app.services.rex_channel import RexBrainChannel
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService


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


@pytest.mark.asyncio
async def test_open_thread_offer_works_on_voice_channel():
    ai_service = FakeAIService(response="Voice follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    result = await chat_service.send_message(
        "I've been trying to rebuild my workout habit this month.",
        channel=RexBrainChannel.VOICE,
    )

    assert THREAD_OFFER_PHRASE in result["response"]
    assert "not saved memory" in result["response"]
    assert ai_service.generate_calls == 0
