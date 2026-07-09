from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.open_thread_turn_service import THREAD_OFFER_PHRASE
from app.services.rex_channel import RexBrainChannel
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService
from app.services.open_thread_turn_service import (
    THREAD_OFFER_PHRASE,
    OpenThreadTurnService,
)
from test_open_thread_turn_service import (
    FakeDurableWriteService,
    FakeTurnMemoryService,
)
from test_open_thread_service import FakeOpenThreadStore
from app.services.open_thread_service import OpenThreadService


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


def _chat_service(
    memory_service: FakeMemoryService,
    *,
    ai_response: str = "Rex companion follow-up",
) -> ChatService:
    return ChatService(
        FakeAIService(response=ai_response),
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )


SLEEP_VENT = (
    "i cant sleep too much on my mind, I wake up around 11am so i just "
    "starting get sleep but I dont want to sleep because I gotta wake up around 6:30am"
)
HABIT_THREAD = "I want to change my sleep schedule and wake up every day at 6am."


@pytest.mark.asyncio
async def test_off_mode_skips_thread_offer_for_habit_message(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "off")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = _chat_service(FakeMemoryService())

    result = await chat_service.send_message(HABIT_THREAD)

    assert THREAD_OFFER_PHRASE not in result["response"]
    proposals = (result.get("memory_changes") or {}).get("write_proposals") or []
    assert not proposals
    assert chat_service.ai_service.generate_calls == 1
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_text_mode_offers_thread_for_habit_not_sleep_vent(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "text")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = _chat_service(FakeMemoryService())

    vent = await chat_service.send_message(SLEEP_VENT)
    assert THREAD_OFFER_PHRASE not in vent["response"]

    habit = await chat_service.send_message(HABIT_THREAD)
    assert THREAD_OFFER_PHRASE in habit["response"]
    assert habit["memory_changes"]["confirmation_required"] == 0
    assert not (habit["memory_changes"].get("write_proposals") or [])
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_card_mode_proposes_open_thread_confirm_card(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = _chat_service(FakeMemoryService())

    result = await chat_service.send_message(HABIT_THREAD)

    proposals = result["memory_changes"].get("write_proposals") or []
    assert result["memory_changes"]["confirmation_required"] == 1
    assert proposals[0]["write_kind"] == "open_thread"
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_open_thread_decline_continues_on_voice_channel():
    chat_service = _chat_service(
        FakeMemoryService(),
        ai_response="Voice companion follow-up",
    )

    offered = await chat_service.send_message(
        HABIT_THREAD,
        channel=RexBrainChannel.VOICE,
    )
    declined = await chat_service.send_message(
        "No",
        offered["conversation_id"],
        channel=RexBrainChannel.VOICE,
    )

    assert declined["response"] == "Voice companion follow-up"
    assert chat_service.ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_plan_card_rejection_continues_companion_chat():
    memory_service = FakeMemoryService()
    memory_service.plans.append(
        {
            "id": "plan-europe",
            "plan_type": "personal",
            "title": "Relocate to Europe next year",
            "description": "Build location independent income and savings.",
            "priority": 5,
            "active": True,
            "status": "active",
        }
    )
    chat_service = _chat_service(memory_service)

    requested = await chat_service.send_message(
        "I'm working on reaching $5k monthly income with location independent "
        "work to support relocating to Europe."
    )
    rejected = await chat_service.send_message(
        "No",
        requested["conversation_id"],
    )

    assert rejected["response"] == "Rex companion follow-up"
    assert rejected["memory_changes"]["skipped"] == 1
    assert chat_service.ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_memory_rejection_continues_companion_chat():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)
    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        conversation_id,
        "user",
        "My mom's birthday is June 18.",
    )
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "Want me to remember that?",
    )

    rejected = await chat_service.send_message(
        "no don't save that",
        conversation_id,
    )

    assert rejected["response"] == "Rex companion follow-up"
    assert rejected["memory_changes"]["skipped"] == 1
    assert chat_service.ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_service_level_off_mode_blocks_thread_auto_offer():
    memory = FakeTurnMemoryService()
    store = FakeOpenThreadStore()
    threads = OpenThreadService(store)
    service = OpenThreadTurnService(
        memory,
        open_thread_service=threads,
        durable_write_service=FakeDurableWriteService(),
    )

    result = await service.handle_turn(
        HABIT_THREAD,
        conversation_id="conversation-1",
        user_message={"id": "user-1", "content": HABIT_THREAD},
        conversation_history=[],
        proposal_settings=AssistantProposalSettings(mode="off"),
    )

    assert result is None
