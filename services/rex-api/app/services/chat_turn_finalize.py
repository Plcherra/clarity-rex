"""Finalize a Grok turn: parse → gate → Truth → open-thread body → save payload."""

from __future__ import annotations

from typing import Any, Optional

from app.services.action_truth_policy import response_claims_unconfirmed_success
from app.services.assistant_proposal_settings import (
    PROPOSAL_KIND_GOALS,
    PROPOSAL_KIND_MEMORY,
    PROPOSAL_KIND_THREADS,
    AssistantProposalSettings,
)
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import (
    BrainAction,
    actions_from_tool_calls,
    parse_brain_actions,
)
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
    fetch_runner=None,
    tool_calls=None,
    was_cut_off: bool = False,
) -> dict[str, Any]:
    """Grok reply always continues; body may attach propose/apply beside it.

    Truth runs before body propose/save so pending turns never persist
    past-tense success claims.
    """
    brain = parse_brain_actions(rex_response)
    actions = [*actions_from_tool_calls(tool_calls), *brain.actions]
    gate = apply_auto_suggestions_gate(
        actions,
        proposal_settings,
        user_message=brain_message,
    )

    fence_unsupported = clarity_action_parser.unsupported_actions(rex_response)
    # Legacy ```clarity_action``` fences are not a capability — strip them and
    # let Grok's rex_action finance capabilities drive proposals instead.
    reply_text, _legacy_fences = clarity_action_parser.extract_proposals(
        brain.reply_text,
    )
    fetched = None
    if fetch_runner is not None:
        fetched = await fetch_runner(
            (*gate.allowed_soft_actions, *gate.passthrough_actions),
            ai_messages,
        )
        if fetched is not None and fetched.reply:
            reply_text = fetched.reply
    finance = dispatch_finance_proposals(
        gate=gate,
        settings=proposal_settings,
        clarity_action_parser=clarity_action_parser,
        financial_context=financial_context,
    )
    finance_proposals = finance.proposals
    if finance.has_blocked_changes:
        reply_text = _with_blocked_finance_reason(
            reply_text,
            finance.blocked_message(),
            has_proposals=bool(finance_proposals),
        )
    unsupported = _merge_unsupported(gate.unsupported_hints, fence_unsupported)
    assistant_response = truth_service.truthful_generated_response(
        reply_text,
        finance_proposals,
        unsupported_actions=unsupported,
        intent_decision=None,
        user_message=brain_message,
        # Recall Truth speaks only for a search that actually ran this turn.
        memory_status=fetched.memory_status if fetched else None,
        chat_search_results_loaded=(
            bool(fetched and fetched.chat_history_included)
            or truth_service.has_chat_search_results(ai_messages)
        ),
        conversation_history=conversation_history,
        turn_trace=turn_trace,
    )
    # Last word, so no other guard can bury why the save did not happen.
    blocked_kinds = _kinds_the_user_asked_for_that_are_switched_off(
        gate.dropped_soft_actions,
    )
    if blocked_kinds:
        assistant_response = _with_blocked_write_reason(
            assistant_response,
            blocked_kinds,
        )
    if was_cut_off:
        assistant_response = _with_cut_off_note(
            assistant_response,
            acted=bool(actions),
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

    memory_changes = clarity_action_parser.with_memory_changes(
        None,
        finance_proposals,
    )
    return {
        "proposed_turn": None,
        "response": assistant_response,
        "memory_changes": memory_changes,
    }


_BLOCKED_WRITE_TEXT = {
    PROPOSAL_KIND_GOALS: "goal saves are switched off in Companion settings",
    PROPOSAL_KIND_THREADS: "open thread saves are switched off in Companion settings",
    PROPOSAL_KIND_MEMORY: "memory saves are switched off in Companion settings",
}


def _kinds_the_user_asked_for_that_are_switched_off(
    dropped: list[BrainAction],
) -> list[str]:
    """Kinds the user asked for that a toggle refused.

    Rex's own offers are meant to fall silently in Off mode; a save the user
    actually asked for is different, and going quiet there reads as done.
    """
    kinds: list[str] = []
    for action in dropped:
        kind = action.kind
        if action.auto or kind is None or kind in kinds:
            continue
        kinds.append(kind)
    return kinds


_CUT_OFF_NOTE = "I ran out of room there, so that reply is cut short."
_CUT_OFF_WITHOUT_ACTION_NOTE = (
    "I ran out of room before I could actually do that, so nothing has "
    "happened yet. Ask me again and I'll run it."
)


def _with_cut_off_note(reply_text: str, *, acted: bool) -> str:
    """Say when the model hit its limit instead of shipping a stub as an answer.

    A reply that stops mid-thought looks the same to the user as a reply that
    is simply short — and when it stopped before the capability call, "adding
    this goal" is a promise nothing behind it will keep.
    """
    note = _CUT_OFF_NOTE if acted else _CUT_OFF_WITHOUT_ACTION_NOTE
    cleaned = reply_text.strip()
    if not cleaned:
        return note
    return f"{cleaned}\n\n{note}"


def _with_blocked_write_reason(reply_text: str, kinds: list[str]) -> str:
    reasons = [_BLOCKED_WRITE_TEXT[kind] for kind in kinds if kind in _BLOCKED_WRITE_TEXT]
    if not reasons:
        return reply_text
    reason = (
        f"Nothing was saved — {_join_reasons(reasons)}. "
        "Turn that back on and ask me again."
    )
    cleaned = reply_text.strip()
    if not cleaned:
        return reason
    if response_claims_unconfirmed_success(cleaned):
        return reason
    return f"{cleaned}\n\n{reason}"


def _join_reasons(reasons: list[str]) -> str:
    if len(reasons) == 1:
        return reasons[0]
    return f"{', '.join(reasons[:-1])} and {reasons[-1]}"


def _with_blocked_finance_reason(
    reply_text: str,
    reason: str,
    *,
    has_proposals: bool,
) -> str:
    """Say why a finance change is not happening, keeping any real answer.

    When nothing was prepared, a reply that claims or promises the change has
    to go and the reason takes its place. Otherwise — an answer, a question, or
    a turn where other changes did become cards — the reason rides alongside so
    the dropped piece is never silent.
    """
    if not reason:
        return reply_text
    cleaned = reply_text.strip()
    if not cleaned:
        return reason
    if not has_proposals and response_claims_unconfirmed_success(cleaned):
        return reason
    return f"{cleaned} {reason}"


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
