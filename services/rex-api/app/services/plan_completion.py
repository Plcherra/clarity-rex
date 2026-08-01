"""When a goal or milestone is finished, record when.

Without this the app can list what was achieved but never say when, and
"completed" would rest on a status string alone.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

COMPLETED_STATUS = "completed"


def with_completion_time(
    payload: dict[str, Any],
    *,
    now: datetime | None = None,
) -> dict[str, Any]:
    """Stamp completed_at when finishing; clear it when reopening.

    Reopen must write null — otherwise Goals still shows "Achieved on …" even
    after status is active again, and the undo control looks broken.
    """
    status = str(payload.get("status") or "").strip().lower()
    if not status:
        return payload
    if status == COMPLETED_STATUS:
        if payload.get("completed_at"):
            return payload
        moment = now or datetime.now(timezone.utc)
        return {**payload, "completed_at": moment.isoformat()}
    # Any non-completed status means the goal is open again.
    return {**payload, "completed_at": None}
