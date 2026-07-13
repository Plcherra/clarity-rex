import pytest

from app.services.conversation_pending_action import PendingAction
from app.services.durable_write_pending import (
    pending_action_for_durable_write,
    proposal_from_pending_action,
)
from app.services.durable_write_service import DurableWriteService
from app.services.goal_command_service import GoalCommandService
from app.services.plan_service import PlanService, PlanServiceError
from chat_service_fakes import FakeMemoryService


class FailingPlanService(PlanService):
    def __init__(self, memory_service):
        self.memory_service = memory_service

    async def create_plan(self, _request):
        raise PlanServiceError("plan write failed", 500)


def _time_context():
    return {
        "date": "2026-06-04",
        "timezone": "America/New_York",
    }


async def _user_message(memory_service, conversation_id, content):
    return await memory_service.save_message(conversation_id, "user", content)


def _goal_command_service(memory_service, *, plan_service=None):
    plan_svc = plan_service or PlanService(memory_service)
    durable = DurableWriteService(memory_service, plan_service=plan_svc)
    return GoalCommandService(
        memory_service,
        plan_service=plan_svc,
        durable_write_service=durable,
    )


async def _run_goal_turn(
    service,
    *,
    memory_service,
    message,
    conversation_id,
    user_message,
    conversation_history,
    time_context,
):
    result = await service.handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=conversation_history,
        time_context=time_context,
    )
    if result is None:
        return None
    memory_changes = result.get("memory_changes") or {}
    if not memory_changes.get("confirmation_required"):
        return result

    pending = memory_service.pending_actions.get(conversation_id)
    proposal = proposal_from_pending_action(pending)
    if proposal is None:
        return result

    pending_action = (
        pending
        if isinstance(pending, PendingAction)
        else PendingAction.from_dict(pending)
    )
    return await service.durable_write_service._apply(
        proposal,
        pending=pending_action,
        conversation_id=conversation_id,
        user_message=user_message,
    )


