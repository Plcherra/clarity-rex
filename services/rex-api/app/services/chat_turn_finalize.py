"""Finalize a Grok turn: parse → gate → Truth → open-thread body → save payload."""

from __future__ import annotations

from typing import Any

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import parse_brain_actions
from app.services.capability_dispatcher import dispatch_allowed_actions


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
    # Strip legacy finance fences from reply text; mutate dispatch is not live.
    reply_text, _ignored_finance = clarity_action_parser.extract_proposals(
        brain.reply_text,
    )
    finance_proposals: list[dict] = []
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
