"""Canonical filters for goals and milestones.

Goals tab, Rex inventory answers, and accountability overview must all use
these helpers so user-visible lists stay aligned.
"""

from __future__ import annotations

OPEN_MILESTONE_STATUSES = frozenset({"open", "in_progress"})
ACTIVE_PLAN_STATUS = "active"


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
