"""Shared helpers for goal capability handlers."""

from __future__ import annotations

from typing import Any, Optional

from app.services.body_display_text import clarification_turn_result
from app.services.durable_write_results import (
    applied_memory_changes,
    failed_memory_changes,
)
from app.services.grok_continuing_reply import continuing_reply_for_goal_apply
from app.services.memory_reference_models import KnowsReferenceMatch
from app.services.memory_reference_resolver import MemoryReferenceResolver
from app.services.memory_text_normalization import normalized_text

BAD_CREATE_REPLY = (
    "I need a short goal title before I can save it. "
    'For example: "Buy 32GB RAM".'
)
MISSING_DEADLINE_REPLY = (
    "I need a due date for that goal before I can save it — "
    "when do you want it done by?"
)
BAD_UPDATE_REPLY = (
    "I need which goal to update and what to change. "
    "Tell me the goal title (or id) and the new details."
)
BAD_DELETE_REPLY = (
    "I need to know which goal to delete (a title or id). "
    "Nothing will be deleted until you confirm."
)
GOAL_NOT_FOUND_REPLY = (
    "I couldn't find that goal in Goals. "
    "Check Goals and tell me the exact title if you still want it changed."
)
GOAL_AMBIGUOUS_REPLY = (
    "I found more than one matching goal. "
    "Tell me the exact title (or id) and I'll confirm before changing it."
)
LIST_FAILED_REPLY = (
    "I couldn't load your goals just now, so I won't create or change "
    "one until that works again. Please try once more in a moment."
)


def with_assistant_reply(assistant_reply: str, fallback: str) -> str:
    base = str(assistant_reply or "").strip()
    if base and fallback.lower() in base.lower():
        return base
    if base:
        return f"{base}\n\n{fallback}"
    return fallback


async def apply_goal_proposal(
    proposal,
    *,
    durable_write_service,
    conversation_id: str,
    user_message: dict,
    assistant_reply: str,
) -> dict:
    result = await durable_write_service.applier.apply_proposal(
        proposal,
        conversation_id=conversation_id,
        source_message_id=str(user_message.get("id") or "") or None,
    )
    if not result.get("applied"):
        reason = str(result.get("reason") or "").strip() or None
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=(
                f"I understood what you wanted about {proposal.title}, "
                "but I couldn't update it just now. Please try again in a moment."
            ),
            memory_changes=failed_memory_changes(proposal=proposal, reason=reason),
        )
    record = result.get("record") or {}
    records = result.get("records") or ([record] if record else [])
    return await clarification_turn_result(
        durable_write_service.memory_service,
        conversation_id=conversation_id,
        user_message=user_message,
        response=continuing_reply_for_goal_apply(
            assistant_reply,
            title=proposal.title,
            write_kind=str(getattr(proposal, "write_kind", "") or ""),
        ),
        memory_changes=applied_memory_changes(
            proposal=proposal,
            record=record,
            merged=bool(result.get("merged")),
            records=records,
            updated_count=result.get("updated_count"),
        ),
    )


async def resolve_plan_by_id_or_reference(
    memory_service: Any,
    *,
    plan_id: Optional[str],
    reference: Optional[str],
) -> KnowsReferenceMatch | str:
    if plan_id:
        try:
            plan = await _plan_by_id(memory_service, plan_id)
        except Exception:
            return LIST_FAILED_REPLY
        if plan is None:
            return GOAL_NOT_FOUND_REPLY
        title = str(plan.get("title") or plan_id).strip() or plan_id
        return KnowsReferenceMatch(
            table="plans",
            id=str(plan.get("id") or plan_id),
            title=title,
            record=plan,
            action="would_update",
        )

    ref = str(reference or "").strip()
    if not ref:
        return BAD_UPDATE_REPLY

    resolver = MemoryReferenceResolver(memory_service)
    exact = await resolver.find_existing_plan(ref)
    if exact is not None:
        title = str(exact.get("title") or ref).strip() or ref
        return KnowsReferenceMatch(
            table="plans",
            id=str(exact.get("id") or ""),
            title=title,
            record=exact,
            action="would_update",
        )

    try:
        plans = await memory_service.list_plans(active=True, limit=100)
    except Exception:
        return LIST_FAILED_REPLY

    key = normalized_text(ref)
    matches = [
        plan
        for plan in plans or []
        if key and key in normalized_text(str(plan.get("title") or ""))
    ]
    if not matches:
        return GOAL_NOT_FOUND_REPLY
    if len(matches) > 1:
        exact_title = [
            plan
            for plan in matches
            if normalized_text(str(plan.get("title") or "")) == key
        ]
        if len(exact_title) == 1:
            matches = exact_title
        else:
            return GOAL_AMBIGUOUS_REPLY
    plan = matches[0]
    title = str(plan.get("title") or ref).strip() or ref
    return KnowsReferenceMatch(
        table="plans",
        id=str(plan.get("id") or ""),
        title=title,
        record=plan,
        action="would_update",
    )


async def _plan_by_id(memory_service: Any, plan_id: str) -> Optional[dict]:
    """Load a plan by id. Propagates list failures to the caller."""
    plans = await memory_service.list_plans(active=True, limit=100)
    for plan in plans or []:
        if str(plan.get("id") or "") == plan_id:
            return plan
    return None
