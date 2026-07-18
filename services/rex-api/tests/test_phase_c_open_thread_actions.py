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
async def test_off_soft_desire_does_not_dispatch_even_if_grok_marks_explicit() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="off", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={
            "thread_id": "thread-sleep",
            "title": "Wake at 6am",
        },
        explicit=True,
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
async def test_off_command_applies_immediately() -> None:
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
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "update my 3am thread to 5am"},
        assistant_reply="Done shifting that wake target to 5am.",
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes.get("confirmation_required", 0) == 0
    assert int(changes.get("updated") or 0) >= 1 or changes.get("write_proposals")
    assert store.rows[0]["title"] == "Wake up every day at 5am"
    assert "5am" in result["response"].lower()
    assert "goals" in result["response"].lower()


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
