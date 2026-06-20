"""Experimental layered Rex Brain context utilities.

MVP production chat and voice use ChatService + SimpleRexBrain.
"""

from copy import deepcopy
from typing import Any

from app.services.rex_brain_context_models import SENSITIVE_KEY_PARTS


def _fit_mapping_to_budget(
    value: dict[str, Any],
    character_budget: int,
    diagnostics: list[str],
    diagnostic: str,
) -> dict[str, Any]:
    if character_budget <= 0:
        diagnostics.append(diagnostic)
        return {}
    selected: dict[str, Any] = {}
    for key, item in value.items():
        candidate = {**selected, key: item}
        if _estimate_characters(candidate) <= character_budget:
            selected[key] = item
            continue
        if isinstance(item, list):
            fitted = _fit_records_to_budget(
                item,
                max(character_budget - _estimate_characters(selected), 0),
                diagnostics,
                diagnostic,
            )
            if fitted:
                selected[key] = fitted
            else:
                diagnostics.append(diagnostic)
            break
        diagnostics.append(diagnostic)
        break
    return selected


def _fit_records_to_budget(
    records: list[dict[str, Any]],
    character_budget: int,
    diagnostics: list[str],
    diagnostic: str,
) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    used_characters = 0
    for record in records:
        safe_record = _sanitize_value(record)
        record_size = _estimate_characters(safe_record)
        if used_characters + record_size > character_budget:
            diagnostics.append(diagnostic)
            break
        selected.append(safe_record)
        used_characters += record_size
    return selected


def _copy_keys(value: dict[str, Any], keys: tuple[str, ...]) -> dict[str, Any]:
    return {key: deepcopy(value[key]) for key in keys if key in value}


def _sanitize_value(value: Any) -> Any:
    if isinstance(value, dict):
        result: dict[str, Any] = {}
        for key, item in value.items():
            normalized_key = str(key).lower()
            if any(part in normalized_key for part in SENSITIVE_KEY_PARTS):
                continue
            result[str(key)] = _sanitize_value(item)
        return result
    if isinstance(value, list):
        return [_sanitize_value(item) for item in value]
    if isinstance(value, tuple):
        return tuple(_sanitize_value(item) for item in value)
    if isinstance(value, str):
        return _truncate(value, 1200)
    return value


def _truncate(value: str, max_characters: int) -> str:
    if len(value) <= max_characters:
        return value
    return f"{value[: max_characters - 14].rstrip()} [truncated]"


def _memory_rank_key(memory: dict[str, Any]) -> tuple[int, int, str]:
    memory_type = str(memory.get("memory_type") or memory.get("candidate_type") or "")
    content = str(memory.get("content") or memory.get("text") or "")
    is_correction = "correction" in memory_type.lower() or "correction" in content.lower()
    importance = _safe_int(memory.get("importance"), default=3)
    updated = str(memory.get("updated_at") or memory.get("created_at") or "")
    return (0 if is_correction else 1, -importance, _reverse_sortable_string(updated))


def _structured_rank_key(record: dict[str, Any]) -> tuple[int, str]:
    priority = _safe_int(
        record.get("priority", record.get("importance", record.get("severity", 3))),
        default=3,
    )
    updated = str(record.get("updated_at") or record.get("due_at") or record.get("target_date") or "")
    return (-priority, _reverse_sortable_string(updated))


def _accountability_rank_key(signal: dict[str, Any]) -> tuple[int, int, str]:
    severity_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    severity = str(signal.get("severity") or "medium").lower()
    priority = _safe_int(signal.get("priority"), default=3)
    created = str(signal.get("created_at") or signal.get("due_at") or "")
    return (severity_order.get(severity, 2), -priority, _reverse_sortable_string(created))


def _signal_to_dict(signal: Any) -> dict[str, Any]:
    if isinstance(signal, dict):
        return _sanitize_value(signal)
    if hasattr(signal, "model_dump"):
        return _sanitize_value(signal.model_dump())
    if hasattr(signal, "dict"):
        return _sanitize_value(signal.dict())
    return {"value": _truncate(str(signal), 600)}


def _estimate_characters(value: Any) -> int:
    return len(str(value))


def _safe_int(value: Any, *, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _reverse_sortable_string(value: str) -> str:
    # Keep newer ISO-like timestamps ahead in ascending tuple sorts.
    return "".join(chr(255 - ord(character)) for character in value[:64])
