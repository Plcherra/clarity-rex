"""Finalize a Grok turn: gate → optional open-thread propose → Truth → save payload."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.capability_dispatcher import dispatch_allowed_actions
from app.services.chat_turn_reply import build_truthful_turn_reply


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
    """Return either a full propose turn or {response, memory_changes} for save.

    Keys:
    - proposed_turn: full clarification_turn_result when open-thread proposed
    - response / memory_changes: when just_chat / unsupported / dropped soft
    """
    assistant_response, clarity_proposals, gate = build_truthful_turn_reply(
        rex_response,
        clarity_action_parser=clarity_action_parser,
        truth_service=truth_service,
        proposal_settings=proposal_settings,
        brain_message=brain_message,
        conversation_history=conversation_history,
        turn_trace=turn_trace,
        ai_messages=ai_messages,
    )

    proposed = await dispatch_allowed_actions(
        gate=gate,
        settings=proposal_settings,
        durable_write_service=durable_write_service,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_history,
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
                )
        return {"proposed_turn": proposed}

    memory_changes = clarity_action_parser.with_memory_changes(
        None,
        clarity_proposals,
    )
    return {
        "proposed_turn": None,
        "response": assistant_response,
        "memory_changes": memory_changes,
    }
