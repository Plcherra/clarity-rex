from __future__ import annotations

import json
from typing import Any, Optional
from urllib.parse import quote, urlencode

import httpx

from app.config import Settings, get_settings
from app.services.http_client import request_with_retries
from app.services.plaid_sync_models import (
    PlaidItemStatus,
    PlaidSyncServiceError,
    first_row,
    required_string,
    string_or_none,
    utc_now_iso,
)

PLAID_ITEMS_TABLE = "plaid_items"
PLAID_ITEM_SECRETS_TABLE = "plaid_item_secrets"


class PlaidCursorService:
    def __init__(self, settings: Optional[Settings] = None) -> None:
        self.settings = settings or get_settings()

    async def upsert_item(
        self,
        *,
        user_id: str,
        plaid_item_id: str,
        institution_id: Optional[str],
        institution_name: Optional[str],
        request_id: Optional[str],
    ) -> dict[str, Any]:
        body = {
            "user_id": user_id,
            "plaid_item_id": plaid_item_id,
            "institution_id": institution_id,
            "institution_name": institution_name,
            "status": "active",
            "metadata": {"last_exchange_request_id": request_id} if request_id else {},
        }
        rows = await self.supabase_request(
            "POST",
            PLAID_ITEMS_TABLE,
            body={key: value for key, value in body.items() if value is not None},
            query={
                "on_conflict": "user_id,plaid_item_id",
                "select": "id,status,institution_name",
            },
            prefer="resolution=merge-duplicates,return=representation",
        )
        return first_row(rows, "Supabase Plaid item upsert returned no rows.")

    async def upsert_secret(
        self,
        *,
        user_id: str,
        item_id: str,
        access_token_ref: str,
    ) -> None:
        await self.supabase_request(
            "POST",
            PLAID_ITEM_SECRETS_TABLE,
            body={
                "user_id": user_id,
                "item_id": item_id,
                "access_token_ref": access_token_ref,
            },
            query={"on_conflict": "user_id,item_id"},
            prefer="resolution=merge-duplicates,return=minimal",
        )

    async def load_item_and_token_ref(self, item_id: str) -> tuple[dict[str, Any], str]:
        item_rows = await self.supabase_request(
            "GET",
            PLAID_ITEMS_TABLE,
            query={
                "select": "id,user_id,plaid_item_id,institution_name,sync_cursor,status",
                "id": f"eq.{item_id}",
                "limit": "1",
            },
        )
        if not item_rows:
            raise PlaidSyncServiceError("Plaid item was not found.", status_code=404)
        secret_rows = await self.supabase_request(
            "GET",
            PLAID_ITEM_SECRETS_TABLE,
            query={
                "select": "access_token_ref",
                "item_id": f"eq.{item_id}",
                "limit": "1",
            },
        )
        if not secret_rows:
            raise PlaidSyncServiceError(
                "Plaid item credentials were not found.",
                status_code=404,
            )
        return item_rows[0], required_string(secret_rows[0], "access_token_ref")

    async def get_item_status(self, *, user_id: str, item_id: str) -> PlaidItemStatus:
        normalized_user_id = user_id.strip()
        normalized_item_id = item_id.strip()
        if not normalized_user_id:
            raise PlaidSyncServiceError("user_id is required.", status_code=400)
        if not normalized_item_id:
            raise PlaidSyncServiceError("item_id is required.", status_code=400)

        rows = await self.supabase_request(
            "GET",
            PLAID_ITEMS_TABLE,
            query={
                "select": (
                    "id,status,institution_name,last_synced_at,"
                    "webhook_last_received_at"
                ),
                "user_id": f"eq.{normalized_user_id}",
                "id": f"eq.{normalized_item_id}",
                "limit": "1",
            },
        )
        if not rows:
            raise PlaidSyncServiceError("Plaid item was not found.", status_code=404)
        row = rows[0]
        return PlaidItemStatus(
            plaid_item_record_id=required_string(row, "id"),
            status=required_string(row, "status"),
            institution_name=string_or_none(row.get("institution_name")),
            last_synced_at=string_or_none(row.get("last_synced_at")),
            webhook_last_received_at=string_or_none(
                row.get("webhook_last_received_at")
            ),
        )

    async def update_item_after_sync(
        self,
        item_id: str,
        next_cursor: Optional[str],
    ) -> None:
        await self.supabase_request(
            "PATCH",
            PLAID_ITEMS_TABLE,
            body={
                "sync_cursor": next_cursor,
                "last_synced_at": utc_now_iso(),
                "status": "active",
            },
            query={"id": f"eq.{item_id}"},
            prefer="return=minimal",
        )

    async def update_item_status(
        self,
        item_id: str,
        *,
        status: str,
        metadata: dict[str, Any],
    ) -> None:
        await self.supabase_request(
            "PATCH",
            PLAID_ITEMS_TABLE,
            body={
                "status": status,
                "metadata": metadata,
            },
            query={"id": f"eq.{item_id}"},
            prefer="return=minimal",
        )

    async def update_items_by_plaid_id(
        self,
        plaid_item_id: str,
        *,
        status: str,
        metadata: dict[str, Any],
    ) -> None:
        await self.supabase_request(
            "PATCH",
            PLAID_ITEMS_TABLE,
            body={
                "status": status,
                "webhook_last_received_at": utc_now_iso(),
                "metadata": metadata,
            },
            query={"plaid_item_id": f"eq.{plaid_item_id}"},
            prefer="return=minimal",
        )

    async def supabase_request(
        self,
        method: str,
        table: str,
        *,
        body: Optional[dict[str, Any]] = None,
        query: Optional[dict[str, str]] = None,
        prefer: Optional[str] = None,
    ) -> list[dict[str, Any]]:
        rest_url = self.settings.supabase_rest_url
        service_key = self.settings.supabase_service_role_key
        if not rest_url or not service_key:
            raise PlaidSyncServiceError("Supabase Plaid storage is not configured.")

        url = f"{rest_url}/{quote(table)}"
        if query:
            url = f"{url}?{urlencode(query)}"
        headers = {
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
        }
        if body is not None:
            headers["Content-Type"] = "application/json"
        if prefer:
            headers["Prefer"] = prefer

        response = await request_with_retries(method, url, headers=headers, json=body)
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError as error:
            raise PlaidSyncServiceError(
                "Cannot save Plaid connection right now.",
            ) from error

        if not response.text:
            return []
        try:
            data = response.json()
        except json.JSONDecodeError as error:
            raise PlaidSyncServiceError(
                "Supabase Plaid storage returned an unreadable response.",
                status_code=502,
            ) from error
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            return [data]
        raise PlaidSyncServiceError(
            "Supabase Plaid storage returned an unexpected response.",
            status_code=502,
        )
