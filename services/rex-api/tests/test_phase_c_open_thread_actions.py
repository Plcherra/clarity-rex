"""Phase C: open-thread create/update via gated Grok actions."""

from __future__ import annotations

import pytest

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import BrainAction, parse_brain_actions
from app.services.capability_dispatcher import dispatch_allowed_actions
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_finalize import finalize_grok_turn
from app.services.clarity_action_parser import ClarityActionParser
from app.services.durable_write_service import DurableWriteService
from app.services.prompt_open_threads_context import format_open_threads_context
from app.services.tiny_system_prompt import build_tiny_system_prompt


class _FakePendingStore:
    def __init__(self) -> None:
        self.user_id = "user-1"
        self.access_token = "token"
        self.pending: dict[str, object] = {}
        self.messages: list[dict] = []
        self.rows: list[dict] = [
            {
                "id": "thread-sleep",
                "title": "Sleep Schedule and Wake Up Everyday At 3am",
                "status": "active",
                "summary": "wake early",
                "user_id": "user-1",
            }
        ]

    async def get_conversation_pending_action(self, conversation_id: str):
        return self.pending.get(conversation_id)

    async def set_conversation_pending_action(self, conversation_id: str, pending_action):
        if pending_action is None:
            self.pending.pop(conversation_id, None)
        else:
            self.pending[conversation_id] = pending_action

    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        message = {
            "id": f"msg-{len(self.messages) + 1}",
            "conversation_id": conversation_id,
            "role": role,
            "content": content,
        }
        self.messages.append(message)
        return message

    async def get_recent_messages(self, conversation_id: str, limit: int = 20) -> list:
        _ = conversation_id
        return list(self.messages)[-limit:]

    async def _list_records(self, table: str, **kwargs) -> list[dict]:
        if table != "open_threads":
            return []
        filters = kwargs.get("filters") or {}
        rows = list(self.rows)
        status = filters.get("status")
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        thread_id = filters.get("id")
        if thread_id is not None:
            rows = [row for row in rows if row.get("id") == thread_id]
        limit = int(kwargs.get("limit") or 50)
        return rows[:limit]

    async def _create_record(self, table: str, body: dict, select: str) -> dict:
        _ = select
        row = {
            "id": f"thread-{len(self.rows) + 1}",
            **body,
            "created_at": "2026-07-18T00:00:00Z",
            "updated_at": "2026-07-18T00:00:00Z",
        }
        self.rows.append(row)
        return row

    async def _update_record(
        self,
        table: str,
        record_id: str,
        *,
        updates: dict,
        select: str,
        empty_detail: str,
    ) -> dict | None:
        _ = table, select, empty_detail
        for row in self.rows:
            if row.get("id") == record_id:
                row.update(updates)
                row["updated_at"] = "2026-07-18T01:00:00Z"
                return row
        return None


@pytest.mark.asyncio
async def test_card_soft_emits_write_proposal() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="card", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={
            "thread_id": "thread-sleep",
            "title": "Wake at 6am",
            "summary": "morning habit",
        },
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="I want to wake at 6am",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
        assistant_reply=(
            "Shifting from 3am to 6am means an earlier bedtime — "
            "what would you cut the night before?"
        ),
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes["write_proposals"]
    assert "earlier bedtime" in result["response"].lower()
    assert "tap confirm" not in result["response"].lower()


@pytest.mark.asyncio
async def test_text_soft_proposes_without_client_cards() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="text", threads=True)
    action = BrainAction(
        name="create_open_thread",
        payload={"title": "Wake at 6am"},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="I want to wake at 6am",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
        assistant_reply="An earlier wake time is doable if bedtime moves too.",
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes.get("write_proposals") == []
    assert changes.get("text_confirmation_pending") is True
    assert "bedtime" in result["response"].lower()
    assert "say yes" in result["response"].lower()


@pytest.mark.asyncio
async def test_off_soft_desire_without_explicit_does_not_dispatch() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="off", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={
            "thread_id": "thread-sleep",
            "title": "Wake at 6am",
        },
        explicit=False,
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="I want to wake up everyday at 6am",
    )
    assert gate.dropped_soft_actions
    assert not gate.allowed_soft_actions
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake up everyday at 6am"},
    )
    assert result is None
    assert not store.pending


@pytest.mark.asyncio
async def test_off_explicit_command_applies_immediately() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="off", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={
            "thread_id": "thread-sleep",
            "title": "Wake up every day at 5am",
            "summary": "shifted schedule",
        },
        explicit=True,
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="update my 3am thread to 5am",
    )
    assert gate.allowed_soft_actions
    assert not gate.dropped_soft_actions
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "update my 3am thread to 5am"},
        assistant_reply="Got it — shifting that wake target to 5am.",
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 0
    assert changes["updated"] == 1
    assert changes.get("text_confirmation_pending") is not True
    assert "updated in goals" in result["response"].lower()
    assert store.pending.get("c1") is None


