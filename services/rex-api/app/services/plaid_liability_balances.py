from __future__ import annotations

from typing import Any

from app.services.plaid_sync_models import dict_or_empty, number_or_none, string_or_none


def credit_balance_patches_from_liabilities(
    payload: dict[str, Any],
) -> dict[str, dict[str, float]]:
    """Fill missing credit leftover/limit from /liabilities/get.

    Does not overwrite values Plaid already sent on the account balances object.
    """
    patches: dict[str, dict[str, float]] = {}
    for account in _dict_rows(payload.get("accounts")):
        account_id = string_or_none(account.get("account_id"))
        account_type = (string_or_none(account.get("type")) or "").lower()
        if not account_id or account_type not in {"credit", "credit card"}:
            continue
        balances = dict_or_empty(account.get("balances"))
        _merge_patch(
            patches,
            account_id,
            available=number_or_none(balances.get("available")),
            limit=number_or_none(balances.get("limit")),
        )
    liabilities = dict_or_empty(payload.get("liabilities"))
    for credit in _dict_rows(liabilities.get("credit")):
        account_id = string_or_none(credit.get("account_id"))
        if not account_id:
            continue
        _merge_patch(
            patches,
            account_id,
            available=number_or_none(credit.get("available_credit")),
            limit=number_or_none(
                credit.get("credit_limit") or credit.get("limit")
            ),
        )
    return patches


def apply_credit_liability_patch(
    account: dict[str, Any],
    patch: dict[str, float] | None,
) -> dict[str, Any]:
    if not patch:
        return account
    balances = dict(dict_or_empty(account.get("balances")))
    if (
        patch.get("available") is not None
        and number_or_none(balances.get("available")) is None
    ):
        balances["available"] = patch["available"]
    if (
        patch.get("limit") is not None
        and number_or_none(balances.get("limit")) is None
    ):
        balances["limit"] = patch["limit"]
    return {**account, "balances": balances}


def _merge_patch(
    patches: dict[str, dict[str, float]],
    account_id: str,
    *,
    available: float | None,
    limit: float | None,
) -> None:
    patch = patches.setdefault(account_id, {})
    if available is not None and "available" not in patch:
        patch["available"] = available
    if limit is not None and "limit" not in patch:
        patch["limit"] = limit


def _dict_rows(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]
