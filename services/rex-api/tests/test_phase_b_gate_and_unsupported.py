"""Phase B: unsupported + Auto Suggestions Off gate + no reply-length."""

from __future__ import annotations

import pytest

from app.services.action_fence_stream import ActionFenceStreamFilter
from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import BrainAction, parse_brain_actions
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_finalize import finalize_grok_turn
from app.services.clarity_action_parser import ClarityActionParser
from app.services.durable_write_service import DurableWriteService
from app.services.tiny_system_prompt import build_tiny_system_prompt


class _NoPendingStore:
    """Minimal store so finalize can Truth-gate without proposing."""

    def __init__(self) -> None:
        self.user_id = "user-1"
        self.access_token = "token"
        self.pending: dict = {}
        self.messages: list[dict] = []

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
        _ = table, kwargs
        return []


def test_parse_unsupported_rex_action_block() -> None:
    parsed = parse_brain_actions(
        "I can't send email from Clarity, but here's a draft:\n\n"
        "Hi — ...\n\n"
        "```rex_action\n"
        '{"action":"unsupported","capability_hint":"send_email"}\n'
        "```"
    )
    assert "can't send email" in parsed.reply_text.lower()
    assert "rex_action" not in parsed.reply_text
    assert len(parsed.actions) == 1
    assert parsed.actions[0].is_unsupported
    assert parsed.actions[0].capability_hint == "send_email"


def test_gate_off_drops_soft_habit_action() -> None:
    actions = [
        BrainAction(
            name="create_open_thread",
            payload={"title": "Wake at 6am"},
            auto=True,
            explicit=False,
        )
    ]
    off = AssistantProposalSettings(mode="off", threads=True)
    gated = apply_auto_suggestions_gate(
        actions,
        off,
        user_message="I want to wake at 6am",
    )
    assert gated.dropped_soft_actions
    assert not gated.allowed_soft_actions


def test_gate_off_allows_explicit_command() -> None:
    actions = [
        BrainAction(
            name="update_open_thread",
            payload={"thread_id": "t1", "title": "Wake at 5am"},
            explicit=True,
        )
    ]
    off = AssistantProposalSettings(mode="off", threads=True)
    gated = apply_auto_suggestions_gate(
        actions,
        off,
        user_message="update my thread to 5am",
    )
    assert gated.allowed_soft_actions
    assert not gated.dropped_soft_actions


def test_gate_off_runs_a_change_grok_did_not_flag_as_its_own_idea() -> None:
    """Off means "stop offering", so an unflagged save still runs for memory."""
    actions = [
        BrainAction(
            name="save_memory",
            payload={"content": "I am allergic to penicillin"},
        )
    ]
    off = AssistantProposalSettings(mode="off", memory=True)
    gated = apply_auto_suggestions_gate(
        actions,
        off,
        user_message="remember that I'm allergic to penicillin",
    )
    assert gated.allowed_soft_actions
    assert not gated.dropped_soft_actions


def test_gate_off_explicit_respects_kind_toggle() -> None:
    actions = [
        BrainAction(
            name="update_open_thread",
            payload={"thread_id": "t1", "title": "Wake at 5am"},
            explicit=True,
        )
    ]
    off = AssistantProposalSettings(mode="off", threads=False)
    gated = apply_auto_suggestions_gate(
        actions,
        off,
        user_message="update my thread to 5am",
    )
    assert gated.dropped_soft_actions
    assert not gated.allowed_soft_actions


def test_gate_card_keeps_soft_habit_for_later_dispatch() -> None:
    actions = [
        BrainAction(
            name="create_open_thread",
            payload={"title": "Wake at 6am"},
            auto=True,
            explicit=False,
        )
    ]
    card = AssistantProposalSettings(mode="card", threads=True)
    gated = apply_auto_suggestions_gate(
        actions,
        card,
        user_message="I want to wake at 6am",
    )
    assert gated.allowed_soft_actions
    assert not gated.dropped_soft_actions


def test_gate_card_respects_kind_toggle_off() -> None:
    actions = [
        BrainAction(name="create_open_thread", payload={"title": "Wake"}, auto=True)
    ]
    card = AssistantProposalSettings(mode="card", threads=False)
    gated = apply_auto_suggestions_gate(
        actions,
        card,
        user_message="I want to wake at 6am",
    )
    assert gated.dropped_soft_actions
    assert not gated.allowed_soft_actions


@pytest.mark.asyncio
async def test_email_unsupported_truth_never_claims_sent() -> None:
    store = _NoPendingStore()
    rex = (
        "Sent! I emailed example@gmail.com for you.\n\n"
        "```rex_action\n"
        '{"action":"unsupported","capability_hint":"send_email"}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=DurableWriteService(memory_service=store),
        proposal_settings=AssistantProposalSettings(mode="off"),
        brain_message="Send an email to example@gmail.com",
        user_message={"id": "u1", "content": "Send an email to example@gmail.com"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    assert finalized.get("proposed_turn") is None
    reply = finalized["response"]
    lowered = reply.lower()
    assert "sent" not in lowered or "won't claim" in lowered or "can't complete" in lowered
    assert "email" in lowered
    assert "draft" in lowered or "think it through" in lowered


@pytest.mark.asyncio
async def test_off_soft_habit_pipeline_emits_no_proposals() -> None:
    """A wish Rex turned into an offer of its own stays unsaved in Off."""
    store = _NoPendingStore()
    rex = (
        "Wake at 6am sounds good — I can help you stick with it.\n\n"
        "```rex_action\n"
        '{"action":"create_open_thread","auto":true,'
        '"payload":{"title":"Wake at 6am"}}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=DurableWriteService(memory_service=store),
        proposal_settings=AssistantProposalSettings(mode="off", threads=True),
        brain_message="I want to wake at 6am",
        user_message={"id": "u1", "content": "I want to wake at 6am"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    assert finalized.get("proposed_turn") is None
    assert not store.pending
    reply = finalized["response"]
    assert "rex_action" not in reply
    assert "wake" in reply.lower()


def test_tiny_system_has_unsupported_no_response_style() -> None:
    prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="off"))
    assert "unsupported" in prompt.lower()
    assert "rex_action" in prompt
    assert "send_email" in prompt
    assert "update_open_thread" in prompt
    assert "response style" not in prompt.lower()
    assert "concise" not in prompt.lower()
    assert "balanced" not in prompt.lower()
    assert "detailed" not in prompt.lower()


def test_action_fence_stream_hides_rex_action() -> None:
    stream_filter = ActionFenceStreamFilter()
    visible: list[str] = []
    for token in [
        "Draft here. ```rex",
        "_action\n",
        '{"action":"unsupported","capability_hint":"send_email"}',
        "\n``` Thanks.",
    ]:
        visible.extend(stream_filter.feed(token))
    visible.extend(stream_filter.finish())
    text = "".join(visible)
    assert "Draft here." in text
    assert "Thanks." in text
    assert "rex_action" not in text
    assert "send_email" not in text
