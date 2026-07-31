"""Finalize a Grok turn: parse → gate → Truth → open-thread body → save payload."""

from __future__ import annotations

from typing import Any, Optional

from app.services.action_truth_policy import UNEXECUTED_GOAL_FALLBACK
from app.services.action_truth_thread_mutation import (
    CONTINUING_THREAD_HELP_FALLBACK,
    UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK,
)
from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import parse_brain_actions
from app.services.capability_dispatcher import (
    dispatch_allowed_actions,
    dispatch_finance_proposals,
)


async def finalize_grok_turn(
    rex_response: str,
    *,
    clarity_action_parser,
    truth_service,
    durable_write_service,
    proposal_settings: AssistantProposalSettings,
    brain_message: str,
    user_message: dict,
    conversation_id: str,
    conversation_history: list[dict],
    turn_trace,
    ai_messages: list[dict],
    financial_context: Optional[dict] = None,
    finance_fetch_runner=None,
) -> dict[str, Any]:
    """Grok reply always continues; body may attach propose/apply beside it.

    Truth runs before body propose/save so pending turns never persist
    past-tense success claims.
    """
    brain = parse_brain_actions(rex_response)
    gate = apply_auto_suggestions_gate(
        brain.actions,
        proposal_settings,
        user_message=brain_message,
    )

    fence_unsupported = clarity_action_parser.unsupported_actions(rex_response)
    # Legacy ```clarity_action``` fences are not a capability — strip them and
    # let Grok's rex_action finance capabilities drive proposals instead.
    reply_text, _legacy_fences = clarity_action_parser.extract_proposals(
        brain.reply_text,
    )
    if finance_fetch_runner is not None:
        fetched_reply = await finance_fetch_runner(
            (*gate.allowed_soft_actions, *gate.passthrough_actions),
            ai_messages,
        )
        if fetched_reply:
            reply_text = fetched_reply
    finance_proposals = dispatch_finance_proposals(
        gate=gate,
        settings=proposal_settings,
        clarity_action_parser=clarity_action_parser,
        financial_context=financial_context,
    )
    unsupported = _merge_unsupported(gate.unsupported_hints, fence_unsupported)
    assistant_response = truth_service.truthful_generated_response(
        reply_text,
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

    # Body may propose/apply using the truthful reply (not raw Grok claims).
    proposed = await dispatch_allowed_actions(
        gate=gate,
        settings=proposal_settings,
        durable_write_service=durable_write_service,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_history,
        assistant_reply=assistant_response,
    )
    if proposed is not None:
        if finance_proposals:
            proposed["memory_changes"] = clarity_action_parser.with_memory_changes(
                proposed.get("memory_changes"),
                finance_proposals,
            )
        if turn_trace is not None:
            record = getattr(turn_trace, "record_proposal_outcome", None)
            if callable(record):
                changes = proposed.get("memory_changes") or {}
                proposals = changes.get("write_proposals") or []
                record(
                    proposal_kind="threads",
                    write_proposals_count=len(proposals),
                    durable_apply_status=(
                        "applied"
                        if int(changes.get("created") or 0)
                        or int(changes.get("updated") or 0)
                        else "pending"
                    ),
                )
        return {"proposed_turn": proposed}

    # Soft mutate dropped / no body write: never leave "I'll save it directly"
    # or unexecuted-mutation denial copy in the user-visible reply.
    if assistant_response.strip() in {
        UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK,
        UNEXECUTED_GOAL_FALLBACK,
    }:
        assistant_response = CONTINUING_THREAD_HELP_FALLBACK
    memory_changes = clarity_action_parser.with_memory_changes(
        None,
        finance_proposals,
    )
    return {
        "proposed_turn": None,
        "response": assistant_response,
        "memory_changes": memory_changes,
    }


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