@pytest.mark.asyncio
async def test_sole_active_thread_create_becomes_update() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="card", threads=True)
    action = BrainAction(
        name="create_open_thread",
        payload={"title": "Sleep Schedule and Wake Up Everyday At 6am"},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="I want to wake at 6am",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
        assistant_reply="That lines up with your existing sleep thread.",
    )
    assert result is not None
    assert result["memory_changes"]["write_proposals"]
    assert "sleep thread" in result["response"].lower()


@pytest.mark.asyncio
async def test_finalize_card_returns_proposed_turn() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "Shifting that wake time means an earlier bedtime — "
        "what would you cut the night before?\n\n"
        "```rex_action\n"
        '{"action":"update_open_thread","payload":{'
        '"thread_id":"thread-sleep",'
        '"title":"Sleep Schedule and Wake Up Everyday At 6am",'
        '"summary":"wake at 6am"'
        "}}\n"
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(mode="card", threads=True),
        brain_message="I want to wake at 6am",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    assert finalized.get("proposed_turn") is not None
    proposed = finalized["proposed_turn"]
    assert proposed["memory_changes"]["write_proposals"]
    # Grok conversation continues; body attaches the card.
    assert "earlier bedtime" in proposed["response"].lower()
    assert "tap confirm to save" not in proposed["response"].lower()


@pytest.mark.asyncio
async def test_text_yes_applies_pending_without_card() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="text", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={
            "thread_id": "thread-sleep",
            "title": "Wake at 6am",
        },
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="I want to wake at 6am",
    )
    proposed = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
        assistant_reply="Earlier wake times need an earlier bedtime.",
    )
    assert proposed is not None
    assert proposed["memory_changes"].get("write_proposals") == []
    assert proposed["memory_changes"].get("text_confirmation_pending") is True

    applied = await durable.try_handle_pending(
        "yes",
        pending_action=store.pending["c1"],
        conversation_id="c1",
        user_message={"id": "u2", "content": "yes"},
    )
    assert applied is not None
    assert applied["memory_changes"].get("confirmation_required", 1) == 0
    assert store.rows[0]["title"] == "Wake at 6am"
    assert applied["memory_changes"].get("write_proposals")  # applied card status ok


@pytest.mark.asyncio
async def test_finalize_off_soft_stays_chat_only() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "Moving from 3am to 6am means an earlier bedtime. "
        "What would you cut the night before?\n\n"
        "```rex_action\n"
        '{"action":"update_open_thread","payload":{'
        '"thread_id":"thread-sleep",'
        '"title":"Wake at 6am"'
        "}}\n"
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(mode="off", threads=True),
        brain_message="I want to wake at 6am",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    assert finalized.get("proposed_turn") is None
    assert "bedtime" in finalized["response"].lower()
    assert not store.pending


