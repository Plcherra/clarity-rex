"""Detect and split malformed numbered-list goal bodies."""

from __future__ import annotations

import re
from typing import Any

from app.services.goal_command_parsing import (
    expand_goal_save_items,
    is_meta_instruction_body,
    normalize_equipment_goal_title,
    split_compound_goal_bodies,
)

_MALFORMED_NUMBERED_GOAL = re.compile(
    r"^\s*\d+\s+(?:goals?|commitments?)\s*[.:]",
    re.IGNORECASE,
)
_NUMBERED_ITEM_PREFIX = re.compile(r"^\d+[.)]?\s+", re.IGNORECASE)


def _clean_repair_item(text: str) -> str:
    return _NUMBERED_ITEM_PREFIX.sub("", str(text or "").strip()).strip(" .")


def is_malformed_numbered_goal(plan: dict[str, Any]) -> bool:
    for field_name in ("description", "desired_outcome", "title"):
        text = str(plan.get(field_name) or "").strip()
        if not text:
            continue
        if _MALFORMED_NUMBERED_GOAL.search(text):
            return True
        items = split_compound_goal_bodies(text)
        if len(items) > 1 and len(text) > 40:
            return True
    return False


def split_plan_bodies(plan: dict[str, Any]) -> list[str]:
    items = expand_goal_save_items(
        title=str(plan.get("title") or "").strip() or None,
        description=str(plan.get("description") or "").strip() or None,
        desired_outcome=str(plan.get("desired_outcome") or "").strip() or None,
    )
    if not items:
        source = (
            str(plan.get("description") or "").strip()
            or str(plan.get("desired_outcome") or "").strip()
            or str(plan.get("title") or "").strip()
        )
        items = split_compound_goal_bodies(source)
    return [
        normalize_equipment_goal_title(_clean_repair_item(item))
        for item in items
        if item and not is_meta_instruction_body(_clean_repair_item(item))
    ]
