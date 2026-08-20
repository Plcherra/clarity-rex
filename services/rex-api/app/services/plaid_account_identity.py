from __future__ import annotations

from typing import Any

from app.services.plaid_sync_models import string_or_none


def normalized_identity_text(value: Any) -> str:
    text = string_or_none(value)
    if text is None:
        return ""
    return " ".join(text.strip().lower().split())


def normalized_mask(value: Any) -> str:
    text = string_or_none(value)
    if text is None:
        return ""
    return "".join(character for character in text if character.isalnum()).lower()


def plaid_account_identity(
    *,
    institution_name: Any,
    mask: Any,
    account_type: Any,
    account_subtype: Any,
) -> tuple[str, str, str, str] | None:
    """Stable key for the same real-world account across Plaid relinks.

    A new Plaid Item issues new account IDs. Institution + mask + type still
    identify the same checking, savings, or card.
    """
    institution = normalized_identity_text(institution_name)
    mask_value = normalized_mask(mask)
    if not institution or not mask_value:
        return None
    subtype = normalized_identity_text(account_subtype)
    account_kind = normalized_identity_text(account_type)
    kind = subtype or account_kind
    if not kind:
        return None
    return (institution, mask_value, account_kind or kind, kind)


def transaction_fingerprint(row: dict[str, Any]) -> tuple[str, str, str, str, str]:
    date = str(row.get("date") or "").strip()
    amount = str(row.get("amount") or "").strip()
    label = normalized_identity_text(
        row.get("merchant") or row.get("description") or row.get("name")
    )
    kind = normalized_identity_text(row.get("type"))
    pending = "1" if row.get("pending") is True else "0"
    return (date, amount, label, kind, pending)
