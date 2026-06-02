from __future__ import annotations

from typing import Any


def clean_optional(value: object) -> str | None:
    if value is None:
        return None
    text = " ".join(str(value).split())
    return text or None


def with_preview(row: dict[str, Any]) -> dict[str, Any]:
    return {**row, "preview": preview(row)}


def preview(row: dict[str, Any]) -> str:
    payload = row.get("payload") or {}
    candidate_type = str(row.get("candidate_type") or "memory")
    if candidate_type == "correction":
        correction_preview = correction_preview_text(payload)
        if correction_preview:
            return correction_preview
    title = first_text(
        payload,
        "title",
        "display_name",
        "content",
        "rule_text",
        "commitment_text",
        "new_value",
    )
    action = first_text(payload, "action", "operation")
    if action and title:
        return f"{candidate_type}: {action} {title}"
    if title:
        return f"{candidate_type}: {title}"
    return f"{candidate_type}: pending memory change"


def correction_preview_text(payload: dict[str, Any]) -> str | None:
    intent = payload.get("intent")
    if not isinstance(intent, dict):
        return None
    old_value = clean_optional(intent.get("old_value"))
    new_value = clean_optional(intent.get("new_value"))
    target_hint = clean_optional(intent.get("target_hint"))
    if old_value and new_value:
        return f'correction: replace "{old_value}" with "{new_value}"'
    if new_value and target_hint:
        return f'correction: change "{target_hint}" to "{new_value}"'
    if target_hint:
        return f"correction: review {target_hint}"
    return None


def first_text(payload: dict[str, Any], *keys: str) -> str | None:
    for key in keys:
        value = payload.get(key)
        if value is None:
            continue
        text = clean_optional(value)
        if text:
            return text
    return None
