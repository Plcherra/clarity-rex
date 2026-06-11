from __future__ import annotations

from typing import Any, Optional

from app.config import Settings, get_settings
from app.services.plaid_account_service import PlaidAccountService
from app.services.plaid_api_client import PlaidApiClient, PlaidApiClientError
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_sync_models import (
    PlaidExchangeResult,
    PlaidItemStatus,
    PlaidSyncResult,
    PlaidSyncServiceError,
    PlaidWebhookResult,
    required_string,
    string_or_none,
)
from app.services.plaid_token_service import PlaidTokenService
from app.services.plaid_transaction_service import PlaidTransactionService


class PlaidSyncService:
    def __init__(
        self,
        plaid_client: Optional[PlaidApiClient] = None,
        settings: Optional[Settings] = None,
        token_service: Optional[PlaidTokenService] = None,
        cursor_service: Optional[PlaidCursorService] = None,
        account_service: Optional[PlaidAccountService] = None,
        transaction_service: Optional[PlaidTransactionService] = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.plaid_client = plaid_client or PlaidApiClient(self.settings)
        self.token_service = token_service or PlaidTokenService(self.settings)
        self.cursor_service = cursor_service or PlaidCursorService(self.settings)
        self.account_service = account_service or PlaidAccountService(
            plaid_client=self.plaid_client,
            cursor_service=self.cursor_service,
        )
        self.transaction_service = transaction_service or PlaidTransactionService(
            plaid_client=self.plaid_client,
            cursor_service=self.cursor_service,
        )

    async def exchange_public_token(
        self,
        *,
        user_id: str,
        public_token: str,
        institution_id: Optional[str] = None,
        institution_name: Optional[str] = None,
    ) -> PlaidExchangeResult:
        normalized_user_id = user_id.strip()
        normalized_public_token = public_token.strip()
        if not normalized_user_id:
            raise PlaidSyncServiceError("user_id is required.", status_code=400)
        if not normalized_public_token:
            raise PlaidSyncServiceError(
                "Plaid public token is required.",
                status_code=400,
            )

        exchange = await self.plaid_client.exchange_public_token(
            normalized_public_token,
        )
        access_token = required_string(exchange, "access_token")
        plaid_item_id = required_string(exchange, "item_id")

        item = await self.cursor_service.upsert_item(
            user_id=normalized_user_id,
            plaid_item_id=plaid_item_id,
            institution_id=institution_id,
            institution_name=institution_name,
            request_id=string_or_none(exchange.get("request_id")),
        )
        item_id = required_string(item, "id")
        await self.cursor_service.upsert_secret(
            user_id=normalized_user_id,
            item_id=item_id,
            access_token_ref=self._encrypted_access_token_ref(access_token),
        )

        return PlaidExchangeResult(
            plaid_item_record_id=item_id,
            status=string_or_none(item.get("status")) or "active",
            institution_name=string_or_none(item.get("institution_name")),
        )

    async def sync_item(self, item_id: str) -> PlaidSyncResult:
        normalized_item_id = item_id.strip()
        if not normalized_item_id:
            raise PlaidSyncServiceError("item_id is required.", status_code=400)

        try:
            item, access_token_ref = await self.cursor_service.load_item_and_token_ref(
                normalized_item_id
            )
            access_token = self._decrypt_access_token_ref(access_token_ref)
            user_id = required_string(item, "user_id")
            account_map = await self.account_service.sync_accounts(
                user_id=user_id,
                item_id=normalized_item_id,
                access_token=access_token,
                institution_name=string_or_none(item.get("institution_name")),
            )
            sync_counts = await self.transaction_service.sync_transactions(
                user_id=user_id,
                item_id=normalized_item_id,
                access_token=access_token,
                cursor=string_or_none(item.get("sync_cursor")),
                account_map=account_map,
            )
        except PlaidApiClientError as error:
            if error.plaid_error_code == "RATE_LIMIT_EXCEEDED":
                raise PlaidSyncServiceError(
                    "Plaid sync is rate limited. Try again later.",
                    status_code=429,
                ) from error
            raise

        return PlaidSyncResult(
            plaid_item_record_id=normalized_item_id,
            accounts_synced=len(account_map),
            transactions_added=sync_counts["added"],
            transactions_modified=sync_counts["modified"],
            transactions_removed=sync_counts["removed"],
            next_cursor=sync_counts["next_cursor"],
        )

    async def mark_item_sync_degraded(self, item_id: str) -> None:
        normalized_item_id = item_id.strip()
        if not normalized_item_id:
            raise PlaidSyncServiceError("item_id is required.", status_code=400)
        await self.cursor_service.update_item_status(
            normalized_item_id,
            status="degraded",
            metadata={"last_sync_error": "initial_sync_failed"},
        )

    async def get_item_status(
        self,
        *,
        user_id: str,
        item_id: str,
    ) -> PlaidItemStatus:
        return await self.cursor_service.get_item_status(
            user_id=user_id,
            item_id=item_id,
        )

    async def handle_webhook_event(
        self,
        *,
        payload: dict[str, Any],
    ) -> PlaidWebhookResult:
        event = _webhook_event(payload)
        plaid_item_id = string_or_none(payload.get("item_id"))
        if not plaid_item_id:
            return PlaidWebhookResult(accepted=True, action="ignored_missing_item")

        if event in {"ITEM_LOGIN_REPAIRED", "LOGIN_REPAIRED"}:
            await self.cursor_service.update_items_by_plaid_id(
                plaid_item_id,
                status="active",
                metadata={"last_webhook_event": event},
            )
            return PlaidWebhookResult(accepted=True, action="item_login_repaired")

        if event == "SYNC_UPDATES_AVAILABLE":
            await self.cursor_service.update_items_by_plaid_id(
                plaid_item_id,
                status="active",
                metadata={"last_webhook_event": event, "sync_requested": True},
            )
            return PlaidWebhookResult(accepted=True, action="sync_requested")

        if event in {"ITEMS:REMOVE", "ITEM:REMOVE", "REMOVE"}:
            await self.cursor_service.update_items_by_plaid_id(
                plaid_item_id,
                status="disconnected",
                metadata={"last_webhook_event": event},
            )
            return PlaidWebhookResult(accepted=True, action="item_removed")

        return PlaidWebhookResult(accepted=True, action="ignored")

    def _encrypted_access_token_ref(self, access_token: str) -> str:
        return self.token_service.encrypted_access_token_ref(access_token)

    def _decrypt_access_token_ref(self, access_token_ref: str) -> str:
        return self.token_service.decrypt_access_token_ref(access_token_ref)


def _webhook_event(payload: dict[str, Any]) -> str:
    webhook_type = str(payload.get("webhook_type") or "").strip().upper()
    webhook_code = str(payload.get("webhook_code") or "").strip().upper()
    if webhook_type == "ITEMS" and webhook_code == "REMOVE":
        return "ITEMS:REMOVE"
    if webhook_type == "ITEM" and webhook_code == "REMOVE":
        return "ITEM:REMOVE"
    return webhook_code
