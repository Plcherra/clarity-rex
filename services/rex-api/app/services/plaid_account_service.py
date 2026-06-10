from __future__ import annotations

from typing import Any

from app.services.plaid_api_client import PlaidApiClient
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_sync_models import (
    dict_or_empty,
    first_row,
    number_or_none,
    number_or_zero,
    required_string,
    string_or_none,
    utc_now_iso,
)

PLAID_ACCOUNTS_TABLE = "plaid_accounts"
ACCOUNTS_TABLE = "accounts"


class PlaidAccountService:
    def __init__(
        self,
        *,
        plaid_client: PlaidApiClient,
        cursor_service: PlaidCursorService,
    ) -> None:
        self.plaid_client = plaid_client
        self.cursor_service = cursor_service

    async def sync_accounts(
        self,
        *,
        user_id: str,
        item_id: str,
        access_token: str,
        institution_name: str | None = None,
    ) -> dict[str, str]:
        accounts_response = await self.plaid_client.get_accounts(access_token)
        account_map: dict[str, str] = {}
        for account in _account_list(accounts_response.get("accounts")):
            plaid_account_id = required_string(account, "account_id")
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
        return account_map

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
        rows = await self.cursor_service.supabase_request(
            "POST",
            ACCOUNTS_TABLE,
            body={
                "user_id": user_id,
                "name": _account_name(account),
                "type": string_or_none(account.get("subtype"))
                or string_or_none(account.get("type"))
                or "account",
                "institution": institution_name,
                "balance": number_or_zero(balances.get("current")),
                "currency": string_or_none(balances.get("iso_currency_code"))
                or "USD",
                "is_active": True,
                "source": "plaid",
                "plaid_item_record_id": item_id,
                "plaid_account_id": plaid_account_id,
                "sync_status": "active",
                "last_synced_at": utc_now_iso(),
            },
            query={
                "on_conflict": "user_id,plaid_account_id",
                "select": "id,plaid_account_id",
            },
            prefer="resolution=merge-duplicates,return=representation",
        )
        return first_row(rows, "Supabase account upsert returned no rows.")

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
        await self.cursor_service.supabase_request(
            "POST",
            PLAID_ACCOUNTS_TABLE,
            body={
                "user_id": user_id,
                "item_id": item_id,
                "plaid_account_id": plaid_account_id,
                "linked_account_id": linked_account_id,
                "institution_name": institution_name,
                "name": _account_name(account),
                "official_name": string_or_none(account.get("official_name")),
                "mask": string_or_none(account.get("mask")),
                "account_type": string_or_none(account.get("type")),
                "account_subtype": string_or_none(account.get("subtype")),
                "status": "active",
                "current_balance": number_or_none(balances.get("current")),
                "available_balance": number_or_none(balances.get("available")),
                "iso_currency_code": string_or_none(balances.get("iso_currency_code")),
                "unofficial_currency_code": string_or_none(
                    balances.get("unofficial_currency_code")
                ),
                "metadata": {},
            },
            query={"on_conflict": "user_id,plaid_account_id"},
            prefer="resolution=merge-duplicates,return=minimal",
        )


def _account_name(account: dict[str, Any]) -> str:
    return (
        string_or_none(account.get("name"))
        or string_or_none(account.get("official_name"))
        or "Plaid account"
    )


def _account_list(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]
