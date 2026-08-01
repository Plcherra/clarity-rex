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
    target_amount: Optional[float]
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
    raw_amount = _first_present_key(payload, "target_amount", "amount", "cost")
    amount = _optional_amount(raw_amount)
    return GoalCommand(
        kind="create",
        title=title,
        body=body or title,
        record_type=record_type,
        target_text=target,
        target_amount=0.0 if amount is None else amount,
    )


def update_goal_fields_from_payload(payload: dict[str, Any]) -> Optional[UpdateGoalFields]:
    """Parse update_goal identity and rename fields.

    Lookup (which goal): plan_id / reference / existing_title / target_title /
    goal_title. Never use new_title alone as the find key for a rename.

    Title-only without plan_id/reference: treat as “find goal with this title”
    (existing behavior) — ``title`` is both the find key and the kept title.
    """
    plan_id = _optional_str(
        payload.get("plan_id")
        or payload.get("goal_id")
        or payload.get("id")
        or payload.get("record_id")
    )
    # Explicit find keys only — never new_title.
    explicit_lookup = _optional_str(
        payload.get("reference")
        or payload.get("target_title")
        or payload.get("existing_title")
        or payload.get("goal_title")
    )
    title_field = _optional_str(payload.get("title"))
    new_title_field = _optional_str(payload.get("new_title"))
    body = _optional_str(
        payload.get("description")
        or payload.get("body")
        or payload.get("desired_outcome")
        or payload.get("summary")
    )
    target_date = _optional_str(payload.get("target_date") or payload.get("target_text"))
    target_amount = _optional_amount(
        _first_present_key(payload, "target_amount", "amount", "cost")
    )
    status_raw = _optional_str(payload.get("status"))
    status = status_raw if status_raw in _VALID_STATUSES else None

    if plan_id or explicit_lookup:
        lookup = explicit_lookup
        rename_to = new_title_field or title_field
    elif title_field and new_title_field:
        # title finds the existing goal; new_title is the rename target.
        lookup = title_field
        rename_to = new_title_field
    elif title_field:
        # Title-only: find the goal with this title (no separate rename key).
        lookup = title_field
        rename_to = title_field
    else:
        # new_title alone (or empty identity) cannot identify which goal to update.
        lookup = None
        rename_to = new_title_field

    if not plan_id and not lookup:
        return None
    if not any(
        (rename_to, body, target_date, target_amount is not None, status, plan_id, lookup)
    ):
        return None
    return UpdateGoalFields(
        plan_id=plan_id,
        reference=lookup,
        title=rename_to,
        body=body,
        target_date=target_date,
        target_amount=target_amount,
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


def _optional_amount(value: Any) -> Optional[float]:
    if value is None or value == "":
        return None
    try:
        amount = float(value)
    except (TypeError, ValueError):
        return None
    if amount < 0:
        return 0.0
    return amount


def _first_present_key(payload: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in payload:
            return payload.get(key)
    return None
