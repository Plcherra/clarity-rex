import pytest

from app.services.conversation_pending_action import (
    ConversationPendingActionService,
    PendingAction,
    is_affirmative_confirmation,
    pending_action_for_delete,
    pending_delete_resolver_target,
    should_defer_to_pending_delete,
)
from app.services.memory_correction_types import CorrectionAffectedRecord
from app.services.memory_delete_reference import should_defer_to_delete_confirmation


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


def test_pending_action_round_trip_dict():
    action = pending_action_for_delete(
        target="tonight plan",
        match=CorrectionAffectedRecord(
            table="long_term_memory",
            id="memory-1",
            action="archive",
            title="Tonight plan",
        ),
    )
    restored = PendingAction.from_dict(action.to_dict())
    assert restored == action


def test_should_defer_to_pending_delete_without_history():
    action = pending_action_for_delete(
        target="Be a goal",
        match=CorrectionAffectedRecord(
            table="plans",
            id="plan-1",
            action="archive",
            title="Be a goal",
        ),
    )
    assert should_defer_to_pending_delete(
        "Yes delete it",
        pending_action=action,
        conversation_history=[],
    )


def test_pending_delete_resolver_target_prefers_explicit_state():
    action = pending_action_for_delete(
        target="stored target",
        match=CorrectionAffectedRecord(
            table="long_term_memory",
            id="memory-1",
            action="archive",
            title="Visible title",
        ),
    )
    assert (
        pending_delete_resolver_target(
            pending_action=action,
            conversation_history=[],
        )
        == "stored target"
    )


@pytest.mark.asyncio
async def test_pending_action_service_persists_on_conversation():
    store = FakePendingActionStore()
    service = ConversationPendingActionService(store)
    action = pending_action_for_delete(
        target="Tonight plan",
        match=CorrectionAffectedRecord(
            table="long_term_memory",
            id="memory-1",
            action="archive",
            title="Tonight plan",
        ),
    )

    await service.set("conversation-1", action)
    loaded = await service.get("conversation-1")

    assert loaded == action
    await service.clear("conversation-1")
    assert await service.get("conversation-1") is None


def test_is_affirmative_confirmation_accepts_common_yes_phrases() -> None:
    for phrase in (
        "yes",
        "Yes!",
        "please do",
        "save it",
        "confirm",
        "do it",
    ):
        assert is_affirmative_confirmation(phrase), phrase
    # Casual chat must not apply a pending write.
    assert not is_affirmative_confirmation("sure")
    assert not is_affirmative_confirmation("ok")
    assert not is_affirmative_confirmation("okay")
    assert not is_affirmative_confirmation("sounds good")
    assert not is_affirmative_confirmation("go ahead")
    assert not is_affirmative_confirmation("yesterday")
    assert not is_affirmative_confirmation("yes update it")
    assert not is_affirmative_confirmation("please don't")


def test_should_defer_to_delete_confirmation_accepts_pending_action_dict():
    pending = {
        "action_type": "delete",
        "target_type": "long_term_memory",
        "target_id": "memory-1",
        "target_label": "Tonight plan",
        "resolver_target": "tonight plan",
    }
    assert should_defer_to_delete_confirmation(
        "Yes",
        conversation_history=[],
        pending_action=pending,
    )
