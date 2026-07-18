"""Post-Grok reply pipeline: parse actions → Auto Suggestions gate → Truth."""

from __future__ import annotations

from typing import Optional

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

    Phase B: soft mutates are gated (Off drops autos) but not dispatched.
    write_proposals stay empty until Phase C body handlers land.
    """
    brain = parse_brain_actions(rex_response)
    gate = apply_auto_suggestions_gate(brain.actions, proposal_settings)

    fence_unsupported = clarity_action_parser.unsupported_actions(rex_response)
    reply_after_finance, finance_proposals = clarity_action_parser.extract_proposals(
        brain.reply_text,
    )
    finance_proposals = filter_clarity_action_proposals(
        finance_proposals,
        finance_edits_enabled=proposal_settings.finance_edits_enabled,
    )
    # Phase B: no finance mutate dispatch either — keep Truth honest.
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
    if turn_trace is not None:
        record = getattr(turn_trace, "record_proposal_outcome", None)
        if callable(record):
            record(write_proposals_count=len(gate.write_proposals))
    return truthful, finance_proposals, gate


def memory_changes_for_phase_b(
    clarity_action_parser,
    *,
    clarity_proposals: list[dict],
    gate: AutoSuggestionsGateResult,
) -> Optional[dict]:
    """Phase B gated outputs: no soft write_proposals; optional clarity list."""
    _ = gate  # reserved — Phase C will attach allowed soft proposals here
    return clarity_action_parser.with_memory_changes(None, clarity_proposals)


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
