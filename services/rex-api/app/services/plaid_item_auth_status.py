from __future__ import annotations

from typing import Any

LOGIN_REQUIRED_CODES = frozenset({"ITEM_LOGIN_REQUIRED"})
PENDING_EXPIRATION_CODES = frozenset({"PENDING_EXPIRATION"})


def item_status_from_plaid_error_code(error_code: str | None) -> str | None:
    code = (error_code or "").strip().upper()
    if code in LOGIN_REQUIRED_CODES:
        return "login_required"
    if code in PENDING_EXPIRATION_CODES:
        return "pending_expiration"
    return None


def webhook_auth_status(payload: dict[str, Any]) -> str | None:
    webhook_code = str(payload.get("webhook_code") or "").strip().upper()
    if webhook_code == "ERROR":
        error = payload.get("error")
        code = None
        if isinstance(error, dict):
            code = error.get("error_code")
        return item_status_from_plaid_error_code(
            str(code) if code is not None else None
        )
    return item_status_from_plaid_error_code(webhook_code)