@pytest.mark.asyncio
async def test_finalize_propose_scrubs_past_tense_success_before_save() -> None:
    """P0: Truth runs before propose save — no past-tense success on pending turns."""
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "I've updated your sleep thread to wake at 6am. Want me to confirm?\n\n"
        "```rex_action\n"
        '{"action":"update_open_thread","payload":{'
        '"thread_id":"thread-sleep",'
        '"title":"Wake at 6am"}}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(mode="text", threads=True),
        brain_message="update my sleep thread to 6am",
        user_message={"id": "u1", "content": "update my sleep thread to 6am"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    proposed = finalized.get("proposed_turn")
    assert proposed is not None
    lowered = proposed["response"].lower()
    assert "i've updated" not in lowered
    assert "i have updated" not in lowered
    assert "say yes" in lowered or "confirm" in lowered
    # Persisted assistant message must match (Truth before save).
    assert store.messages
    saved = store.messages[-1]["content"].lower()
    assert "i've updated" not in saved
    assert "i have updated" not in saved


@pytest.mark.asyncio
async def test_finalize_off_explicit_applies_immediately() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "Shifting that wake target to 5am — say the word and it's updated.\n\n"
        "```rex_action\n"
        '{"action":"update_open_thread","payload":{'
        '"thread_id":"thread-sleep",'
        '"title":"Wake at 5am"},"explicit":true}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(mode="off", threads=True),
        brain_message="update my 3am thread to 5am",
        user_message={"id": "u1", "content": "update my 3am thread to 5am"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    proposed = finalized.get("proposed_turn")
    assert proposed is not None
    changes = proposed["memory_changes"]
    assert changes["updated"] == 1
    assert changes.get("text_confirmation_pending") is not True
    assert store.pending.get("c1") is None


@pytest.mark.asyncio
async def test_finalize_off_explicit_true_still_applies_immediately() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "I'll update the sleep thread to 5am.\n\n"
        "```rex_action\n"
        '{"action":"update_open_thread","payload":{'
        '"thread_id":"thread-sleep","title":"Wake at 5am"},'
        '"explicit":true,"auto":true}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(mode="off", threads=True),
        brain_message="I want to update my waking time for 5am",
        user_message={
            "id": "u1",
            "content": "I want to update my waking time for 5am",
        },
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    proposed = finalized.get("proposed_turn")
    assert proposed is not None
    assert proposed["memory_changes"]["updated"] == 1
    assert proposed["memory_changes"].get("text_confirmation_pending") is not True


@pytest.mark.asyncio
async def test_finalize_off_claim_without_action_keeps_conversation() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    rex = "I'll update the existing Sleep Schedule thread to 5am."
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(mode="off", threads=True),
        brain_message="Can you update my thread then,",
        user_message={
            "id": "u1",
            "content": "Can you update my thread then,",
        },
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    assert finalized.get("proposed_turn") is None
    lowered = finalized["response"].lower()
    assert "auto suggestions" not in lowered
    assert "keep talking" in lowered or "happy to keep talking" in lowered


@pytest.mark.asyncio
async def test_finalize_card_claim_without_action_keeps_conversation() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    rex = "I'll update the existing Sleep Schedule thread to 5am."
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(mode="card", threads=True),
        brain_message="I want to update my waking time for 5am",
        user_message={
            "id": "u1",
            "content": "I want to update my waking time for 5am",
        },
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    assert finalized.get("proposed_turn") is None
    lowered = finalized["response"].lower()
    assert "auto suggestions" not in lowered
    assert "confirm card" not in lowered
    assert "keep talking" in lowered or "happy to keep talking" in lowered


@pytest.mark.asyncio
async def test_card_conversational_user_message_becomes_short_wake_title() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="card", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={
            "thread_id": "thread-sleep",
            "title": "I want to start waking up at 5am",
        },
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="I want to start waking up at 5am",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to start waking up at 5am"},
        assistant_reply="I'll prepare the change for you to confirm.",
    )
    assert result is not None
    proposals = result["memory_changes"].get("write_proposals") or []
    assert proposals
    title = str(proposals[0].get("title") or "")
    assert title == "Wake at 5am"
    assert "i want" not in title.lower()


@pytest.mark.asyncio
async def test_finalize_card_with_action_returns_write_proposals() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "Want me to update your sleep thread to 5am?\n\n"
        "```rex_action\n"
        '{"action":"update_open_thread","payload":{'
        '"thread_id":"thread-sleep","title":"Wake at 5am"}}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(mode="card", threads=True),
        brain_message="I want to update my waking time for 5am",
        user_message={
            "id": "u1",
            "content": "I want to update my waking time for 5am",
        },
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    proposed = finalized.get("proposed_turn")
    assert proposed is not None
    proposals = proposed["memory_changes"].get("write_proposals") or []
    assert proposals
    assert "5am" in str(proposals[0].get("title") or "").lower()


def test_open_threads_context_includes_ids() -> None:
    rendered = format_open_threads_context(
        [
            {
                "id": "thread-1",
                "status": "active",
                "title": "Morning routine",
            }
        ]
    )
    assert rendered is not None
    assert "thread-1: Morning routine" in rendered
    assert "update_open_thread" in rendered


def test_tiny_system_phase_c_mentions_open_thread_dispatch() -> None:
    prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="card"))
    assert "create_open_thread" in prompt
    assert "update_open_thread" in prompt
    assert "delete_open_thread" not in prompt


@pytest.mark.asyncio
async def test_update_without_thread_id_asks_which_when_multiple() -> None:
    store = _FakePendingStore()
    store.rows.append(
        {
            "id": "thread-gym",
            "title": "Gym three times a week",
            "status": "active",
            "summary": "lift",
            "user_id": "user-1",
        }
    )
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="card", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={"title": "Wake at 6am"},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="update my thread to 6am",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "update my thread to 6am"},
        assistant_reply="Happy to adjust that.",
    )
    assert result is not None
    assert "which open thread" in result["response"].lower()
    assert not store.pending
    assert result["memory_changes"].get("confirmation_required", 0) == 0


