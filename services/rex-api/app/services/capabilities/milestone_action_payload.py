"""Parse create/update/delete milestone payloads from Grok actions."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from app.services.body_display_text import clean_goal_text

_VALID_STATUSES = frozenset(
    {"open", "in_progress", "completed", "missed", "canceled"}
)


@dataclass(frozen=True)
class CreateMilestoneFields:
    title: str
    plan_id: Optional[str]
    parent_reference: Optional[str]
    description: Optional[str]
    target_date: Optional[str]


@dataclass(frozen=True)
class UpdateMilestoneFields:
    milestone_id: Optional[str]
    plan_id: Optional[str]
    parent_reference: Optional[str]
    reference: Optional[str]
    title: Optional[str]
    description: Optional[str]
    target_date: Optional[str]
    status: Optional[str]


@dataclass(frozen=True)
class DeleteMilestoneFields:
    milestone_id: Optional[str]
    plan_id: Optional[str]
    parent_reference: Optional[str]
    reference: Optional[str]
    title: Optional[str]


def create_milestone_fields_from_payload(
    payload: dict[str, Any],
) -> Optional[CreateMilestoneFields]:
    title = _first_nonempty(
        payload.get("title"),
        payload.get("milestone_title"),
        payload.get("name"),
    )
    if not title:
        return None
    plan_id = _optional_str(
        payload.get("plan_id")
        or payload.get("goal_id")
        or payload.get("parent_plan_id")
    )
    # Explicit parent keys only — never bare `reference` (that means the
    # milestone on update/delete and would break single-goal auto-pick).
    parent_reference = _optional_str(
        payload.get("goal_title")
        or payload.get("plan_title")
        or payload.get("parent_title")
        or payload.get("parent_reference")
    )
    description = _optional_str(
        payload.get("description")
        or payload.get("body")
        or payload.get("summary")
    )
    target_date = _optional_str(
        payload.get("target_date") or payload.get("target_text")
    )
    return CreateMilestoneFields(
        title=title,
        plan_id=plan_id,
        parent_reference=parent_reference,
        description=description,
        target_date=target_date,
    )


def update_milestone_fields_from_payload(
    payload: dict[str, Any],
) -> Optional[UpdateMilestoneFields]:
    """Parse update_milestone identity vs rename (same 05a rule as update_goal).

    Lookup: milestone_id / existing_title / reference / title(+new_title).
    Never use new_title alone as the find key.
    """
    milestone_id = _optional_str(
        payload.get("milestone_id")
        or payload.get("id")
        or payload.get("record_id")
    )
    plan_id = _optional_str(
        payload.get("plan_id")
        or payload.get("goal_id")
        or payload.get("parent_plan_id")
    )
    parent_reference = _optional_str(
        payload.get("goal_title")
        or payload.get("plan_title")
        or payload.get("parent_title")
        or payload.get("parent_reference")
    )
    explicit_lookup = _optional_str(
        payload.get("reference")
        or payload.get("target_title")
        or payload.get("existing_title")
        or payload.get("milestone_title")
    )
    title_field = _optional_str(payload.get("title"))
    new_title_field = _optional_str(payload.get("new_title"))
    description = _optional_str(
        payload.get("description")
        or payload.get("body")
        or payload.get("summary")
    )
    target_date = _optional_str(
        payload.get("target_date") or payload.get("target_text")
    )
    status_raw = _optional_str(payload.get("status"))
    status = status_raw if status_raw in _VALID_STATUSES else None

    if milestone_id or explicit_lookup:
        lookup = explicit_lookup
        rename_to = new_title_field or title_field
    elif title_field and new_title_field:
        lookup = title_field
        rename_to = new_title_field
    elif title_field:
        lookup = title_field
        rename_to = title_field
    else:
        lookup = None
        rename_to = new_title_field

    if not milestone_id and not lookup:
        return None
    if not any(
        (rename_to, description, target_date, status, milestone_id, lookup)
    ):
        return None
    return UpdateMilestoneFields(
        milestone_id=milestone_id,
        plan_id=plan_id,
        parent_reference=parent_reference,
        reference=lookup,
        title=rename_to,
        description=description,
        target_date=target_date,
        status=status,
    )


def delete_milestone_fields_from_payload(
    payload: dict[str, Any],
) -> Optional[DeleteMilestoneFields]:
    milestone_id = _optional_str(
        payload.get("milestone_id")
        or payload.get("id")
        or payload.get("record_id")
    )
    plan_id = _optional_str(
        payload.get("plan_id")
        or payload.get("goal_id")
        or payload.get("parent_plan_id")
    )
    parent_reference = _optional_str(
        payload.get("goal_title")
        or payload.get("plan_title")
        or payload.get("parent_title")
        or payload.get("parent_reference")
    )
    reference = _optional_str(
        payload.get("reference")
        or payload.get("title")
        or payload.get("milestone_title")
        or payload.get("target_title")
        or payload.get("existing_title")
    )
    if not milestone_id and not reference:
        return None
    return DeleteMilestoneFields(
        milestone_id=milestone_id,
        plan_id=plan_id,
        parent_reference=parent_reference,
        reference=reference,
        title=_optional_str(payload.get("title") or payload.get("milestone_title")),
    )


def _first_nonempty(*values: Any) -> Optional[str]:
    for value in values:
        text = clean_goal_text(value) if value is not None else ""
        if text:
            return text
    return None


def _optional_str(value: Any) -> Optional[str]:
    text = str(value or "").strip()
    return text or None
