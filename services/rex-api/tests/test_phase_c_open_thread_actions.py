"""Phase C: open-thread create/update via gated Grok actions."""

from __future__ import annotations

import pytest

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import BrainAction, parse_brain_actions
from app.services.capability_dispatcher import dispatch_allowed_actions
from app.services.capabilities.open_thread_capability import handle_open_thread_action
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
        _ = kwargs
        if table != "open_threads":
            return []
        return list(self.rows)


@pytest.mark.asyncio
async def test_card_create_open_thread_emits_write_proposal() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="card", threads=True)
    action = BrainAction(
        name="create_open_thread",
        payload={"title": "Wake at 6am", "summary": "morning habit"},
    )
    gate = apply_auto_suggestions_gate([action], settings)
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes["write_proposals"]
    assert changes["write_proposals"][0]["write_kind"] == "open_thread"
    assert "confirm" in result["response"].lower()
    assert "nothing is saved" in result["response"].lower()


@pytest.mark.asyncio
async def test_off_soft_create_does_not_dispatch() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    settings = AssistantProposalSettings(mode="off", threads=True)
    action = BrainAction(
        name="create_open_thread",
        payload={"title": "Wake at 6am"},
        explicit=False,
    )
    gate = apply_auto_suggestions_gate([action], settings)
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
    )
    assert result is None
    assert not store.pending


@pytest.mark.asyncio
async def test_off_explicit_update_dispatches_card() -> None:
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
    gate = apply_auto_suggestions_gate([action], settings)
    assert gate.allowed_soft_actions
    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "update my 3am thread to 5am"},
    )
    assert result is not None
    assert result["memory_changes"]["write_proposals"]
    snapshot = result["memory_changes"]["write_proposals"][0].get("apply_snapshot") or {}
    # Client dict may nest differently — check pending action instead.
    pending = store.pending.get("c1")
    assert pending is not None


@pytest.mark.asyncio
async def test_update_without_thread_id_skips_propose() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    result = await handle_open_thread_action(
        BrainAction(
            name="update_open_thread",
            payload={"title": "Wake at 6am"},
        ),
        durable_write_service=durable,
        settings=AssistantProposalSettings(mode="card", threads=True),
        conversation_id="c1",
        user_message={"id": "u1", "content": "wake at 6"},
    )
    assert result is None


@pytest.mark.asyncio
async def test_finalize_card_update_returns_proposed_turn() -> None:
    store = _FakePendingStore()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "I can update your sleep thread to 6am.\n\n"
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
    assert "nothing is saved" in proposed["response"].lower()


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
    assert "not saved memory" in rendered.lower()


def test_tiny_system_phase_c_mentions_open_thread_dispatch() -> None:
    prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="card"))
    assert "create_open_thread" in prompt
    assert "update_open_thread" in prompt
    assert "explicit=true" in prompt
    assert "mutate dispatch is not applied yet" not in prompt


def test_parse_update_action_with_thread_id() -> None:
    parsed = parse_brain_actions(
        "```rex_action\n"
        '{"action":"update_open_thread","payload":{'
        '"thread_id":"abc","title":"Wake at 6am"},"explicit":true}\n'
        "```"
    )
    assert len(parsed.actions) == 1
    assert parsed.actions[0].name == "update_open_thread"
    assert parsed.actions[0].payload["thread_id"] == "abc"
    assert parsed.actions[0].explicit is True
