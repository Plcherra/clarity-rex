from __future__ import annotations

import logging
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

logger = logging.getLogger(__name__)


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
            app_timezone=self.settings.app_timezone,
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

    async def sync_item(
        self,
        item_id: str,
        *,
        request_bank_refresh: bool = False,
    ) -> PlaidSyncResult:
        normalized_item_id = item_id.strip()
        if not normalized_item_id:
            raise PlaidSyncServiceError("item_id is required.", status_code=400)

        phase = "load_item"
        user_id = "unknown"
        try:
            item, access_token_ref = await self.cursor_service.load_item_and_token_ref(
                normalized_item_id
            )
            phase = "decrypt_access_token"
            access_token = self._decrypt_access_token_ref(access_token_ref)
            user_id = required_string(item, "user_id")
            balances_refreshed = False
            transactions_refresh_status = "skipped"
            accounts_response = None
            if request_bank_refresh:
                logger.info(
                    "Plaid manual refresh started user=%s item=%s",
                    _safe_user_label(user_id),
                    _safe_item_label(normalized_item_id),
                )
                if self.settings.plaid_enable_transactions_refresh:
                    phase = "refresh_transactions"
                    try:
                        await self.plaid_client.refresh_transactions(access_token)
                        transactions_refresh_status = "ok"
                    except PlaidApiClientError as error:
                        error_code = _safe_error_detail(error.plaid_error_code)
                        if error_code == "INVALID_PRODUCT":
                            transactions_refresh_status = "unavailable"
                            logger.info(
                                "Plaid transactions refresh unavailable user=%s item=%s "
                                "(Plaid transactions_refresh add-on not enabled for this client)",
                                _safe_user_label(user_id),
                                _safe_item_label(normalized_item_id),
                            )
                        else:
                            transactions_refresh_status = "failed"
                            logger.warning(
                                "Plaid transaction refresh failed user=%s item=%s code=%s",
                                _safe_user_label(user_id),
                                _safe_item_label(normalized_item_id),
                                error_code,
                            )
                else:
                    logger.info(
                        "Plaid transactions refresh skipped user=%s item=%s "
                        "(PLAID_ENABLE_TRANSACTIONS_REFRESH is false)",
                        _safe_user_label(user_id),
                        _safe_item_label(normalized_item_id),
                    )
                phase = "fetch_balances"
                try:
                    accounts_response = await self.plaid_client.get_account_balances(
                        access_token
                    )
                    balances_refreshed = True
                except PlaidApiClientError as error:
                    logger.warning(
                        "Plaid balance fetch failed user=%s item=%s code=%s",
                        _safe_user_label(user_id),
                        _safe_item_label(normalized_item_id),
                        _safe_error_detail(error.plaid_error_code),
                    )
            phase = "sync_accounts"
            account_map = await self.account_service.sync_accounts(
                user_id=user_id,
                item_id=normalized_item_id,
                access_token=access_token,
                institution_name=string_or_none(item.get("institution_name")),
                accounts_response=accounts_response,
            )
            logger.info(
                "Plaid account sync completed user=%s item=%s accounts=%s",
                _safe_user_label(user_id),
                _safe_item_label(normalized_item_id),
                len(account_map),
            )
            phase = "sync_transactions"
            sync_counts = await self.transaction_service.sync_transactions(
                user_id=user_id,
                item_id=normalized_item_id,
                access_token=access_token,
                cursor=string_or_none(item.get("sync_cursor")),
                account_map=account_map,
            )
            logger.info(
                "Plaid transaction sync completed user=%s item=%s added=%s modified=%s removed=%s "
                "bank_refresh=%s balances_refreshed=%s transactions_refresh=%s",
                _safe_user_label(user_id),
                _safe_item_label(normalized_item_id),
                sync_counts["added"],
                sync_counts["modified"],
                sync_counts["removed"],
                request_bank_refresh,
                balances_refreshed,
                transactions_refresh_status,
            )
        except PlaidApiClientError as error:
            logger.warning(
                "Plaid sync API failed phase=%s user=%s item=%s status=%s code=%s request_id=%s detail=%s",
                phase,
                _safe_user_label(user_id),
                _safe_item_label(normalized_item_id),
                error.status_code,
                _safe_error_detail(error.plaid_error_code),
                _safe_error_detail(error.request_id),
                _safe_error_detail(error.detail),
            )
            if error.plaid_error_code == "RATE_LIMIT_EXCEEDED":
                raise PlaidSyncServiceError(
                    "Plaid sync is rate limited. Try again later.",
                    status_code=429,
                ) from error
            raise
        except PlaidSyncServiceError as error:
            logger.warning(
                "Plaid sync failed phase=%s user=%s item=%s status=%s detail=%s",
                phase,
                _safe_user_label(user_id),
                _safe_item_label(normalized_item_id),
                error.status_code,
                _safe_error_detail(error.detail),
            )
            raise

        return PlaidSyncResult(
            plaid_item_record_id=normalized_item_id,
            accounts_synced=len(account_map),
            transactions_added=sync_counts["added"],
            transactions_modified=sync_counts["modified"],
            transactions_removed=sync_counts["removed"],
            next_cursor=sync_counts["next_cursor"],
            balances_refreshed=balances_refreshed,
            transactions_refresh_status=transactions_refresh_status,
        )

    async def sanitized_accounts_for_item(
        self,
        *,
        user_id: str,
        item_id: str,
    ) -> list[dict[str, Any]]:
        normalized_user_id = user_id.strip()
        normalized_item_id = item_id.strip()
        if not normalized_user_id:
            raise PlaidSyncServiceError("user_id is required.", status_code=400)
        if not normalized_item_id:
            raise PlaidSyncServiceError("item_id is required.", status_code=400)
        return await self.account_service.sanitized_accounts_for_item(
            user_id=normalized_user_id,
            item_id=normalized_item_id,
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

    async def disconnect_item(
        self,
        *,
        user_id: str,
        item_id: str,
    ) -> PlaidItemStatus:
        normalized_user_id = user_id.strip()
        normalized_item_id = item_id.strip()
        if not normalized_user_id:
            raise PlaidSyncServiceError("user_id is required.", status_code=400)
        if not normalized_item_id:
            raise PlaidSyncServiceError("item_id is required.", status_code=400)

        current_status = await self.cursor_service.get_item_status(
            user_id=normalized_user_id,
            item_id=normalized_item_id,
        )
        if current_status.status == "disconnected":
            return current_status

        item, access_token_ref = await self.cursor_service.load_user_item_and_token_ref(
            user_id=normalized_user_id,
            item_id=normalized_item_id,
        )
        access_token = self._decrypt_access_token_ref(access_token_ref)
        await self.plaid_client.remove_item(access_token)
        await self.cursor_service.mark_item_disconnected(
            user_id=normalized_user_id,
            item_id=normalized_item_id,
        )
        logger.info(
            "Plaid item disconnected user=%s item=%s",
            _safe_user_label(normalized_user_id),
            _safe_item_label(normalized_item_id),
        )
        return PlaidItemStatus(
            plaid_item_record_id=normalized_item_id,
            status="disconnected",
            institution_name=string_or_none(item.get("institution_name")),
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
            items = await self.cursor_service.list_syncable_items_by_plaid_id(
                plaid_item_id,
            )
            if not items:
                return PlaidWebhookResult(accepted=True, action="sync_item_missing")

            synced = 0
            retryable = 0
            failed = 0
            for item in items:
                item_id = string_or_none(item.get("id"))
                if not item_id:
                    failed += 1
                    continue
                try:
                    await self.sync_item(item_id)
                    synced += 1
                except PlaidSyncServiceError as error:
                    if error.status_code == 429:
                        retryable += 1
                        await self._mark_webhook_sync_degraded(
                            item_id=item_id,
                            event=event,
                            reason="rate_limited",
                            retryable=True,
                        )
                    else:
                        failed += 1
                        await self._mark_webhook_sync_degraded(
                            item_id=item_id,
                            event=event,
                            reason="sync_failed",
                            retryable=False,
                        )
                except PlaidApiClientError:
                    failed += 1
                    await self._mark_webhook_sync_degraded(
                        item_id=item_id,
                        event=event,
                        reason="plaid_api_failed",
                        retryable=False,
                    )

            if failed:
                return PlaidWebhookResult(accepted=True, action="sync_degraded")
            if retryable:
                return PlaidWebhookResult(accepted=True, action="sync_retryable")
            if synced:
                return PlaidWebhookResult(accepted=True, action="sync_completed")
            return PlaidWebhookResult(accepted=True, action="sync_item_missing")

        if event in {"ITEMS:REMOVE", "ITEM:REMOVE", "REMOVE"}:
            await self.cursor_service.update_items_by_plaid_id(
                plaid_item_id,
                status="disconnected",
                metadata={"last_webhook_event": event},
            )
            return PlaidWebhookResult(accepted=True, action="item_removed")

        return PlaidWebhookResult(accepted=True, action="ignored")

    async def _mark_webhook_sync_degraded(
        self,
        *,
        item_id: str,
        event: str,
        reason: str,
        retryable: bool,
    ) -> None:
        await self.cursor_service.update_item_status(
            item_id,
            status="degraded",
            metadata={
                "last_webhook_event": event,
                "sync_requested": True,
                "last_sync_error": reason,
                "retryable": retryable,
            },
        )

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


def _safe_user_label(user_id: str) -> str:
    normalized = user_id.strip()
    if len(normalized) <= 8:
        return normalized or "unknown"
    return f"...{normalized[-8:]}"


def _safe_item_label(item_id: str) -> str:
    normalized = item_id.strip()
    if len(normalized) <= 8:
        return normalized or "unknown"
    return f"...{normalized[-8:]}"


def _safe_error_detail(value: object) -> str:
    normalized = str(value or "").strip()
    if not normalized:
        return "none"
    return normalized[:300]
