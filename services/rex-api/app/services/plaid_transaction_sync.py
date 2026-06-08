from __future__ import annotations

from typing import Any, Optional

from app.services.plaid_api_client import PlaidApiClient
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_sync_models import (
    list_of_dicts,
    required_string,
    string_or_none,
    utc_now_iso,
)
from app.services.plaid_transaction_mapper import (
    map_plaid_transaction,
    removed_transaction_id,
)

TRANSACTIONS_TABLE = "transactions"


class PlaidTransactionSync:
    def __init__(
        self,
        *,
        plaid_client: PlaidApiClient,
        cursor_service: PlaidCursorService,
    ) -> None:
        self.plaid_client = plaid_client
        self.cursor_service = cursor_service

    async def sync_transactions(
        self,
        *,
        user_id: str,
        item_id: str,
        access_token: str,
        cursor: Optional[str],
        account_map: dict[str, str],
    ) -> dict[str, Any]:
        added = modified = removed = 0
        next_cursor = cursor
        has_more = True
        while has_more:
            response = await self.plaid_client.sync_transactions(
                access_token,
                cursor=next_cursor,
            )
            for transaction in list_of_dicts(response.get("added")):
                if await self._upsert_transaction(
                    user_id=user_id,
                    item_id=item_id,
                    transaction=transaction,
                    account_map=account_map,
                ):
                    added += 1
            for transaction in list_of_dicts(response.get("modified")):
                if await self._upsert_transaction(
                    user_id=user_id,
                    item_id=item_id,
                    transaction=transaction,
                    account_map=account_map,
                ):
                    modified += 1
            for transaction in list_of_dicts(response.get("removed")):
                if await self._mark_transaction_removed(
                    user_id=user_id,
                    transaction=transaction,
                ):
                    removed += 1
            next_cursor = string_or_none(response.get("next_cursor")) or next_cursor
            has_more = bool(response.get("has_more"))

        await self.cursor_service.update_item_after_sync(item_id, next_cursor)
        return {
            "added": added,
            "modified": modified,
            "removed": removed,
            "next_cursor": next_cursor,
        }

    async def _upsert_transaction(
        self,
        *,
        user_id: str,
        item_id: str,
        transaction: dict[str, Any],
        account_map: dict[str, str],
    ) -> bool:
        plaid_account_id = required_string(transaction, "account_id")
        linked_account_id = account_map.get(plaid_account_id)
        if not linked_account_id:
            return False
        rows = await self.cursor_service.supabase_request(
            "POST",
            TRANSACTIONS_TABLE,
            body=map_plaid_transaction(
                user_id=user_id,
                item_id=item_id,
                linked_account_id=linked_account_id,
                transaction=transaction,
            ),
            query={"on_conflict": "user_id,plaid_transaction_id"},
            prefer="resolution=merge-duplicates,return=minimal",
        )
        del rows
        return True

    async def _mark_transaction_removed(
        self,
        *,
        user_id: str,
        transaction: dict[str, Any],
    ) -> bool:
        transaction_id = removed_transaction_id(transaction)
        if not transaction_id:
            return False
        await self.cursor_service.supabase_request(
            "PATCH",
            TRANSACTIONS_TABLE,
            body={"removed_at": utc_now_iso(), "last_synced_at": utc_now_iso()},
            query={
                "user_id": f"eq.{user_id}",
                "plaid_transaction_id": f"eq.{transaction_id}",
                "source": "eq.plaid",
            },
            prefer="return=minimal",
        )
        return True
