"""Build Activity-friendly previous/new/metadata for assistant finance audits."""

from __future__ import annotations

from typing import Any


AUDIT_PREFIX = "_audit_"


def strip_audit_markers(result: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Remove internal audit markers so clients never see them."""
    for row in result:
        for key in list(row.keys()):
            if key.startswith(AUDIT_PREFIX):
                row.pop(key, None)
    return result


def assistant_audit_values(
    *,
    action: str,
    payload: dict[str, Any],
    result: list[dict[str, Any]],
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    """Return (previous_value, new_value, metadata) for mobile Activity subtitles."""
    cleaned = str(action or "").strip()
    previous = _previous_value(cleaned, payload, result)
    new_value = _new_value(cleaned, payload, result)
    metadata: dict[str, Any] = {"clarity_action": cleaned}
    count = _transaction_count(cleaned, payload, result)
    if count is not None:
        metadata["transaction_count"] = count
    merchant = _string(payload.get("merchant"))
    if merchant:
        metadata["merchant"] = merchant
    return previous, new_value, metadata


def _previous_value(
    action: str,
    payload: dict[str, Any],
    result: list[dict[str, Any]],
) -> dict[str, Any]:
    if action in {
        "bulk_update_transaction_category",
        "update_transaction",
    }:
        name = _first_audit_string(result, "previous_category_name")
        category_id = _first_audit_string(result, "previous_category_id")
        out: dict[str, Any] = {}
        if name:
            out["category_name"] = name
        if category_id:
            out["category_id"] = category_id
        if out:
            return out
    return {}


def _new_value(
    action: str,
    payload: dict[str, Any],
    result: list[dict[str, Any]],
) -> dict[str, Any]:
    out: dict[str, Any] = {}
    if action in {
        "bulk_update_transaction_category",
        "update_transaction",
        "create_category",
        "update_category",
        "delete_category",
    }:
        name = (
            _first_audit_string(result, "category_name")
            or _payload_category_name(payload)
            or _result_name(result)
        )
        category_id = _first_audit_string(result, "category_id") or _string(
            payload.get("category_id")
        )
        if not category_id and action.endswith("category") and result:
            category_id = _string(result[0].get("id"))
        if not category_id and result:
            category_id = _string(result[0].get("category_id"))
        if name:
            out["category_name"] = name
            out["name"] = name
        if category_id:
            out["category_id"] = category_id
    if action in {"create_budget", "update_budget", "delete_budget"}:
        name = _string(payload.get("name")) or _result_name(result)
        if name:
            out["name"] = name
    if action in {"create_account", "update_account", "delete_account"}:
        name = _string(payload.get("name")) or _result_name(result)
        if name:
            out["name"] = name
    merchant = _string(payload.get("merchant"))
    if merchant and "category_name" not in out and "name" not in out:
        out["merchant_display"] = merchant
    if not out:
        # Keep a minimal breadcrumb when nothing friendlier is available.
        out["action"] = action
        if result:
            out["result_count"] = len(result)
    return out


def _transaction_count(
    action: str,
    payload: dict[str, Any],
    result: list[dict[str, Any]],
) -> int | None:
    if action not in {
        "bulk_update_transaction_category",
        "update_transaction",
        "delete_transaction",
        "delete_import_batch",
    }:
        return None
    ids = payload.get("ids") or payload.get("transaction_ids")
    if isinstance(ids, list):
        cleaned = [str(value).strip() for value in ids if str(value).strip()]
        if cleaned:
            return len(cleaned)
    if result:
        return len(result)
    return None


def _payload_category_name(payload: dict[str, Any]) -> str | None:
    for key in ("category_name", "category_key", "name"):
        value = _string(payload.get(key))
        if value:
            return value
    nested = payload.get("new_category")
    if isinstance(nested, dict):
        return _string(nested.get("name"))
    return None


def _result_name(result: list[dict[str, Any]]) -> str | None:
    if not result:
        return None
    row = result[0]
    for key in ("name", "category_name"):
        value = _string(row.get(key))
        if value:
            return value
    return None


def _first_audit_string(result: list[dict[str, Any]], suffix: str) -> str | None:
    key = f"{AUDIT_PREFIX}{suffix}"
    for row in result:
        value = _string(row.get(key))
        if value:
            return value
    return None


def _string(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
