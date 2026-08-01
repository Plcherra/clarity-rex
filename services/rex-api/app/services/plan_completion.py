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
    """Stamp completed_at on the turn a record becomes completed.

    An explicit completed_at from the caller wins; reopening a record leaves
    the old stamp alone because the transport cannot write a null.
    """
    status = str(payload.get("status") or "").strip().lower()
    if status != COMPLETED_STATUS or payload.get("completed_at"):
        return payload
    moment = now or datetime.now(timezone.utc)
    return {**payload, "completed_at": moment.isoformat()}
