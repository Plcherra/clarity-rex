"""Post-Grok reply pipeline: parse actions → Auto Suggestions gate → Truth."""

from __future__ import annotations

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import (
    AutoSuggestionsGateResult,
    apply_auto_suggestions_gate,
)
from app.services.brain_action_schema import parse_brain_actions
from app.services.clarity_action_proposal_filter import filter_clarity_action_proposals


def build_truthful_turn_reply(
    rex_response: str,
    *,
    clarity_action_parser,
    truth_service,
    proposal_settings: AssistantProposalSettings,
    brain_message: str,
    conversation_history: list[dict],
    turn_trace,
    ai_messages: list[dict],
) -> tuple[str, list[dict], AutoSuggestionsGateResult]:
    """Return (truthful_reply, clarity_proposals, gate_result).

    Soft mutates are gated here; open-thread propose runs in finalize/dispatch.
    """
    brain = parse_brain_actions(rex_response)
    gate = apply_auto_suggestions_gate(
        brain.actions,
        proposal_settings,
        user_message=brain_message,
    )

    fence_unsupported = clarity_action_parser.unsupported_actions(rex_response)
    reply_after_finance, finance_proposals = clarity_action_parser.extract_proposals(
        brain.reply_text,
    )
    finance_proposals = filter_clarity_action_proposals(
        finance_proposals,
        finance_edits_enabled=proposal_settings.finance_edits_enabled,
    )
    # Finance mutate dispatch is not live yet — keep Truth honest.
    finance_proposals = []

    unsupported = _merge_unsupported(gate.unsupported_hints, fence_unsupported)
    truthful = truth_service.truthful_generated_response(
        reply_after_finance,
        finance_proposals,
        unsupported_actions=unsupported,
        intent_decision=None,
        user_message=brain_message,
        memory_status=None,
        chat_search_results_loaded=truth_service.has_chat_search_results(
            ai_messages
        ),
        conversation_history=conversation_history,
        turn_trace=turn_trace,
    )
    return truthful, finance_proposals, gate


def _merge_unsupported(brain_hints: list[str], fence_actions: list[str]) -> list[str]:
    merged: list[str] = []
    seen: set[str] = set()
    for item in [*brain_hints, *fence_actions]:
        key = str(item or "").strip()
        if not key or key in seen:
            continue
        seen.add(key)
        merged.append(key)
    return merged
