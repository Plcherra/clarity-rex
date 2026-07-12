"""Owner-usage privacy helpers: email redaction + access audit logging."""

from __future__ import annotations

import json
import logging
from typing import Any, Optional

LOGGER = logging.getLogger("rex.owner_usage_audit")


def redact_email(email: Optional[str]) -> Optional[str]:
    """Mask local-part; keep domain for admin identification without full email."""
    if email is None:
        return None
    value = str(email).strip()
    if not value or "@" not in value:
        return None
    local, _, domain = value.partition("@")
    if not local or not domain:
        return None
    if len(local) == 1:
        masked_local = "*"
    elif len(local) == 2:
        masked_local = f"{local[0]}*"
    else:
        masked_local = f"{local[0]}***{local[-1]}"
    return f"{masked_local}@{domain.lower()}"


def redact_owner_user_row(row: dict[str, Any]) -> dict[str, Any]:
    sanitized = dict(row)
    if "email" in sanitized:
        sanitized["email"] = redact_email(
            sanitized.get("email") if isinstance(sanitized.get("email"), str) else None
        )
    return sanitized


def redact_owner_users(users: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [redact_owner_user_row(row) for row in users]


def log_owner_usage_access(
    *,
    endpoint: str,
    requester_user_id: str,
    authorized: bool,
    include_emails: bool = False,
) -> None:
    payload = {
        "endpoint": endpoint,
        "requester_user_id": requester_user_id,
        "authorized": authorized,
        "include_emails": include_emails,
    }
    LOGGER.info(
        "owner_usage_access %s",
        json.dumps(payload, sort_keys=True),
    )
