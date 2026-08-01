"""Canonical filters for goals and milestones.

Goals tab, Rex inventory answers, and accountability overview must all use
these helpers so user-visible lists stay aligned.
"""

from __future__ import annotations

OPEN_MILESTONE_STATUSES = frozenset({"open", "in_progress"})
ACTIVE_PLAN_STATUS = "active"
ACHIEVED_PLAN_STATUS = "completed"
ACHIEVED_PLAN_LIMIT = 20


def normalized_status(record: dict, *, default: str) -> str:
    return str(record.get("status") or default).strip().lower()


def is_record_active(record: dict) -> bool:
    return record.get("active") is not False


def active_plans_for(plans: list[dict]) -> list[dict]:
    return [
        plan
        for plan in plans
        if is_record_active(plan)
        and normalized_status(plan, default="active") == ACTIVE_PLAN_STATUS
    ]


def achieved_plans_for(
    plans: list[dict],
    *,
    limit: int = ACHIEVED_PLAN_LIMIT,
) -> list[dict]:
    """Goals the user finished, most recent first.

    A finished goal leaves the active list but not the app — it is the only
    record that the work was done, so Goals keeps the recent ones in reach.
    """
    achieved = [
        plan
        for plan in plans
        if is_record_active(plan)
        and normalized_status(plan, default="active") == ACHIEVED_PLAN_STATUS
    ]
    achieved.sort(key=_achieved_sort_key, reverse=True)
    return achieved[:limit]


def _achieved_sort_key(plan: dict) -> str:
    for key in ("completed_at", "updated_at", "created_at"):
        value = str(plan.get(key) or "").strip()
        if value:
            return value
    return ""


def open_milestones_for(milestones: list[dict]) -> list[dict]:
    return [
        milestone
        for milestone in milestones
        if is_record_active(milestone)
        and normalized_status(milestone, default="open") in OPEN_MILESTONE_STATUSES
    ]


def completed_milestones_for(milestones: list[dict]) -> list[dict]:
    return [
        milestone
        for milestone in milestones
        if is_record_active(milestone)
        and (
            normalized_status(milestone, default="open") in {"completed", "done"}
            or bool(milestone.get("completed_at"))
        )
    ]


def record_display_title(record: dict) -> str:
    for key in ("title", "description", "desired_outcome"):
        value = str(record.get(key) or "").strip()
        if value:
            return value
    return "Untitled"
