from __future__ import annotations

import logging
from typing import Any, Optional

from app.services.plaid_api_client import PlaidApiClient
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_sync_models import (
    list_of_dicts,
    number_or_zero,
    required_string,
    string_or_none,
    utc_now_iso,
)
from app.services.plaid_category_mapper import (
    clarity_category_for_plaid_transaction,
    normalized_category_key,
)
from app.services.plaid_transaction_mapper import (
    map_plaid_transaction,
    removed_transaction_id,
)

TRANSACTIONS_TABLE = "transactions"
CATEGORIES_TABLE = "categories"
logger = logging.getLogger(__name__)


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
        pages = 0
        pending_seen = 0
        dates_seen: list[str] = []
        next_cursor = cursor
        has_more = True
        category_cache = await self._load_category_cache(user_id)
        while has_more:
            response = await self.plaid_client.sync_transactions(
                access_token,
                cursor=next_cursor,
            )
            pages += 1
            added_rows = list_of_dicts(response.get("added"))
            modified_rows = list_of_dicts(response.get("modified"))
            removed_rows = list_of_dicts(response.get("removed"))
            for transaction in [*added_rows, *modified_rows]:
                if transaction.get("pending") is True:
                    pending_seen += 1
                date = string_or_none(transaction.get("date"))
                if date:
                    dates_seen.append(date)
            for transaction in added_rows:
                if await self._upsert_transaction(
                    user_id=user_id,
                    item_id=item_id,
                    transaction=transaction,
                    account_map=account_map,
                    category_cache=category_cache,
                ):
                    added += 1
            for transaction in modified_rows:
                if await self._upsert_transaction(
                    user_id=user_id,
                    item_id=item_id,
                    transaction=transaction,
                    account_map=account_map,
                    category_cache=category_cache,
                ):
                    modified += 1
            for transaction in removed_rows:
                if await self._mark_transaction_removed(
                    user_id=user_id,
                    transaction=transaction,
                ):
                    removed += 1
            next_cursor = string_or_none(response.get("next_cursor")) or next_cursor
            has_more = bool(response.get("has_more"))

        await self.cursor_service.update_item_after_sync(item_id, next_cursor)
        backfilled = await self._backfill_uncategorized_plaid_transactions(
            user_id=user_id,
            category_cache=category_cache,
        )
        logger.info(
            "plaid_transaction_sync_complete user_id=%s item_id=%s pages=%s "
            "added=%s modified=%s removed=%s pending_seen=%s date_min=%s "
            "date_max=%s category_backfilled=%s",
            user_id,
            item_id,
            pages,
            added,
            modified,
            removed,
            pending_seen,
            min(dates_seen) if dates_seen else None,
            max(dates_seen) if dates_seen else None,
            backfilled,
        )
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
        category_cache: dict[str, str],
    ) -> bool:
        plaid_account_id = required_string(transaction, "account_id")
        linked_account_id = account_map.get(plaid_account_id)
        if not linked_account_id:
            return False
        category_id = await self._category_id_for_transaction(
            user_id=user_id,
            transaction=transaction,
            category_cache=category_cache,
        )
        rows = await self.cursor_service.supabase_request(
            "POST",
            TRANSACTIONS_TABLE,
            body=map_plaid_transaction(
                user_id=user_id,
                item_id=item_id,
                linked_account_id=linked_account_id,
                transaction=transaction,
                category_id=category_id,
            ),
            query={"on_conflict": "user_id,plaid_transaction_id"},
            prefer="resolution=merge-duplicates,return=minimal",
        )
        del rows
        return True

    async def _load_category_cache(self, user_id: str) -> dict[str, str]:
        rows = await self.cursor_service.supabase_request(
            "GET",
            CATEGORIES_TABLE,
            query={
                "select": "id,name,normalized_name",
                "user_id": f"eq.{user_id}",
            },
        )
        cache: dict[str, str] = {}
        for row in rows:
            category_id = string_or_none(row.get("id"))
            raw_key = string_or_none(row.get("normalized_name")) or string_or_none(
                row.get("name")
            )
            if not category_id or not raw_key:
                continue
            key = normalized_category_key(raw_key)
            if key:
                cache[key] = category_id
        return cache

    async def _category_id_for_transaction(
        self,
        *,
        user_id: str,
        transaction: dict[str, Any],
        category_cache: dict[str, str],
    ) -> Optional[str]:
        category_name = clarity_category_for_plaid_transaction(transaction)
        key = normalized_category_key(category_name)
        if not key:
            return None
        cached = category_cache.get(key)
        if cached:
            return cached

        rows = await self.cursor_service.supabase_request(
            "POST",
            CATEGORIES_TABLE,
            body={
                "user_id": user_id,
                "name": category_name,
                "normalized_name": key,
                "type": "income" if category_name.startswith("Income") else "expense",
            },
            query={
                "on_conflict": "user_id,normalized_name",
                "select": "id,name,normalized_name",
            },
            prefer="resolution=merge-duplicates,return=representation",
        )
        if not rows:
            return None
        category_id = string_or_none(rows[0].get("id"))
        if category_id:
            category_cache[key] = category_id
        return category_id

    async def _backfill_uncategorized_plaid_transactions(
        self,
        *,
        user_id: str,
        category_cache: dict[str, str],
    ) -> int:
        rows = await self.cursor_service.supabase_request(
            "GET",
            TRANSACTIONS_TABLE,
            query={
                "select": "id,description,merchant,amount,type",
                "user_id": f"eq.{user_id}",
                "source": "eq.plaid",
                "category_id": "is.null",
                "removed_at": "is.null",
            },
        )
        updated = 0
        for row in list_of_dicts(rows):
            transaction_id = string_or_none(row.get("id"))
            if not transaction_id:
                continue
            amount = number_or_zero(row.get("amount"))
            if string_or_none(row.get("type")) == "income":
                amount = -amount
            category_id = await self._category_id_for_transaction(
                user_id=user_id,
                transaction={
                    "name": string_or_none(row.get("description")),
                    "merchant_name": string_or_none(row.get("merchant")),
                    "amount": amount,
                },
                category_cache=category_cache,
            )
            if not category_id:
                continue
            await self.cursor_service.supabase_request(
                "PATCH",
                TRANSACTIONS_TABLE,
                body={
                    "category_id": category_id,
                    "last_synced_at": utc_now_iso(),
                },
                query={
                    "id": f"eq.{transaction_id}",
                    "user_id": f"eq.{user_id}",
                    "source": "eq.plaid",
                    "category_id": "is.null",
                },
                prefer="return=minimal",
            )
            updated += 1
        return updated

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
