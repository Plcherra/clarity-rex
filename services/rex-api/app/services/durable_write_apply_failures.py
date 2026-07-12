"""Privacy-safe apply failure logging and reason codes for durable writes."""

from __future__ import annotations

import json
import logging
from typing import Any, Optional

from app.services.product_events import emit_durable_write_apply_failed

LOGGER = logging.getLogger("rex.durable_write")

# Keep client/ops reasons short and free of user content or secrets.
_SAFE_REASON_BY_KIND = {
    "memory": "memory_apply_failed",
    "memory_update": "memory_update_apply_failed",
    "plan": "plan_apply_failed",
    "create_plan": "plan_apply_failed",
    "open_thread": "open_thread_apply_failed",
    "bulk_plan_target_date": "bulk_plan_target_date_apply_failed",
    "record_delete": "record_delete_apply_failed",
    "discipline_decision": "discipline_decision_apply_failed",
}


def safe_apply_failure_reason(
    *,
    snapshot_type: str,
    error: BaseException | None = None,
    detail: str | None = None,
) -> str:
    base = _SAFE_REASON_BY_KIND.get(snapshot_type, "durable_write_apply_failed")
    if detail:
        return f"{base}:{detail}"
    if error is not None:
        return f"{base}:{type(error).__name__}"
    return base


def log_durable_write_apply_failure(
    *,
    snapshot_type: str,
    reason: str,
    error: BaseException | None = None,
    conversation_id: str | None = None,
) -> None:
    payload: dict[str, Any] = {
        "snapshot_type": snapshot_type,
        "reason": reason,
        "conversation_id": conversation_id,
    }
    if error is not None:
        payload["error_class"] = type(error).__name__
        message = str(error).strip()
        if message:
            # Cap length; never include raw payloads that may hold user text.
            payload["error_message"] = message[:200]
    LOGGER.warning(
        "durable_write_apply_failed %s",
        json.dumps(payload, sort_keys=True),
    )
    emit_durable_write_apply_failed(
        snapshot_type=snapshot_type,
        reason=reason,
        error_class=type(error).__name__ if error is not None else None,
    )


def apply_failure_result(
    *,
    snapshot_type: str,
    error: BaseException | None = None,
    detail: str | None = None,
    conversation_id: str | None = None,
    extra: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    reason = safe_apply_failure_reason(
        snapshot_type=snapshot_type,
        error=error,
        detail=detail,
    )
    log_durable_write_apply_failure(
        snapshot_type=snapshot_type,
        reason=reason,
        error=error,
        conversation_id=conversation_id,
    )
    result: dict[str, Any] = {"applied": False, "reason": reason}
    if extra:
        result.update(extra)
    return result
