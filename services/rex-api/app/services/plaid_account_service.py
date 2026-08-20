from __future__ import annotations

import logging
import re
from typing import Any

from app.services.plaid_api_client import PlaidApiClient, PlaidApiClientError
from app.services.plaid_account_relink import PlaidAccountRelinkService
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_liability_balances import (
    apply_credit_liability_patch,
    credit_balance_patches_from_liabilities,
)
from app.services.plaid_sync_models import (
    dict_or_empty,
    number_or_none,
    required_string,
    string_or_none,
    utc_now_iso,
)

PLAID_ACCOUNTS_TABLE = "plaid_accounts"
ACCOUNTS_TABLE = "accounts"
_LIABILITY_SKIP_CODES = {
    "INVALID_PRODUCT",
    "PRODUCTS_NOT_SUPPORTED",
    "NO_LIABILITY_ACCOUNTS",
    "ITEM_NOT_SUPPORTED",
    "PRODUCT_NOT_READY",
}

logger = logging.getLogger(__name__)


class PlaidAccountService:
    def __init__(
        self,
        *,
        plaid_client: PlaidApiClient,
        cursor_service: PlaidCursorService,
    ) -> None:
        self.plaid_client = plaid_client
        self.cursor_service = cursor_service
        self.relink_service = PlaidAccountRelinkService(
            cursor_service=cursor_service,
        )

    async def sync_accounts(
        self,
        *,
        user_id: str,
        item_id: str,
        access_token: str,
        institution_id: str | None = None,
        institution_name: str | None = None,
        accounts_response: dict[str, Any] | None = None,
    ) -> dict[str, str]:
        if accounts_response is None:
            accounts_response = await self.plaid_client.get_accounts(access_token)
        await self.relink_service.collapse_duplicate_accounts(
            user_id=user_id,
            institution_name=institution_name,
        )
        liability_patches = await self._credit_liability_patches(access_token)
        account_map: dict[str, str] = {}
        for account in _account_list(accounts_response.get("accounts")):
            plaid_account_id = required_string(account, "account_id")
            account = apply_credit_liability_patch(
                account,
                liability_patches.get(plaid_account_id),
            )
            linked_account = await self._upsert_clarity_account(
                user_id=user_id,
                item_id=item_id,
                plaid_account_id=plaid_account_id,
                institution_name=institution_name,
                account=account,
            )
            linked_account_id = required_string(linked_account, "id")
            await self._upsert_plaid_account(
                user_id=user_id,
                item_id=item_id,
                plaid_account_id=plaid_account_id,
                linked_account_id=linked_account_id,
                institution_name=institution_name,
                account=account,
            )
            account_map[plaid_account_id] = linked_account_id
        await self.relink_service.disconnect_replaced_items(
            user_id=user_id,
            keep_item_id=item_id,
            institution_id=institution_id,
            institution_name=institution_name,
        )
        return account_map

    async def sanitized_accounts_for_item(
        self,
        *,
        user_id: str,
        item_id: str,
    ) -> list[dict[str, Any]]:
        rows = await self.cursor_service.supabase_request(
            "GET",
            PLAID_ACCOUNTS_TABLE,
            query={
                "select": (
                    "item_id,linked_account_id,institution_name,name,"
                    "official_name,mask,account_type,account_subtype,status,"
                    "current_balance,available_balance,credit_limit,iso_currency_code"
                ),
                "user_id": f"eq.{user_id}",
                "item_id": f"eq.{item_id}",
            },
        )
        summaries: list[dict[str, Any]] = []
        for row in rows:
            linked_account_id = string_or_none(row.get("linked_account_id"))
            if not linked_account_id:
                continue
            name = _account_name(
                row,
                institution_name=string_or_none(row.get("institution_name")),
            )
            summaries.append(
                {
                    "linked_account_id": linked_account_id,
                    "plaid_item_record_id": string_or_none(row.get("item_id"))
                    or item_id,
                    "institution_name": string_or_none(
                        row.get("institution_name")
                    ),
                    "name": name,
                    "official_name": string_or_none(row.get("official_name")),
                    "mask": string_or_none(row.get("mask")),
                    "account_type": string_or_none(row.get("account_type")),
                    "account_subtype": string_or_none(
                        row.get("account_subtype")
                    ),
                    "status": string_or_none(row.get("status")) or "active",
                    "current_balance": number_or_none(
                        row.get("current_balance")
                    ),
                    "available_balance": number_or_none(
                        row.get("available_balance")
                    ),
                    "credit_limit": number_or_none(row.get("credit_limit")),
                    "iso_currency_code": string_or_none(
                        row.get("iso_currency_code")
                    ),
                }
            )
        return summaries

    async def _upsert_clarity_account(
        self,
        *,
        user_id: str,
        item_id: str,
        plaid_account_id: str,
        institution_name: str | None,
        account: dict[str, Any],
    ) -> dict[str, Any]:
        balances = dict_or_empty(account.get("balances"))
        body: dict[str, Any] = {
            "user_id": user_id,
            "name": _account_name(account, institution_name=institution_name),
            "type": string_or_none(account.get("subtype"))
            or string_or_none(account.get("type"))
            or "account",
            "institution": institution_name,
            "currency": string_or_none(balances.get("iso_currency_code"))
            or "USD",
            "is_active": True,
            "source": "plaid",
            "plaid_item_record_id": item_id,
            "plaid_account_id": plaid_account_id,
            "sync_status": "active",
            "last_synced_at": utc_now_iso(),
        }
        resolved_balance = _resolve_plaid_balance(
            balances,
            account_type=string_or_none(account.get("type")),
            subtype=string_or_none(account.get("subtype")),
        )
        if resolved_balance is not None:
            body["balance"] = resolved_balance
        existing_id = await self.relink_service.resolve_existing_account_id(
            user_id=user_id,
            plaid_account_id=plaid_account_id,
            institution_name=institution_name,
            mask=string_or_none(account.get("mask")),
            account_type=string_or_none(account.get("type")),
            account_subtype=string_or_none(account.get("subtype")),
        )
        return await self.relink_service.write_clarity_account(
            user_id=user_id,
            existing_id=existing_id,
            body=body,
        )

    async def _credit_liability_patches(
        self,
        access_token: str,
    ) -> dict[str, dict[str, float]]:
        try:
            payload = await self.plaid_client.get_liabilities(access_token)
        except PlaidApiClientError as error:
            code = error.plaid_error_code or ""
            if code not in _LIABILITY_SKIP_CODES:
                logger.warning(
                    "Plaid liabilities fetch failed code=%s",
                    code or "unknown",
                )
            return {}
        return credit_balance_patches_from_liabilities(payload)

    async def _upsert_plaid_account(
        self,
        *,
        user_id: str,
        item_id: str,
        plaid_account_id: str,
        linked_account_id: str,
        institution_name: str | None,
        account: dict[str, Any],
    ) -> None:
        balances = dict_or_empty(account.get("balances"))
        body: dict[str, Any] = {
            "user_id": user_id,
            "item_id": item_id,
            "plaid_account_id": plaid_account_id,
            "linked_account_id": linked_account_id,
            "institution_name": institution_name,
            "name": _account_name(account, institution_name=institution_name),
            "official_name": string_or_none(account.get("official_name")),
            "mask": string_or_none(account.get("mask")),
            "account_type": string_or_none(account.get("type")),
            "account_subtype": string_or_none(account.get("subtype")),
            "status": "active",
            "iso_currency_code": string_or_none(balances.get("iso_currency_code")),
            "unofficial_currency_code": string_or_none(
                balances.get("unofficial_currency_code")
            ),
            "metadata": {},
        }
        current_balance = number_or_none(balances.get("current"))
        available_balance = number_or_none(balances.get("available"))
        credit_limit = number_or_none(balances.get("limit"))
        if current_balance is not None:
            body["current_balance"] = current_balance
        elif available_balance is not None:
            body["current_balance"] = available_balance
        if available_balance is not None:
            body["available_balance"] = available_balance
        if credit_limit is not None:
            body["credit_limit"] = credit_limit
        await self.cursor_service.supabase_request(
            "POST",
            PLAID_ACCOUNTS_TABLE,
            body=body,
            query={"on_conflict": "user_id,plaid_account_id"},
            prefer="resolution=merge-duplicates,return=minimal",
        )


