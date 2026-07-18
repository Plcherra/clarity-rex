"""Phase B: unsupported + Auto Suggestions Off gate + no reply-length."""

from __future__ import annotations

from app.services.action_fence_stream import ActionFenceStreamFilter
from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import BrainAction, parse_brain_actions
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_reply import build_truthful_turn_reply
from app.services.clarity_action_parser import ClarityActionParser
from app.services.tiny_system_prompt import build_tiny_system_prompt


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


def test_email_unsupported_truth_never_claims_sent() -> None:
    parser = ClarityActionParser()
    truth = ChatResponseTruthService()
    rex = (
        "Sent! I emailed example@gmail.com for you.\n\n"
        "```rex_action\n"
        '{"action":"unsupported","capability_hint":"send_email"}\n'
        "```"
    )
    reply, proposals, gate = build_truthful_turn_reply(
        rex,
        clarity_action_parser=parser,
        truth_service=truth,
        proposal_settings=AssistantProposalSettings(mode="off"),
        brain_message="Send an email to example@gmail.com",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    assert proposals == []
    assert gate.unsupported_hints == ["send_email"]
    lowered = reply.lower()
    assert "sent" not in lowered or "won't claim" in lowered or "can't complete" in lowered
    assert "email" in lowered
    assert "draft" in lowered or "think it through" in lowered


def test_off_soft_habit_pipeline_emits_no_proposals() -> None:
    parser = ClarityActionParser()
    truth = ChatResponseTruthService()
    rex = (
        "Wake at 6am sounds good — I can help you stick with it.\n\n"
        "```rex_action\n"
        '{"action":"create_open_thread","payload":{"title":"Wake at 6am"}}\n'
        "```"
    )
    reply, proposals, gate = build_truthful_turn_reply(
        rex,
        clarity_action_parser=parser,
        truth_service=truth,
        proposal_settings=AssistantProposalSettings(mode="off", threads=True),
        brain_message="I want to wake at 6am",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    assert proposals == []
    assert gate.dropped_soft_actions
    assert not gate.allowed_soft_actions
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
