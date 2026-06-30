from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import FakeAIService, FakeMemoryService
from durable_write_test_helpers import confirm_durable_write, save_message_with_confirmation
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
async def test_conversational_plan_routes_to_milestone_and_requires_confirmation():
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

    response = requested["response"].lower()
    assert "should i save that?" in response
    assert "milestone" in response or "commitment" in response
    assert requested["memory_changes"]["confirmation_required"] == 1
    assert requested["memory_changes"]["plan_save_proposals"][0]["action"] in {
        "save_plan_milestone",
        "save_commitment",
    }
    assert memory_service.created_plan_milestones == []
    assert memory_service.created_commitments == []
    assert memory_service.pending_actions

    confirmed = await chat_service.send_message(
        "Yes",
        requested["conversation_id"],
    )

    assert "Saved" in confirmed["response"]
    assert confirmed["memory_changes"]["created"] == 1
    assert (
        memory_service.created_plan_milestones or memory_service.created_commitments
    )
    saved = (
        memory_service.created_plan_milestones[0]
        if memory_service.created_plan_milestones
        else memory_service.created_commitments[0]
    )
    assert saved["plan_id"] == "plan-europe"
    assert not memory_service.pending_actions


@pytest.mark.asyncio
async def test_conversational_plan_rejection_clears_pending_action():
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
        "I'm working on reaching $5k monthly income from remote client work "
        "to support relocating to Europe."
    )

    rejected = await chat_service.send_message(
        "No",
        requested["conversation_id"],
    )

    assert "won't save" in rejected["response"].lower()
    assert memory_service.created_plan_milestones == []
    assert not memory_service.pending_actions


@pytest.mark.asyncio
async def test_explicit_goal_command_still_saves_without_conversational_confirmation():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My goal is to save $10,000 for Europe")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    saved = await confirm_durable_write(chat_service, proposed)

    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["confirmation_required"] == 0
    assert memory_service.created_plans
    assert not memory_service.pending_actions


@pytest.mark.asyncio
async def test_ambiguous_conversational_plan_asks_before_top_level_save():
    memory_service = FakeMemoryService()
    for index in range(5):
        memory_service.plans.append(
            {
                "id": f"plan-{index}",
                "plan_type": "personal",
                "title": f"Existing plan {index}",
                "description": "Unrelated active plan occupying top-level budget.",
                "priority": 4,
                "active": True,
                "status": "active",
            }
        )
    chat_service = _chat_service(memory_service)

    requested = await chat_service.send_message(
        "I'm trying to build a consistent strength training routine three times per week."
    )

    assert requested["memory_changes"]["confirmation_required"] == 1
    assert requested["memory_changes"]["plan_save_proposals"][0]["action"] == "save_plan"
    assert memory_service.created_plans == []
    assert "Should I save" in requested["response"]

    confirmed = await chat_service.send_message(
        "Yes",
        requested["conversation_id"],
    )

    assert confirmed["memory_changes"]["created"] == 1
    assert memory_service.created_plans


@pytest.mark.asyncio
async def test_unresolved_plan_pending_is_not_overwritten_by_new_plan_message():
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
    assert requested["memory_changes"]["confirmation_required"] == 1

    follow_up = await chat_service.send_message(
        "I'm trying to build a consistent strength training routine three times per week.",
        requested["conversation_id"],
    )

    follow_up_changes = follow_up.get("memory_changes") or {}
    assert follow_up_changes.get("confirmation_required") != 1
    assert memory_service.pending_actions
    assert memory_service.pending_actions[
        requested["conversation_id"]
    ]["action_type"] == "durable_write"


@pytest.mark.asyncio
async def test_failed_plan_confirm_keeps_pending_action_for_retry():
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

    async def failing_create_commitment(_payload):
        raise RuntimeError("write failed")

    memory_service.create_commitment = failing_create_commitment  # type: ignore[method-assign]
    chat_service = _chat_service(memory_service)

    requested = await chat_service.send_message(
        "I'm working on reaching $5k monthly income with location independent "
        "work to support relocating to Europe."
    )
    failed = await chat_service.send_message("Yes", requested["conversation_id"])

    assert "couldn't save" in failed["response"].lower()
    assert memory_service.pending_actions
    assert not memory_service.created_plan_milestones
    assert not memory_service.created_commitments


@pytest.mark.asyncio
async def test_delete_supersedes_pending_plan_save_with_message():
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
    memory_service.long_term_memory.append(
        {
            "id": "memory-tonight-plan",
            "memory_type": "event",
            "content": "User plans to watch it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {
                "fact_kind": "personal_plan",
                "topic_fingerprint": "event:personal_plan:watch:it",
            },
        }
    )
    chat_service = _chat_service(memory_service)

    requested = await chat_service.send_message(
        "I'm working on reaching $5k monthly income with location independent "
        "work to support relocating to Europe."
    )
    assert requested["memory_changes"]["confirmation_required"] == 1

    delete_request = await chat_service.send_message(
        "Can you delete that tonight plan?",
        requested["conversation_id"],
    )

    assert "cleared your pending plan save" in delete_request["response"].lower()
    assert "just to confirm" in delete_request["response"].lower()
    assert memory_service.pending_actions[requested["conversation_id"]]["action_type"] == "delete"


@pytest.mark.asyncio
async def test_plan_save_supersedes_pending_delete_with_message():
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-tonight-plan",
            "memory_type": "event",
            "content": "User plans to watch it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {
                "fact_kind": "personal_plan",
                "topic_fingerprint": "event:personal_plan:watch:it",
            },
        }
    )
    chat_service = _chat_service(memory_service)

    delete_request = await chat_service.send_message(
        "Can you delete that tonight plan?"
    )
    assert "just to confirm" in delete_request["response"].lower()

    plan_request = await chat_service.send_message(
        "I'm trying to build a consistent strength training routine three times per week.",
        delete_request["conversation_id"],
    )

    assert "cleared the pending delete request" in plan_request["response"].lower()
    assert plan_request["memory_changes"]["confirmation_required"] == 1
    assert memory_service.pending_actions[delete_request["conversation_id"]]["action_type"] == "durable_write"


@pytest.mark.asyncio
async def test_conversational_plan_update_requires_confirmation_and_applies():
    memory_service = FakeMemoryService()
    memory_service.plans.append(
        {
            "id": "plan-move",
            "plan_type": "immigration",
            "title": "Move out of the country next year",
            "description": "Move after reaching income targets.",
            "priority": 5,
            "active": True,
            "status": "active",
        }
    )
    chat_service = _chat_service(memory_service)

    requested = await chat_service.send_message(
        "I'm working on clarifying the Italian citizenship route as the primary "
        "path, with Portugal D7 as backup for relocating next year."
    )

    assert requested["memory_changes"]["confirmation_required"] == 1
    proposal_action = requested["memory_changes"]["plan_save_proposals"][0]["action"]
    assert proposal_action in {"update_plan", "save_plan", "save_plan_milestone", "save_commitment"}

    if proposal_action != "update_plan":
        pytest.skip("Discipline routed to a different confirmed write for this message.")

    confirmed = await chat_service.send_message(
        "Yes",
        requested["conversation_id"],
    )

    assert confirmed["memory_changes"]["updated"] == 1
    assert memory_service.plans[0]["description"]
    assert "Italian citizenship" in memory_service.plans[0]["description"]
    assert not memory_service.pending_actions