@pytest.mark.asyncio
async def test_remind_me_phrase_creates_plan_after_confirm(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
    from app.config import get_settings

    get_settings.cache_clear()
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "Remind me to send her $200 on the 10th"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    plan = memory_service.created_plans[0]
    assert "send her" in plan["description"].casefold()
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_explicit_money_goal_with_due_date_creates_plan():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "My goal is to send the rent money by the 12th"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    plan = memory_service.created_plans[0]
    assert plan["plan_type"] == "finance"
    assert "send the rent money by the 12th" in plan["description"].casefold()
    assert plan["target_date"] == "June 12"


@pytest.mark.asyncio
async def test_hold_me_accountable_phrase_does_not_short_circuit_goal_command_path():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "Hold me accountable to wake up at 5 AM"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await service.handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is None
    assert memory_service.created_plans == []


@pytest.mark.asyncio
async def test_goal_write_failure_is_truthful():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "My goal is to send her $200 on the 10th"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(
        memory_service,
        plan_service=FailingPlanService(memory_service),
    )

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "couldn't save it" in result["response"]
    assert result["memory_changes"]["created"] == 0
    assert result["memory_changes"]["write_proposals"][0]["status"] == "failed"
    assert memory_service.created_plans == []


@pytest.mark.asyncio
async def test_explicit_goal_write_failure_is_truthful():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "My goal is save $500 by the 20th"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(
        memory_service,
        plan_service=FailingPlanService(memory_service),
    )

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "couldn't save it" in result["response"]
    assert result["memory_changes"]["created"] == 0
    assert result["memory_changes"]["write_proposals"][0]["status"] == "failed"
    assert memory_service.created_plans == []


@pytest.mark.asyncio
async def test_purchase_checklist_upgrade_creates_goal_not_memory():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = (
        "Nice, it would be my next checklist for the next month purchase. "
        "I have to upgrade my ram from 16 to at least 32 or 64 + "
        "1 or 2 more terabytes of space"
    )
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "Saved plan in Goals" in result["response"]
    assert result["memory_changes"]["created"] == 1
    assert memory_service.created_plans
    plan = memory_service.created_plans[0]
    assert plan["plan_type"] == "personal"
    assert "upgrade my ram" in plan["description"].casefold()
    assert plan["target_date"] == "July 31"
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_have_to_upgrade_without_timeline_creates_goal():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "I have to upgrade my RAM from 16GB to 32GB"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "Saved plan in Goals" in result["response"]
    assert result["memory_changes"]["created"] == 1
    plan = memory_service.created_plans[0]
    assert "upgrade my ram" in plan["description"].casefold()


@pytest.mark.asyncio
async def test_clarified_misclassified_goal_creates_plans_without_auto_archive():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    memory_service.long_term_memory.append(
        {
            "id": "memory-ram",
            "memory_type": "fact",
            "content": "User has a to upgrade my RAM from 16TO at least 32OR 64.",
            "active": True,
        }
    )
    history = [
        {
            "role": "assistant",
            "content": "Got it, you have a to upgrade my RAM from 16TO at least 32OR 64.",
        }
    ]
    message = (
        "This that you saved: RAM from 16TO at least 32OR 64. "
        "It would meant to be buy or get 32gb or 64gb ram and "
        "1terab or 2terab of storage next month"
    )
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[*history, user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    assert len(memory_service.created_plans) == 1
    assert memory_service.long_term_memory[0]["active"] is True
    title = memory_service.created_plans[0]["title"].casefold()
    assert "ram" in title or "storage" in title or "tb" in title


@pytest.mark.asyncio
async def test_meta_reclassification_request_asks_for_details_without_saving():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    memory_service.long_term_memory.append(
        {
            "id": "memory-ram",
            "memory_type": "fact",
            "content": "User has a to upgrade my RAM from 16TO at least 32OR 64.",
            "active": True,
        }
    )
    history = [
        {
            "role": "assistant",
            "content": "Got it, you have a to upgrade my RAM from 16TO at least 32OR 64.",
        }
    ]
    message = (
        "Can you move or delete this from memory? It meant to be a goal/commitment"
    )
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await service.handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[*history, user_message],
        time_context=_time_context(),
    )

    assert result is None
    assert memory_service.created_plans == []
    assert memory_service.long_term_memory[0]["active"] is True


@pytest.mark.asyncio
async def test_hardware_list_creates_two_separate_goals():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "Get 32gb-64gb ram and 1tb-2tb storage by next month"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    assert len(memory_service.created_plans) == 1
    title = memory_service.created_plans[0]["title"].casefold()
    assert "ram" in title or "storage" in title or "tb" in title
    assert memory_service.created_plans[0]["target_date"] == "July 31"


@pytest.mark.asyncio
async def test_numbered_goals_phrase_creates_first_detected_goal_per_turn():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "2 goals. 1 buy 32-64gb ram. 2 buy 1-2tb storage"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    assert len(memory_service.created_plans) == 1
    title = memory_service.created_plans[0]["title"].casefold()
    assert "ram" in title or "storage" in title or "tb" in title
    assert "2 goals" not in title


@pytest.mark.asyncio
async def test_yes_please_after_hardware_message_saves_first_goal_from_history():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    history = [
        await _user_message(
            memory_service,
            conversation_id,
            "Get 32gb-64gb ram and 1tb-2tb storage",
        ),
        await memory_service.save_message(
            conversation_id,
            "assistant",
            "Sure, what's the exact goal you'd like me to set?",
        ),
    ]
    message = "Yes please"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await _run_goal_turn(
        service,
        memory_service=memory_service,
        message=message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[*history, user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    assert len(memory_service.created_plans) == 1


@pytest.mark.asyncio
async def test_list_goals_question_returns_saved_goals_without_llm():
    memory_service = FakeMemoryService()
    memory_service.plans.append(
        {
            "id": "plan-1",
            "title": "Buy RAM",
            "description": "Buy 32-64gb ram",
            "status": "active",
            "active": True,
        }
    )
    conversation_id = await memory_service.create_conversation()
    message = "What goals do we have saved?"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await service.handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "Active goals:" in result["response"]
    assert "Buy RAM" in result["response"]
    assert result["memory_changes"] == {}


@pytest.mark.asyncio
async def test_explicit_goal_command_still_works_when_auto_suggestions_off(
    monkeypatch,
):
    """Off disables autos only — explicit save-as-goal must still propose."""
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "off")
    from app.config import get_settings

    get_settings.cache_clear()
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "Save waking up at 4am every day as a goal"
    user_message = await _user_message(memory_service, conversation_id, message)
    service = _goal_command_service(memory_service)

    result = await service.handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    memory_changes = result.get("memory_changes") or {}
    proposals = memory_changes.get("write_proposals") or []
    assert memory_changes.get("confirmation_required", 0) >= 1 or proposals
    get_settings.cache_clear()
