"""Privacy-safe structured product events for launch observability.

Emit event names and metadata only — never transcripts, message bodies,
memory content, emails, or Plaid tokens.
"""

from __future__ import annotations

import json
import logging
import threading
from typing import Any, Optional

LOGGER = logging.getLogger("rex.product_events")

_COUNTERS_LOCK = threading.Lock()
_COUNTERS: dict[str, int] = {
    "discipline_list_degraded": 0,
    "write_confirmation_result": 0,
    "voice_stream_error": 0,
    "api_5xx": 0,
    "plaid_exchange_result": 0,
    "plaid_sync_degraded": 0,
    "durable_write_apply_failed": 0,
}


def product_event_counts() -> dict[str, int]:
    with _COUNTERS_LOCK:
        return dict(_COUNTERS)


def reset_product_event_counts() -> None:
    with _COUNTERS_LOCK:
        for key in _COUNTERS:
            _COUNTERS[key] = 0


def emit_product_event(name: str, **fields: Any) -> dict[str, Any]:
    """Log a structured product event and increment an in-process counter."""
    payload: dict[str, Any] = {"event": name}
    for key, value in fields.items():
        if value is None:
            continue
        payload[key] = value

    with _COUNTERS_LOCK:
        if name in _COUNTERS:
            _COUNTERS[name] += 1

    LOGGER.info("product_event %s", json.dumps(payload, sort_keys=True, default=str))
    _add_sentry_breadcrumb(name, payload)
    return payload


def emit_write_confirmation_result(
    *,
    result: str,
    action_type: str,
    write_kind: Optional[str] = None,
) -> dict[str, Any]:
    return emit_product_event(
        "write_confirmation_result",
        result=result,
        action_type=action_type,
        write_kind=write_kind,
    )


def emit_voice_stream_error(
    *,
    code: str,
    status_code: Optional[int] = None,
    error_class: Optional[str] = None,
) -> dict[str, Any]:
    return emit_product_event(
        "voice_stream_error",
        code=code,
        status_code=status_code,
        error_class=error_class,
    )


def emit_api_5xx(
    *,
    status_code: int,
    method: str,
    path: str,
) -> dict[str, Any]:
    return emit_product_event(
        "api_5xx",
        status_code=status_code,
        method=method,
        path=_safe_path(path),
    )


def emit_plaid_exchange_result(
    *,
    result: str,
    status_code: Optional[int] = None,
    sync_status: Optional[str] = None,
) -> dict[str, Any]:
    return emit_product_event(
        "plaid_exchange_result",
        result=result,
        status_code=status_code,
        sync_status=sync_status,
    )


def emit_plaid_sync_degraded(
    *,
    error_class: str,
    status_code: Optional[int] = None,
) -> dict[str, Any]:
    return emit_product_event(
        "plaid_sync_degraded",
        error_class=error_class,
        status_code=status_code,
    )


def emit_discipline_list_degraded(
    *,
    operation: str,
    error_class: str,
    fail_closed: bool,
) -> dict[str, Any]:
    return emit_product_event(
        "discipline_list_degraded",
        operation=operation,
        error_class=error_class,
        fail_closed=fail_closed,
    )


def emit_durable_write_apply_failed(
    *,
    snapshot_type: str,
    reason: str,
    error_class: Optional[str] = None,
) -> dict[str, Any]:
    return emit_product_event(
        "durable_write_apply_failed",
        snapshot_type=snapshot_type,
        reason=reason,
        error_class=error_class,
        action_type=snapshot_type,
    )


def _add_sentry_breadcrumb(name: str, payload: dict[str, Any]) -> None:
    try:
        import sentry_sdk
    except ImportError:  # pragma: no cover - optional until installed
        return
    sentry_sdk.add_breadcrumb(
        category="product",
        message=name,
        level="info",
        data={key: value for key, value in payload.items() if key != "event"},
    )


def _safe_path(path: str) -> str:
    """Redact UUID-looking path segments so admin routes stay useful without IDs."""
    parts: list[str] = []
    for segment in str(path or "").split("/"):
        if not segment:
            parts.append(segment)
            continue
        if _looks_like_id(segment):
            parts.append(":id")
        else:
            parts.append(segment)
    return "/".join(parts) or "/"


def _looks_like_id(segment: str) -> bool:
    cleaned = segment.replace("-", "")
    if len(cleaned) >= 16 and all(ch in "0123456789abcdefABCDEF" for ch in cleaned):
        return True
    return False
