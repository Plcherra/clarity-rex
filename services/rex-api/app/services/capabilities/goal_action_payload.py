"""Parse create/update/delete goal payloads from Grok actions."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from app.services.body_display_text import GoalCommand, clean_goal_text, plan_type

_VALID_PLAN_TYPES = frozenset(
    {
        "finance",
        "immigration",
        "career",
        "health",
        "dating",
        "housing",
        "creative",
        "personal",
        "other",
    }
)

_VALID_STATUSES = frozenset(
    {"active", "paused", "completed", "abandoned", "archived"}
)


@dataclass(frozen=True)
class UpdateGoalFields:
    plan_id: Optional[str]
    reference: Optional[str]
    title: Optional[str]
    body: Optional[str]
    target_date: Optional[str]
    status: Optional[str]


@dataclass(frozen=True)
class DeleteGoalFields:
    plan_id: Optional[str]
    reference: Optional[str]
    title: Optional[str]


def goal_command_from_payload(payload: dict[str, Any]) -> Optional[GoalCommand]:
    title = _first_nonempty(
        payload.get("title"),
        payload.get("goal_title"),
        payload.get("name"),
    )
    if not title:
        return None
    body = _first_nonempty(
        payload.get("description"),
        payload.get("body"),
        payload.get("desired_outcome"),
        payload.get("summary"),
        title,
    )
    record_type = _plan_type_from_payload(payload, fallback_text=title)
    target = _optional_str(payload.get("target_date") or payload.get("target_text"))
    return GoalCommand(
        kind="create",
        title=title,
        body=body or title,
        record_type=record_type,
        target_text=target,
    )


def update_goal_fields_from_payload(payload: dict[str, Any]) -> Optional[UpdateGoalFields]:
    plan_id = _optional_str(
        payload.get("plan_id")
        or payload.get("goal_id")
        or payload.get("id")
        or payload.get("record_id")
    )
    reference = _optional_str(
        payload.get("reference")
        or payload.get("target_title")
        or payload.get("existing_title")
        or payload.get("goal_title")
    )
    title = _optional_str(payload.get("title") or payload.get("new_title"))
    body = _optional_str(
        payload.get("description")
        or payload.get("body")
        or payload.get("desired_outcome")
        or payload.get("summary")
    )
    target_date = _optional_str(payload.get("target_date") or payload.get("target_text"))
    status_raw = _optional_str(payload.get("status"))
    status = status_raw if status_raw in _VALID_STATUSES else None
    if not plan_id and not reference and not title:
        return None
    if not any((title, body, target_date, status, plan_id, reference)):
        return None
    # Identity: plan_id or explicit reference/existing title only.
    # Never treat a new title as the lookup key (rename would hit the wrong plan).
    # Title-only updates without plan_id/reference mean "find the goal with this title".
    lookup = reference
    if not plan_id and not lookup and title:
        lookup = title
    return UpdateGoalFields(
        plan_id=plan_id,
        reference=lookup,
        title=title,
        body=body,
        target_date=target_date,
        status=status,
    )


def delete_goal_fields_from_payload(payload: dict[str, Any]) -> Optional[DeleteGoalFields]:
    plan_id = _optional_str(
        payload.get("plan_id")
        or payload.get("goal_id")
        or payload.get("id")
        or payload.get("record_id")
    )
    reference = _optional_str(
        payload.get("reference")
        or payload.get("title")
        or payload.get("goal_title")
        or payload.get("target_title")
    )
    if not plan_id and not reference:
        return None
    return DeleteGoalFields(
        plan_id=plan_id,
        reference=reference,
        title=_optional_str(payload.get("title") or payload.get("goal_title")),
    )


def _plan_type_from_payload(payload: dict[str, Any], *, fallback_text: str) -> str:
    raw = _optional_str(payload.get("plan_type") or payload.get("record_type"))
    if raw and raw.casefold() in _VALID_PLAN_TYPES:
        return raw.casefold()
    return plan_type(fallback_text)


def _first_nonempty(*values: Any) -> Optional[str]:
    for value in values:
        text = clean_goal_text(value) if value is not None else ""
        if text:
            return text
    return None


def _optional_str(value: Any) -> Optional[str]:
    text = str(value or "").strip()
    return text or None
