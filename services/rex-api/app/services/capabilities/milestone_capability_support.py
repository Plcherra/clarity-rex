"""Shared helpers for milestone capability handlers."""

from __future__ import annotations

from typing import Any, Optional

from app.services.body_display_text import clarification_turn_result, goal_title
from app.services.capabilities.goal_capability_support import (
    GOAL_AMBIGUOUS_REPLY,
    GOAL_NOT_FOUND_REPLY,
    LIST_FAILED_REPLY,
    resolve_plan_by_id_or_reference,
)
from app.services.durable_write_results import (
    applied_memory_changes,
    failed_memory_changes,
)
from app.services.grok_continuing_reply import continuing_reply_for_goal_apply
from app.services.memory_reference_models import KnowsReferenceMatch
from app.services.memory_text_normalization import normalized_text

BAD_CREATE_REPLY = (
    "I need a short milestone title and which goal it belongs under. "
    'For example: a step "Order RAM" under "Buy 32GB RAM".'
)
BAD_UPDATE_REPLY = (
    "I need which milestone to update and what to change. "
    "Tell me the milestone title (or id) under which goal."
)
BAD_DELETE_REPLY = (
    "I need to know which milestone to delete (a title or id). "
    "Nothing will be deleted until you confirm."
)
MILESTONE_NOT_FOUND_REPLY = (
    "I couldn't find that milestone under Goals. "
    "Check the goal's steps and tell me the exact title if you still want it changed."
)
MILESTONE_AMBIGUOUS_REPLY = (
    "I found more than one matching milestone. "
    "Tell me the exact title (or id) and I'll confirm before changing it."
)
PARENT_REQUIRED_REPLY = (
    "Which goal should this milestone go under? "
    "Tell me the goal title (or id) and I'll confirm before saving."
)
MILESTONE_DELETE_SCOPE = ("plan_milestones",)


def with_assistant_reply(assistant_reply: str, fallback: str) -> str:
    base = str(assistant_reply or "").strip()
    if base and fallback.lower() in base.lower():
        return base
    if base:
        return f"{base}\n\n{fallback}"
    return fallback


def format_parent_goal_choices(plans: list[dict]) -> str:
    titles = [
        str(plan.get("title") or "").strip()
        for plan in plans or []
        if str(plan.get("title") or "").strip()
    ]
    if not titles:
        return PARENT_REQUIRED_REPLY
    listed = "; ".join(titles[:8])
    more = f" (+{len(titles) - 8} more)" if len(titles) > 8 else ""
    return (
        f"{PARENT_REQUIRED_REPLY} Active goals: {listed}{more}."
    )


async def apply_milestone_proposal(
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


async def resolve_parent_plan(
    memory_service: Any,
    *,
    plan_id: Optional[str],
    parent_reference: Optional[str],
    list_when_missing: bool = False,
) -> KnowsReferenceMatch | str:
    if plan_id or parent_reference:
        return await resolve_plan_by_id_or_reference(
            memory_service,
            plan_id=plan_id,
            reference=parent_reference,
        )
    if not list_when_missing:
        return PARENT_REQUIRED_REPLY
    try:
        plans = await memory_service.list_plans(active=True, limit=100)
    except Exception:
        return LIST_FAILED_REPLY
    active = [plan for plan in plans or [] if plan]
    if len(active) == 1:
        plan = active[0]
        title = str(plan.get("title") or plan.get("id") or "").strip()
        return KnowsReferenceMatch(
            table="plans",
            id=str(plan.get("id") or ""),
            title=title,
            record=plan,
            action="would_update",
        )
    return format_parent_goal_choices(active)


async def resolve_milestone_by_id_or_reference(
    memory_service: Any,
    *,
    milestone_id: Optional[str],
    reference: Optional[str],
    plan_id: Optional[str] = None,
    parent_reference: Optional[str] = None,
) -> KnowsReferenceMatch | str:
    if milestone_id:
        try:
            milestone = await _milestone_by_id(memory_service, milestone_id)
        except Exception:
            return LIST_FAILED_REPLY
        if milestone is None:
            return MILESTONE_NOT_FOUND_REPLY
        title = str(milestone.get("title") or milestone_id).strip() or milestone_id
        return KnowsReferenceMatch(
            table="plan_milestones",
            id=str(milestone.get("id") or milestone_id),
            title=title,
            record=milestone,
            action="would_update",
        )

    ref = str(reference or "").strip()
    if not ref:
        return BAD_UPDATE_REPLY

    parent_plan_id: Optional[str] = None
    if plan_id or parent_reference:
        parent = await resolve_plan_by_id_or_reference(
            memory_service,
            plan_id=plan_id,
            reference=parent_reference,
        )
        if isinstance(parent, str):
            if parent in {GOAL_NOT_FOUND_REPLY, GOAL_AMBIGUOUS_REPLY, LIST_FAILED_REPLY}:
                return parent
            return parent
        parent_plan_id = parent.id

    try:
        milestones = await memory_service.list_plan_milestones(
            plan_id=parent_plan_id,
            active=True,
            limit=100,
        )
    except Exception:
        return LIST_FAILED_REPLY

    key = normalized_text(ref)
    matches = [
        row
        for row in milestones or []
        if key and key in normalized_text(str(row.get("title") or ""))
    ]
    if not matches:
        return MILESTONE_NOT_FOUND_REPLY
    if len(matches) > 1:
        exact_title = [
            row
            for row in matches
            if normalized_text(str(row.get("title") or "")) == key
        ]
        if len(exact_title) == 1:
            matches = exact_title
        else:
            return MILESTONE_AMBIGUOUS_REPLY
    milestone = matches[0]
    title = str(milestone.get("title") or ref).strip() or ref
    return KnowsReferenceMatch(
        table="plan_milestones",
        id=str(milestone.get("id") or ""),
        title=title,
        record=milestone,
        action="would_update",
    )


def milestone_title(value: str | None) -> str:
    return goal_title(value or "")


async def _milestone_by_id(
    memory_service: Any, milestone_id: str
) -> Optional[dict]:
    milestones = await memory_service.list_plan_milestones(active=True, limit=100)
    for row in milestones or []:
        if str(row.get("id") or "") == milestone_id:
            return row
    return None
