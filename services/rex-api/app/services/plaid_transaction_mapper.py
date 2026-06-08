from __future__ import annotations

from typing import Any, Optional

from app.services.plaid_sync_models import (
    number_or_zero,
    required_string,
    string_or_none,
    utc_now_iso,
)


def map_plaid_transaction(
    *,
    user_id: str,
    item_id: str,
    linked_account_id: str,
    transaction: dict[str, Any],
) -> dict[str, Any]:
    amount = number_or_zero(transaction.get("amount"))
    plaid_account_id = required_string(transaction, "account_id")
    plaid_transaction_id = required_string(transaction, "transaction_id")
    return {
        "user_id": user_id,
        "account_id": linked_account_id,
        "amount": abs(amount),
        "type": "expense" if amount >= 0 else "income",
        "description": string_or_none(transaction.get("name")),
        "date": string_or_none(transaction.get("date")) or utc_now_iso()[:10],
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


def removed_transaction_id(transaction: dict[str, Any]) -> Optional[str]:
    return string_or_none(transaction.get("transaction_id"))
