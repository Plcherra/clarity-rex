import pytest

from app.services.conversation_pending_action import (
    ConversationPendingActionService,
    pending_action_for_delete,
)
from app.services.conversational_plan_decision_store import pending_action_for_plan_save
from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineDecision,
    MemoryRecordKind,
)
from app.services.memory_correction_types import CorrectionAffectedRecord


class FakePendingActionStore:
    def __init__(self) -> None:
        self.pending_actions: dict[str, dict] = {}

    async def get_conversation_pending_action(self, conversation_id: str):
        return self.pending_actions.get(conversation_id)

    async def set_conversation_pending_action(
        self,
        conversation_id: str,
        pending_action,
    ) -> None:
        if pending_action is None:
            self.pending_actions.pop(conversation_id, None)
        else:
            self.pending_actions[conversation_id] = pending_action


def _plan_decision() -> MemoryDisciplineDecision:
    return MemoryDisciplineDecision(
        action=MemoryDisciplineAction.CREATE_PLAN,
        record_kind=MemoryRecordKind.PLAN,
        payload={"title": "Strength routine", "plan_type": "health"},
        reason="test",
        confidence=0.8,
    )


@pytest.mark.asyncio
async def test_set_superseding_returns_note_when_plan_replaces_delete():
    store = FakePendingActionStore()
    service = ConversationPendingActionService(store)
    delete_action = pending_action_for_delete(
        target="tonight plan",
        match=CorrectionAffectedRecord(
            table="long_term_memory",
            id="memory-1",
            action="archive",
            title="Tonight plan",
        ),
    )
    plan_action = pending_action_for_plan_save(
        title="Strength routine",
        decision=_plan_decision(),
    )

    await service.set("conversation-1", delete_action)
    note = await service.set_superseding("conversation-1", plan_action)

    assert note == (
        "I cleared the pending delete request so we can focus on saving this plan."
    )
    loaded = await service.get("conversation-1")
    assert loaded is not None
    assert loaded.action_type == "save_plan"


@pytest.mark.asyncio
async def test_set_superseding_returns_note_when_delete_replaces_plan():
    store = FakePendingActionStore()
    service = ConversationPendingActionService(store)
    plan_action = pending_action_for_plan_save(
        title="Strength routine",
        decision=_plan_decision(),
    )
    delete_action = pending_action_for_delete(
        target="tonight plan",
        match=CorrectionAffectedRecord(
            table="long_term_memory",
            id="memory-1",
            action="archive",
            title="Tonight plan",
        ),
    )

    await service.set("conversation-1", plan_action)
    note = await service.set_superseding("conversation-1", delete_action)

    assert note == (
        "I cleared your pending plan save so we can confirm this delete first."
    )
    loaded = await service.get("conversation-1")
    assert loaded is not None
    assert loaded.action_type == "delete"


@pytest.mark.asyncio
async def test_set_superseding_same_type_returns_no_note():
    store = FakePendingActionStore()
    service = ConversationPendingActionService(store)
    first = pending_action_for_plan_save(title="Plan A", decision=_plan_decision())
    second = pending_action_for_plan_save(title="Plan B", decision=_plan_decision())

    await service.set("conversation-1", first)
    note = await service.set_superseding("conversation-1", second)

    assert note is None
    loaded = await service.get("conversation-1")
    assert loaded is not None
    assert loaded.target_label == "Plan B"