def _account_name(
    account: dict[str, Any],
    *,
    institution_name: str | None = None,
) -> str:
    mask = string_or_none(account.get("mask"))
    candidates = [
        string_or_none(account.get("official_name")),
        string_or_none(account.get("name")),
    ]
    for candidate in candidates:
        if candidate and not _is_generic_account_name(candidate, account=account, mask=mask):
            return candidate
    return _composed_account_name(
        account=account,
        institution_name=institution_name,
        mask=mask,
    )


def _composed_account_name(
    *,
    account: dict[str, Any],
    institution_name: str | None,
    mask: str | None,
) -> str:
    label = _account_type_label(account)
    parts = [
        part
        for part in (
            string_or_none(institution_name),
            label,
            mask,
        )
        if part
    ]
    return " ".join(parts) or "Plaid account"


def _account_type_label(account: dict[str, Any]) -> str:
    subtype = (
        string_or_none(account.get("subtype"))
        or string_or_none(account.get("account_subtype"))
        or ""
    ).lower()
    account_type = (
        string_or_none(account.get("type"))
        or string_or_none(account.get("account_type"))
        or ""
    ).lower()
    labels = {
        "checking": "Checking",
        "savings": "Savings",
        "credit card": "Credit Card",
        "credit_card": "Credit Card",
    }
    if subtype in labels:
        return labels[subtype]
    if account_type == "credit":
        return "Credit Card"
    if account_type == "depository":
        return "Depository"
    return (subtype or account_type or "Account").replace("_", " ").title()


def _is_generic_account_name(
    value: str,
    *,
    account: dict[str, Any],
    mask: str | None,
) -> bool:
    normalized = re.sub(r"[^a-z0-9]+", " ", value.lower())
    normalized = re.sub(r"\s+", " ", normalized).strip()
    if not normalized:
        return True
    label = _account_type_label(account).lower()
    generic_names = {
        "account",
        "plaid account",
        "depository",
        "depository account",
        "credit",
        "credit account",
        "checking",
        "checking account",
        "savings",
        "savings account",
        "credit card",
        "credit card account",
        label,
        f"{label} account",
    }
    if normalized in generic_names:
        return True
    if normalized.startswith(("depository account", "credit account")):
        return True
    if mask and normalized.endswith(f" {mask}"):
        without_mask = normalized[: -len(mask)].strip()
        return without_mask in generic_names
    return False


def _resolve_plaid_balance(
    balances: dict[str, Any],
    *,
    account_type: str | None = None,
    subtype: str | None = None,
) -> float | None:
    current = number_or_none(balances.get("current"))
    available = number_or_none(balances.get("available"))
    kind = f"{subtype or ''} {account_type or ''}".lower()
    is_depository = any(
        token in kind
        for token in (
            "depository",
            "checking",
            "savings",
            "money market",
            "cash management",
        )
    )
    if is_depository and available is not None:
        return available
    if current is not None:
        return current
    return available


def _account_list(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]
