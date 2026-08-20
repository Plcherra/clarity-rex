from __future__ import annotations

import logging
from typing import Any

from app.services.plaid_account_identity import (
    normalized_identity_text,
    plaid_account_identity,
    transaction_fingerprint,
)
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_sync_models import first_row, string_or_none

PLAID_ACCOUNTS_TABLE = "plaid_accounts"
PLAID_ITEMS_TABLE = "plaid_items"
ACCOUNTS_TABLE = "accounts"
TRANSACTIONS_TABLE = "transactions"
logger = logging.getLogger(__name__)


class PlaidAccountRelinkService:
    def __init__(self, *, cursor_service: PlaidCursorService) -> None:
        self.cursor_service = cursor_service

    async def resolve_existing_account_id(
        self,
        *,
        user_id: str,
        plaid_account_id: str,
        institution_name: str | None,
        mask: str | None,
        account_type: str | None,
        account_subtype: str | None,
    ) -> str | None:
        identity = plaid_account_identity(
            institution_name=institution_name,
            mask=mask,
            account_type=account_type,
            account_subtype=account_subtype,
        )
        rows = await self._load_plaid_accounts(
            user_id,
            institution_name=institution_name,
        )
        matches: list[tuple[str, str]] = []
        exact_linked: str | None = None
        for row in rows:
            linked = string_or_none(row.get("linked_account_id"))
            if not linked:
                continue
            if string_or_none(row.get("plaid_account_id")) == plaid_account_id:
                exact_linked = linked
            row_identity = plaid_account_identity(
                institution_name=row.get("institution_name") or institution_name,
                mask=row.get("mask"),
                account_type=row.get("account_type"),
                account_subtype=row.get("account_subtype"),
            )
            if identity is not None and row_identity == identity:
                matches.append((str(row.get("created_at") or ""), linked))
        if matches:
            accounts = await self._load_accounts(
                user_id,
                [linked for _created, linked in matches],
            )
            return _oldest_account_id(accounts, fallback=sorted(matches)[0][1])
        return exact_linked

    async def write_clarity_account(
        self,
        *,
        user_id: str,
        existing_id: str | None,
        body: dict[str, Any],
    ) -> dict[str, Any]:
        plaid_account_id = string_or_none(body.get("plaid_account_id"))
        if existing_id and plaid_account_id:
            await self._release_plaid_account_id(
                user_id=user_id,
                plaid_account_id=plaid_account_id,
                keep_account_id=existing_id,
            )
            rows = await self.cursor_service.supabase_request(
                "PATCH",
                ACCOUNTS_TABLE,
                body=body,
                query={
                    "user_id": f"eq.{user_id}",
                    "id": f"eq.{existing_id}",
                    "select": "id,plaid_account_id",
                },
                prefer="return=representation",
            )
            return first_row(rows, "Supabase account update returned no rows.")
        rows = await self.cursor_service.supabase_request(
            "POST",
            ACCOUNTS_TABLE,
            body=body,
            query={
                "on_conflict": "user_id,plaid_account_id",
                "select": "id,plaid_account_id",
            },
            prefer="resolution=merge-duplicates,return=representation",
        )
        return first_row(rows, "Supabase account upsert returned no rows.")

    async def collapse_duplicate_accounts(
        self,
        *,
        user_id: str,
        institution_name: str | None,
    ) -> None:
        if not institution_name or not user_id:
            return
        rows = await self._load_plaid_accounts(
            user_id,
            institution_name=institution_name,
        )
        grouped: dict[tuple[str, str, str, str], set[str]] = {}
        for row in rows:
            identity = plaid_account_identity(
                institution_name=row.get("institution_name") or institution_name,
                mask=row.get("mask"),
                account_type=row.get("account_type"),
                account_subtype=row.get("account_subtype"),
            )
            linked = string_or_none(row.get("linked_account_id"))
            if identity is None or linked is None:
                continue
            grouped.setdefault(identity, set()).add(linked)
        for linked_ids in grouped.values():
            if len(linked_ids) < 2:
                continue
            accounts = await self._load_accounts(user_id, list(linked_ids))
            keeper_id = _oldest_account_id(accounts)
            if not keeper_id:
                continue
            for extra_id in linked_ids:
                if extra_id == keeper_id:
                    continue
                await self._merge_account_into(
                    user_id=user_id,
                    keeper_id=keeper_id,
                    extra_id=extra_id,
                )

    async def disconnect_replaced_items(
        self,
        *,
        user_id: str,
        keep_item_id: str,
        institution_id: str | None,
        institution_name: str | None,
    ) -> None:
        if not user_id or not keep_item_id:
            return
        if not institution_id and not institution_name:
            return
        items = await self.cursor_service.supabase_request(
            "GET",
            PLAID_ITEMS_TABLE,
            query={
                "select": "id,institution_id,institution_name,status",
                "user_id": f"eq.{user_id}",
                "status": "neq.disconnected",
            },
        )
        keep_institution = normalized_identity_text(institution_name)
        for item in items:
            item_id = string_or_none(item.get("id"))
            if not item_id or item_id == keep_item_id:
                continue
            same_institution_id = bool(
                institution_id
                and string_or_none(item.get("institution_id")) == institution_id
            )
            same_institution_name = bool(
                keep_institution
                and normalized_identity_text(item.get("institution_name"))
                == keep_institution
            )
            if not (same_institution_id or same_institution_name):
                continue
            await self.cursor_service.mark_item_disconnected(
                user_id=user_id,
                item_id=item_id,
            )
            await self.cursor_service.supabase_request(
                "PATCH",
                PLAID_ACCOUNTS_TABLE,
                body={"linked_account_id": None},
                query={
                    "user_id": f"eq.{user_id}",
                    "item_id": f"eq.{item_id}",
                },
                prefer="return=minimal",
            )
            logger.info(
                "Disconnected replaced Plaid item user=%s item=%s keep=%s",
                user_id[-8:],
                item_id[-8:],
                keep_item_id[-8:],
            )

    async def _merge_account_into(
        self,
        *,
        user_id: str,
        keeper_id: str,
        extra_id: str,
    ) -> None:
        await self._reassign_unique_transactions(
            user_id=user_id,
            keeper_id=keeper_id,
            extra_id=extra_id,
        )
        await self.cursor_service.supabase_request(
            "PATCH",
            PLAID_ACCOUNTS_TABLE,
            body={"linked_account_id": keeper_id},
            query={
                "user_id": f"eq.{user_id}",
                "linked_account_id": f"eq.{extra_id}",
            },
            prefer="return=minimal",
        )
        await self.cursor_service.supabase_request(
            "DELETE",
            ACCOUNTS_TABLE,
            query={
                "user_id": f"eq.{user_id}",
                "id": f"eq.{extra_id}",
            },
            prefer="return=minimal",
        )

    async def _reassign_unique_transactions(
        self,
        *,
        user_id: str,
        keeper_id: str,
        extra_id: str,
    ) -> None:
        extras = await self.cursor_service.supabase_request(
            "GET",
            TRANSACTIONS_TABLE,
            query={
                "select": (
                    "id,date,amount,merchant,description,type,pending,removed_at"
                ),
                "user_id": f"eq.{user_id}",
                "account_id": f"eq.{extra_id}",
            },
        )
        keepers = await self.cursor_service.supabase_request(
            "GET",
            TRANSACTIONS_TABLE,
            query={
                "select": "date,amount,merchant,description,type,pending,removed_at",
                "user_id": f"eq.{user_id}",
                "account_id": f"eq.{keeper_id}",
            },
        )
        keeper_keys = {
            transaction_fingerprint(row)
            for row in keepers
            if row.get("removed_at") is None
        }
        for row in extras:
            if row.get("removed_at") is not None:
                continue
            transaction_id = string_or_none(row.get("id"))
            if not transaction_id:
                continue
            key = transaction_fingerprint(row)
            if key in keeper_keys:
                await self.cursor_service.supabase_request(
                    "DELETE",
                    TRANSACTIONS_TABLE,
                    query={
                        "user_id": f"eq.{user_id}",
                        "id": f"eq.{transaction_id}",
                    },
                    prefer="return=minimal",
                )
                continue
            await self.cursor_service.supabase_request(
                "PATCH",
                TRANSACTIONS_TABLE,
                body={"account_id": keeper_id},
                query={
                    "user_id": f"eq.{user_id}",
                    "id": f"eq.{transaction_id}",
                },
                prefer="return=minimal",
            )
            keeper_keys.add(key)

    async def _release_plaid_account_id(
        self,
        *,
        user_id: str,
        plaid_account_id: str,
        keep_account_id: str,
    ) -> None:
        await self.cursor_service.supabase_request(
            "PATCH",
            ACCOUNTS_TABLE,
            body={"plaid_account_id": None},
            query={
                "user_id": f"eq.{user_id}",
                "plaid_account_id": f"eq.{plaid_account_id}",
                "id": f"neq.{keep_account_id}",
            },
            prefer="return=minimal",
        )

    async def _load_plaid_accounts(
        self,
        user_id: str,
        *,
        institution_name: str | None,
    ) -> list[dict[str, Any]]:
        query = {
            "select": (
                "id,item_id,plaid_account_id,linked_account_id,institution_name,"
                "mask,account_type,account_subtype,status,created_at"
            ),
            "user_id": f"eq.{user_id}",
        }
        if institution_name:
            query["institution_name"] = f"eq.{institution_name}"
        return await self.cursor_service.supabase_request(
            "GET",
            PLAID_ACCOUNTS_TABLE,
            query=query,
        )

    async def _load_accounts(
        self,
        user_id: str,
        account_ids: list[str],
    ) -> list[dict[str, Any]]:
        unique_ids = [account_id for account_id in dict.fromkeys(account_ids) if account_id]
        if not unique_ids:
            return []
        joined = ",".join(unique_ids)
        return await self.cursor_service.supabase_request(
            "GET",
            ACCOUNTS_TABLE,
            query={
                "select": "id,created_at,plaid_account_id",
                "user_id": f"eq.{user_id}",
                "id": f"in.({joined})",
            },
        )


def _oldest_account_id(
    accounts: list[dict[str, Any]],
    *,
    fallback: str | None = None,
) -> str | None:
    ranked = [
        (str(row.get("created_at") or ""), string_or_none(row.get("id")) or "")
        for row in accounts
        if string_or_none(row.get("id"))
    ]
    if not ranked:
        return fallback
    ranked.sort()
    return ranked[0][1]
