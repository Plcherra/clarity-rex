"""Durable delete confirmation cards with permanent removal."""

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import FakeAIService, FakeMemoryService
from durable_write_test_helpers import confirm_durable_write
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService


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


def _chat_service(memory_service: FakeMemoryService) -> ChatService:
    return ChatService(
        FakeAIService(response="Rex normal response"),
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )


@pytest.mark.asyncio
async def test_delete_memory_proposes_high_risk_card_and_hard_deletes():
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-tonight-plan",
            "memory_type": "event",
            "content": "User plans to watch it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {"fact_kind": "personal_plan"},
        }
    )
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("Can you delete that tonight plan?")

    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = proposed["memory_changes"]["write_proposals"][0]
    assert proposal["write_kind"] == "delete"
    assert proposal["risk_level"] == "high"
    assert "cannot be undone" in proposal["confirmation_text"].lower()
    assert len(memory_service.long_term_memory) == 1

    confirmed = await confirm_durable_write(chat_service, proposed)

    assert "Permanently deleted" in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_delete_goal_uses_same_card_flow():
    memory_service = FakeMemoryService()
    memory_service.plans.append(
        {
            "id": "plan-junk",
            "title": "Buy dumbbells",
            "description": "Buy dumbbells",
            "plan_type": "personal",
            "active": True,
        }
    )
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("Delete the goal Buy dumbbells")

    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = proposed["memory_changes"]["write_proposals"][0]
    assert proposal["write_kind"] == "delete"
    assert proposal["delete_table"] == "plans"

    confirmed = await confirm_durable_write(chat_service, proposed)
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.plans == []


@pytest.mark.asyncio
async def test_delete_open_thread_proposes_card():
    memory_service = FakeMemoryService()
    memory_service.open_threads.append(
        {
            "id": "thread-1",
            "title": "Morning routine",
            "summary": "Follow up on morning routine",
            "status": "active",
        }
    )
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message(
        'Delete the open thread "Morning routine"'
    )

    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = proposed["memory_changes"]["write_proposals"][0]
    assert proposal["write_kind"] == "delete"
    assert proposal["delete_table"] == "open_threads"

    confirmed = await confirm_durable_write(chat_service, proposed)
    assert memory_service.open_threads == []
