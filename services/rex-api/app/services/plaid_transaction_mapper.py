from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any, Optional
from zoneinfo import ZoneInfo

from app.services.plaid_sync_models import (
    number_or_zero,
    required_string,
    string_or_none,
    utc_now_iso,
)

DEFAULT_APP_TIMEZONE = "America/New_York"


def _calendar_date_from_plaid_datetime(
    plaid_dt: str,
    *,
    app_timezone: str = DEFAULT_APP_TIMEZONE,
) -> Optional[str]:
    """Map a Plaid ISO datetime to a user-facing calendar date in app TZ."""
    normalized = plaid_dt.strip()
    if not normalized:
        return None

    try:
        iso = normalized.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(iso)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=ZoneInfo("UTC"))
        local = parsed.astimezone(ZoneInfo(app_timezone))
        return local.date().isoformat()
    except ValueError:
        date_part = normalized.split("T", 1)[0].strip()
        return date_part or None


def _plaid_transaction_date(
    transaction: dict[str, Any],
    *,
    app_timezone: str = DEFAULT_APP_TIMEZONE,
) -> str:
    """Prefer when the user made the purchase over when the bank posted it."""
    authorized = string_or_none(transaction.get("authorized_date"))
    if authorized:
        return authorized

    authorized_dt = string_or_none(transaction.get("authorized_datetime"))
    if authorized_dt:
        calendar_date = _calendar_date_from_plaid_datetime(
            authorized_dt,
            app_timezone=app_timezone,
        )
        if calendar_date:
            return calendar_date

    posted_dt = string_or_none(transaction.get("datetime"))
    if posted_dt:
        calendar_date = _calendar_date_from_plaid_datetime(
            posted_dt,
            app_timezone=app_timezone,
        )
        if calendar_date:
            return calendar_date

    primary = string_or_none(transaction.get("date"))
    if primary:
        return primary

    return utc_now_iso()[:10]


def _uses_posting_date_only(transaction: dict[str, Any]) -> bool:
    if string_or_none(transaction.get("authorized_date")):
        return False
    if string_or_none(transaction.get("authorized_datetime")):
        return False
    if string_or_none(transaction.get("datetime")):
        return False
    return bool(string_or_none(transaction.get("date")))


def _is_next_calendar_day(earlier: str, later: str) -> bool:
    try:
        first = date.fromisoformat(earlier)
        second = date.fromisoformat(later)
    except ValueError:
        return False
    return second - first == timedelta(days=1)


def resolve_plaid_transaction_date(
    transaction: dict[str, Any],
    *,
    app_timezone: str = DEFAULT_APP_TIMEZONE,
    stored_date: Optional[str] = None,
) -> str:
    """Map Plaid payload to stored calendar date, preserving pending-era dates."""
    mapped = _plaid_transaction_date(transaction, app_timezone=app_timezone)
    if (
        stored_date
        and _uses_posting_date_only(transaction)
        and mapped != stored_date
        and _is_next_calendar_day(stored_date, mapped)
    ):
        return stored_date
    return mapped


def map_plaid_transaction(
    *,
    user_id: str,
    item_id: str,
    linked_account_id: str,
    transaction: dict[str, Any],
    category_id: Optional[str] = None,
    app_timezone: str = DEFAULT_APP_TIMEZONE,
    stored_date: Optional[str] = None,
) -> dict[str, Any]:
    amount = number_or_zero(transaction.get("amount"))
    plaid_account_id = required_string(transaction, "account_id")
    plaid_transaction_id = required_string(transaction, "transaction_id")
    payload = {
        "user_id": user_id,
        "account_id": linked_account_id,
        "amount": abs(amount),
        "type": "expense" if amount >= 0 else "income",
        "description": string_or_none(transaction.get("name")),
        "date": resolve_plaid_transaction_date(
            transaction,
            app_timezone=app_timezone,
            stored_date=stored_date,
        ),
        "merchant": string_or_none(transaction.get("merchant_name"))
        or string_or_none(transaction.get("name")),
        "imported_from_csv": False,
        "source": "plaid",
        "plaid_item_record_id": item_id,
        "plaid_account_id": plaid_account_id,
        "plaid_transaction_id": plaid_transaction_id,
        "plaid_pending_transaction_id": string_or_none(
            transaction.get("pending_transaction_id")
        ),
        "pending": bool(transaction.get("pending")),
        "removed_at": None,
        "last_synced_at": utc_now_iso(),
    }
    if category_id:
        payload["category_id"] = category_id
    return payload


def removed_transaction_id(transaction: dict[str, Any]) -> Optional[str]:
    return string_or_none(transaction.get("transaction_id"))
