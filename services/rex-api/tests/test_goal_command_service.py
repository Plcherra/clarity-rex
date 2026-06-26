import pytest

from app.services.goal_command_service import GoalCommandService
from chat_service_fakes import FakeMemoryService


class FailingCommitmentService:
    async def create_commitment(self, _request):
        raise RuntimeError("commitment write failed")


class FailingPlanService:
    async def create_plan(self, _request):
        raise RuntimeError("plan write failed")


def _time_context():
    return {
        "date": "2026-06-04",
        "timezone": "America/New_York",
    }


async def _user_message(memory_service, conversation_id, content):
    return await memory_service.save_message(conversation_id, "user", content)


@pytest.mark.asyncio
async def test_remind_me_command_creates_commitment_without_llm():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "Remind me to send her $200 on the 10th"
    user_message = await _user_message(memory_service, conversation_id, message)

    result = await GoalCommandService(memory_service).handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["response"] == (
        "Got it, I saved that commitment: Send her $200 on the 10th."
    )
    assert result["memory_changes"]["created"] == 1
    commitment = memory_service.created_commitments[0]
    assert commitment["commitment_type"] == "money"
    assert commitment["commitment_text"] == "send her $200 on the 10th"
    assert commitment["due_at"] == "June 10"


@pytest.mark.asyncio
async def test_set_reminder_command_creates_commitment():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "Set a reminder to call mom on June 18"
    user_message = await _user_message(memory_service, conversation_id, message)

    result = await GoalCommandService(memory_service).handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    commitment = memory_service.created_commitments[0]
    assert commitment["commitment_type"] == "relationship"
    assert commitment["commitment_text"] == "call mom on June 18"
    assert commitment["due_at"] == "June 18"


@pytest.mark.asyncio
async def test_hold_me_accountable_creates_morning_routine_habit():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "Hold me accountable to wake up at 5 AM"
    user_message = await _user_message(memory_service, conversation_id, message)

    result = await GoalCommandService(memory_service).handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["response"] == (
        "Got it, I saved that commitment: Wake up at 5 AM."
    )
    commitment = memory_service.created_commitments[0]
    assert commitment["commitment_type"] == "habit"
    assert commitment["title"] == "Wake up at 5 AM"
    assert commitment["commitment_text"] == "wake up at 5 AM"
    assert commitment["priority"] == 5


@pytest.mark.asyncio
async def test_need_to_with_due_date_creates_commitment():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "I need to send the rent money by the 12th"
    user_message = await _user_message(memory_service, conversation_id, message)

    result = await GoalCommandService(memory_service).handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    commitment = memory_service.created_commitments[0]
    assert commitment["commitment_type"] == "money"
    assert commitment["commitment_text"] == "send the rent money by the 12th"
    assert commitment["due_at"] == "June 12"


@pytest.mark.asyncio
async def test_commitment_write_failure_is_truthful():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "Remind me to send her $200 on the 10th"
    user_message = await _user_message(memory_service, conversation_id, message)

    result = await GoalCommandService(
        memory_service,
        commitment_service=FailingCommitmentService(),
    ).handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "couldn't save it" in result["response"]
    assert result["memory_changes"]["created"] == 0
    assert result["memory_changes"]["skipped"] == 1
    assert result["memory_changes"]["records"][0]["action"] == "save_failed"
    assert memory_service.created_commitments == []


@pytest.mark.asyncio
async def test_goal_write_failure_is_truthful():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "My goal is save $500 by the 20th"
    user_message = await _user_message(memory_service, conversation_id, message)

    result = await GoalCommandService(
        memory_service,
        plan_service=FailingPlanService(),
    ).handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "couldn't save it" in result["response"]
    assert result["memory_changes"]["created"] == 0
    assert result["memory_changes"]["skipped"] == 1
    assert result["memory_changes"]["records"][0]["action"] == "save_failed"
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

    result = await GoalCommandService(memory_service).handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "added this as a goal" in result["response"]
    assert result["memory_changes"]["created"] == 1
    assert memory_service.created_plans
    plan = memory_service.created_plans[0]
    assert plan["plan_type"] == "personal"
    assert "upgrade my ram" in plan["description"].casefold()
    assert plan["target_date"] == "Next month"
    assert memory_service.created_commitments == []
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_have_to_upgrade_without_timeline_creates_commitment():
    memory_service = FakeMemoryService()
    conversation_id = await memory_service.create_conversation()
    message = "I have to upgrade my RAM from 16GB to 32GB"
    user_message = await _user_message(memory_service, conversation_id, message)

    result = await GoalCommandService(memory_service).handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "saved that commitment" in result["response"]
    assert result["memory_changes"]["created"] == 1
    commitment = memory_service.created_commitments[0]
    assert commitment["commitment_type"] == "task"
    assert "upgrade my RAM" in commitment["commitment_text"]


@pytest.mark.asyncio
async def test_move_misclassified_memory_to_goal_archives_and_creates_plan():
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

    result = await GoalCommandService(memory_service).handle_turn(
        message,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_history=[*history, user_message],
        time_context=_time_context(),
    )

    assert result is not None
    assert "removed that from saved memory" in result["response"]
    assert result["memory_changes"]["created"] == 1
    assert result["memory_changes"]["archived"] == 1
    assert memory_service.created_plans
    assert memory_service.long_term_memory[0]["active"] is False
    assert "32gb" in memory_service.created_plans[0]["description"].casefold()
