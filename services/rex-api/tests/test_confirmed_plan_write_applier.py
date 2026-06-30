import pytest

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineDecision,
    MemoryRecordKind,
)
from app.services.confirmed_plan_write_applier import ConfirmedPlanWriteApplier
from test_plan_service import FakePlanMemoryService


@pytest.mark.asyncio
async def test_confirmed_create_plan_uses_plan_service_merge_path():
    memory = FakePlanMemoryService()
    memory.plans.append(
        {
            "id": "plan-1",
            "plan_type": "health",
            "title": "Strength routine",
            "description": "Existing active plan.",
            "priority": 4,
            "active": True,
            "status": "active",
            "metadata": {},
        }
    )
    applier = ConfirmedPlanWriteApplier(memory)
    decision = MemoryDisciplineDecision(
        action=MemoryDisciplineAction.CREATE_PLAN,
        record_kind=MemoryRecordKind.PLAN,
        payload={
            "plan_type": "health",
            "title": "Strength routine",
            "description": "Train three times per week.",
            "desired_outcome": "Train three times per week.",
            "priority": 4,
        },
        reason="test",
        confidence=0.8,
    )

    result = await applier.apply_confirmed_decision(
        decision,
        conversation_id="conversation-1",
        source_message_id="message-1",
    )

    assert result["applied"] is True
    assert result["record"]["id"] == "plan-1"
    assert len(memory.plans) == 1


@pytest.mark.asyncio
async def test_confirmed_update_plan_applies_via_plan_service():
    memory = FakePlanMemoryService()
    memory.plans.append(
        {
            "id": "plan-move",
            "plan_type": "immigration",
            "title": "Move out of the country next year",
            "description": "Original route notes.",
            "priority": 5,
            "active": True,
            "status": "active",
            "metadata": {},
        }
    )
    applier = ConfirmedPlanWriteApplier(memory)
    decision = MemoryDisciplineDecision(
        action=MemoryDisciplineAction.UPDATE_PLAN,
        record_kind=MemoryRecordKind.PLAN,
        payload={
            "description": "Primary route is Italian citizenship, with Portugal D7 as backup.",
        },
        reason="test",
        confidence=0.8,
        target_id="plan-move",
    )

    result = await applier.apply_confirmed_decision(
        decision,
        conversation_id="conversation-1",
        source_message_id="message-1",
    )

    assert result["applied"] is True
    assert "Italian citizenship" in result["record"]["description"]
