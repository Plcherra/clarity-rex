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
async def test_open_thread_offer_works_on_voice_channel(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
    from app.config import get_settings

    get_settings.cache_clear()
    ai_service = FakeAIService(response="Voice follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    result = await chat_service.send_message(
        "I've been trying to figure out a better morning routine lately.",
        channel=RexBrainChannel.VOICE,
    )

    assert result["memory_changes"]["confirmation_required"] == 1
    assert result["memory_changes"]["write_proposals"][0]["write_kind"] == "open_thread"
    assert result["memory_changes"]["write_proposals"][0]["title"] == "Better Morning Routine"
    assert THREAD_OFFER_PHRASE not in result["response"]
    assert ai_service.generate_calls == 0
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_weak_workout_habit_message_does_not_offer_open_thread():
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

    assert THREAD_OFFER_PHRASE not in result["response"]
    assert ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_open_thread_wins_over_conversational_plan_for_companion_vents():
    ai_service = FakeAIService(response="Should not run")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    result = await chat_service.send_message(
        "I'm working on my citizenship application and it has been really stressful lately.",
        channel=RexBrainChannel.CHAT,
    )

    assert THREAD_OFFER_PHRASE in result["response"]
    assert result["memory_changes"]["confirmation_required"] == 0
    assert not result["memory_changes"].get("write_proposals")
    assert ai_service.generate_calls == 0


@pytest.mark.asyncio
async def test_clear_savings_goal_routes_to_plan_not_open_thread():
    ai_service = FakeAIService(response="Should not run")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    result = await chat_service.send_message(
        "I need to save $5000 by December for my emergency fund.",
        channel=RexBrainChannel.CHAT,
    )

    proposals = result.get("memory_changes", {}).get("write_proposals") or []
    assert not any(
        proposal.get("write_kind") == "open_thread" for proposal in proposals
    )
    assert ai_service.generate_calls == 0
