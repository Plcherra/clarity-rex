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

    assert "Tap confirm to save" in requested["response"]
    assert "nothing is saved until you confirm" in requested["response"]
    proposal = requested["memory_changes"]["plan_save_proposals"][0]
    assert proposal["action"] == "save_plan_milestone"
    assert requested["memory_changes"]["confirmation_required"] == 1
    assert memory_service.created_plan_milestones == []
    assert memory_service.pending_actions

    confirmed = await chat_service.send_message(
        "Yes",
        requested["conversation_id"],
    )

    assert confirmed["response"] == "Rex normal response"
    assert confirmed["memory_changes"]["created"] == 1
    assert memory_service.created_plan_milestones
    saved = memory_service.created_plan_milestones[0]
    assert saved["plan_id"] == "plan-europe"
    assert not memory_service.pending_actions
    assert chat_service.ai_service.generate_calls == 1


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

    assert rejected["response"] == "Rex normal response"
    assert memory_service.created_plan_milestones == []
    assert not memory_service.pending_actions
    assert chat_service.ai_service.generate_calls == 1


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
async def test_ambiguous_conversational_plan_asks_before_top_level_save(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "text")
    from app.config import get_settings

    get_settings.cache_clear()
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

    assert requested["memory_changes"]["confirmation_required"] == 0
    assert memory_service.created_plans == []
    assert "goal in Goals" in requested["response"]
    assert not (requested["memory_changes"].get("write_proposals") or [])
    get_settings.cache_clear()


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

    async def failing_create_plan_milestone(_payload):
        raise RuntimeError("write failed")

    memory_service.create_plan_milestone = failing_create_plan_milestone  # type: ignore[method-assign]
    chat_service = _chat_service(memory_service)

    requested = await chat_service.send_message(
        "I'm working on reaching $5k monthly income with location independent "
        "work to support relocating to Europe."
    )
    failed = await chat_service.send_message("Yes", requested["conversation_id"])

    assert "couldn't save" in failed["response"].lower()
    assert memory_service.pending_actions
    assert not memory_service.created_plan_milestones


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
    assert delete_request["memory_changes"]["confirmation_required"] == 1
    assert (
        delete_request["memory_changes"]["write_proposals"][0]["write_kind"] == "delete"
    )
    assert memory_service.pending_actions[requested["conversation_id"]]["action_type"] == "durable_write"


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
    assert delete_request["memory_changes"]["confirmation_required"] == 1

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
    proposal = requested["memory_changes"]["plan_save_proposals"][0]
    proposal_action = proposal["action"]
    assert proposal_action in {"update_plan", "save_plan", "save_plan_milestone"}

    confirmed = await confirm_durable_write(chat_service, requested)

    if proposal_action == "update_plan":
        assert confirmed["memory_changes"]["updated"] == 1
        plan_text = " ".join(
            str(memory_service.plans[0].get(key) or "")
            for key in ("title", "description", "desired_outcome")
        )
    elif proposal_action == "save_plan_milestone":
        assert confirmed["memory_changes"]["created"] == 1
        milestone_title = str(
            (confirmed.get("memory_changes") or {}).get("applied_record", {}).get("title")
            or proposal.get("title")
            or ""
        )
        plan_text = milestone_title
    else:
        assert confirmed["memory_changes"]["created"] == 1
        target_plan = memory_service.plans[-1]
        plan_text = " ".join(
            str(target_plan.get(key) or "")
            for key in ("title", "description", "desired_outcome")
        )

    assert "Italian citizenship" in plan_text
    assert not memory_service.pending_actions