@pytest.mark.asyncio
async def test_list_threads_failure_surfaces_error_not_create() -> None:
    class _FailingStore(_FakePendingStore):
        async def _list_records(self, table: str, **kwargs) -> list[dict]:
            raise RuntimeError("supabase down")

    store = _FailingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="text", threads=True)
    action = BrainAction(
        name="create_open_thread",
        payload={"title": "Wake at 6am"},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="I want to wake at 6am",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
        assistant_reply="An earlier wake time is doable.",
    )
    assert result is not None
    assert "couldn't load your open threads" in result["response"].lower()
    assert not store.pending
    assert len(store.rows) == 1  # no duplicate create


@pytest.mark.asyncio
async def test_delete_open_thread_action_is_honest_not_silent() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="card", threads=True)
    action = BrainAction(
        name="delete_open_thread",
        payload={"thread_id": "thread-sleep"},
    )
    # Not a soft action anymore; still must not silently drop if emitted.
    from app.services.auto_suggestions_gate import AutoSuggestionsGateResult

    gate = AutoSuggestionsGateResult(
        mode="card",
        passthrough_actions=[action],
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "delete my sleep thread"},
    )
    assert result is not None
    assert "can't delete" in result["response"].lower()
    assert "goals" in result["response"].lower()
    assert not store.pending


@pytest.mark.asyncio
async def test_empty_title_create_surfaces_clarification() -> None:
    store = _FakePendingStore()
    store.rows = []  # no sole-thread recovery path
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="card", threads=True)
    action = BrainAction(
        name="create_open_thread",
        payload={"title": "   "},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="Yes, please.",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "Yes, please."},
        assistant_reply="Happy to help.",
    )
    assert result is not None
    assert "short title" in result["response"].lower()
    assert "happy to help" in result["response"].lower()
    assert not store.pending


@pytest.mark.asyncio
async def test_update_empty_title_yes_only_reuses_existing_title() -> None:
    """Yes alone can keep the existing title when only the summary is unchanged."""
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="text", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={"title": ""},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="Yes, please.",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "Yes, please."},
        assistant_reply="Want me to update the Sleep Schedule thread?",
    )
    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert result["memory_changes"].get("text_confirmation_pending") is True
    proposal = store.pending["c1"].get("context", {}).get("durable_write_proposal", {})
    assert proposal.get("title") == "Sleep Schedule and Wake Up Everyday At 3am"


@pytest.mark.asyncio
async def test_update_empty_title_uses_typed_title_message() -> None:
    """After clarify, a short typed title must resolve even if Grok omits payload."""
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="text", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={"thread_id": "thread-sleep"},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="Wake at 5:30am",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "Wake at 5:30am"},
        assistant_reply="Got it — say the new title and I'll confirm.",
    )
    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert result["memory_changes"].get("text_confirmation_pending") is True
    proposal = (
        store.pending["c1"]
        .get("context", {})
        .get("durable_write_proposal", {})
    )
    title = str(proposal.get("title") or "")
    assert "5:30" in title


@pytest.mark.asyncio
async def test_update_uses_new_title_alias_and_thread_id() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="card", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={
            "thread_id": "thread-sleep",
            "new_title": "Wake at 5:30am",
        },
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="Yes, please.",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "Yes, please."},
        assistant_reply="On it after you confirm.",
    )
    assert result is not None
    proposals = result["memory_changes"].get("write_proposals") or []
    assert proposals
    assert "5:30" in str(proposals[0].get("title") or "")


@pytest.mark.asyncio
async def test_create_recovers_title_from_short_summary() -> None:
    store = _FakePendingStore()
    store.rows = []
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="text", threads=True)
    action = BrainAction(
        name="create_open_thread",
        payload={"summary": "Wake at 5:30am"},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="I want to wake at 5:30",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake at 5:30"},
        assistant_reply="Solid plan.",
    )
    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert store.pending.get("c1") is not None


@pytest.mark.asyncio
async def test_propose_stores_surface_client_cards_on_pending() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="text", threads=True)
    action = BrainAction(
        name="create_open_thread",
        payload={"title": "Wake at 6am"},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="I want to wake at 6am",
    )
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
        assistant_reply="Earlier bedtime helps.",
    )
    assert result is not None
    pending = store.pending["c1"]
    assert pending["context"]["surface_client_cards"] is False


def test_parse_update_action_with_thread_id() -> None:
    parsed = parse_brain_actions(
        "```rex_action\n"
        '{"action":"update_open_thread","payload":{'
        '"thread_id":"abc","title":"Wake at 6am"},"explicit":true}\n'
        "```"
    )
    assert len(parsed.actions) == 1
    assert parsed.actions[0].payload["thread_id"] == "abc"
    assert parsed.actions[0].explicit is True
