from __future__ import annotations

import logging
from typing import Any

from app.services.plaid_account_identity import (
    normalized_identity_text,
    transaction_fingerprint,
)
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_sync_models import string_or_none

PLAID_ITEMS_TABLE = "plaid_items"
TRANSACTIONS_TABLE = "transactions"
_PAGE_SIZE = 500
logger = logging.getLogger(__name__)


class PlaidTransactionDedupe:
    """Deletes relink copies. Plaid issues new transaction IDs after a relink."""

    def __init__(self, *, cursor_service: PlaidCursorService) -> None:
        self.cursor_service = cursor_service

    async def delete_replaced_item_duplicates(
        self,
        *,
        user_id: str,
        keep_item_id: str | None = None,
    ) -> int:
        if not user_id:
            return 0
        items = await self._load_items(user_id)
        replaced_ids = _replaced_item_ids(items, keep_item_id=keep_item_id)
        keeper_ids = _keeper_item_ids(items, keep_item_id=keep_item_id)
        if not replaced_ids or not keeper_ids:
            return 0
        rows = await self._load_live_transactions(
            user_id,
            item_ids=replaced_ids | keeper_ids,
        )
        keeper_keys = {
            (string_or_none(row.get("account_id")), transaction_fingerprint(row))
            for row in rows
            if string_or_none(row.get("plaid_item_record_id")) in keeper_ids
            and string_or_none(row.get("account_id"))
        }
        deleted = 0
        for row in rows:
            item_id = string_or_none(row.get("plaid_item_record_id"))
            account_id = string_or_none(row.get("account_id"))
            transaction_id = string_or_none(row.get("id"))
            if item_id not in replaced_ids or not account_id or not transaction_id:
                continue
            if (account_id, transaction_fingerprint(row)) not in keeper_keys:
                continue
            await self.cursor_service.supabase_request(
                "DELETE",
                TRANSACTIONS_TABLE,
                query={
                    "user_id": f"eq.{user_id}",
                    "id": f"eq.{transaction_id}",
                },
                prefer="return=minimal",
            )
            deleted += 1
        if deleted:
            logger.info(
                "Deleted replaced-item Plaid duplicates user=%s count=%s",
                user_id[-8:],
                deleted,
            )
        return deleted

    async def _load_items(self, user_id: str) -> list[dict[str, Any]]:
        return await self.cursor_service.supabase_request(
            "GET",
            PLAID_ITEMS_TABLE,
            query={
                "select": "id,institution_id,institution_name,status",
                "user_id": f"eq.{user_id}",
            },
        )

    async def _load_live_transactions(
        self,
        user_id: str,
        *,
        item_ids: set[str],
    ) -> list[dict[str, Any]]:
        if not item_ids:
            return []
        joined = ",".join(sorted(item_ids))
        rows: list[dict[str, Any]] = []
        offset = 0
        while True:
            batch = await self.cursor_service.supabase_request(
                "GET",
                TRANSACTIONS_TABLE,
                query={
                    "select": (
                        "id,account_id,date,amount,merchant,description,type,"
                        "pending,removed_at,plaid_item_record_id"
                    ),
                    "user_id": f"eq.{user_id}",
                    "plaid_item_record_id": f"in.({joined})",
                    "removed_at": "is.null",
                    "limit": str(_PAGE_SIZE),
                    "offset": str(offset),
                },
            )
            rows.extend(batch)
            if len(batch) < _PAGE_SIZE:
                return rows
            offset += _PAGE_SIZE


def _replaced_item_ids(
    items: list[dict[str, Any]],
    *,
    keep_item_id: str | None,
) -> set[str]:
    keepers = _keeper_item_ids(items, keep_item_id=keep_item_id)
    keep_institutions = {
        _institution_key(row)
        for row in items
        if string_or_none(row.get("id")) in keepers
    }
    replaced: set[str] = set()
    for row in items:
        item_id = string_or_none(row.get("id"))
        if not item_id or item_id in keepers:
            continue
        if string_or_none(row.get("status")) != "disconnected":
            continue
        if _institution_key(row) not in keep_institutions:
            continue
        replaced.add(item_id)
    return replaced


def _keeper_item_ids(
    items: list[dict[str, Any]],
    *,
    keep_item_id: str | None,
) -> set[str]:
    if keep_item_id:
        return {keep_item_id}
    return {
        item_id
        for row in items
        if (item_id := string_or_none(row.get("id")))
        and string_or_none(row.get("status")) != "disconnected"
    }


def _institution_key(row: dict[str, Any]) -> tuple[str, str]:
    return (
        string_or_none(row.get("institution_id")) or "",
        normalized_identity_text(row.get("institution_name")),
    )
