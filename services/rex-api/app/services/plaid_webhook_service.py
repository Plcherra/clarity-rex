from __future__ import annotations

from typing import Any, Optional

from app.services.plaid_sync_service import PlaidSyncService
from app.services.plaid_webhook_verifier import (
    PlaidWebhookVerificationError,
    PlaidWebhookVerifier,
)

ITEM_EVENTS_REQUIRING_ITEM = {
    "ITEM_LOGIN_REPAIRED",
    "LOGIN_REPAIRED",
    "SYNC_UPDATES_AVAILABLE",
    "DEFAULT_UPDATE",
    "PRODUCT_READY",
    "ITEMS:REMOVE",
    "ITEM:REMOVE",
    "REMOVE",
}


class PlaidWebhookValidationError(Exception):
    def __init__(self, detail: str, *, status_code: int = 400) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


class PlaidWebhookService:
    def __init__(
        self,
        plaid_sync_service: PlaidSyncService,
        webhook_verifier: PlaidWebhookVerifier,
    ) -> None:
        self.plaid_sync_service = plaid_sync_service
        self.webhook_verifier = webhook_verifier

    async def verify_webhook_request(
        self,
        *,
        payload: dict[str, Any],
        plaid_verification: Optional[str],
        raw_body: bytes,
    ) -> None:
        try:
            await self.webhook_verifier.verify(
                plaid_verification=plaid_verification,
                raw_body=raw_body,
            )
        except PlaidWebhookVerificationError as error:
            raise PlaidWebhookValidationError(
                "Invalid Plaid webhook verification.",
                status_code=401,
            ) from error
        self.validate_payload(payload)

    def validate_payload(self, payload: dict[str, Any]) -> None:
        webhook_type = _clean(payload.get("webhook_type"))
        webhook_code = _clean(payload.get("webhook_code"))
        if not webhook_type or not webhook_code:
            raise PlaidWebhookValidationError("Invalid Plaid webhook payload.")

        event = _event_key(webhook_type=webhook_type, webhook_code=webhook_code)
        if event in ITEM_EVENTS_REQUIRING_ITEM and not _clean(payload.get("item_id")):
            raise PlaidWebhookValidationError("Plaid webhook item_id is required.")

    async def process_webhook(self, *, payload: dict[str, Any]) -> None:
        await self.plaid_sync_service.handle_webhook_event(payload=payload)


def _clean(value: Any) -> str:
    return str(value or "").strip().upper()


def _event_key(*, webhook_type: str, webhook_code: str) -> str:
    if webhook_type == "ITEMS" and webhook_code == "REMOVE":
        return "ITEMS:REMOVE"
    if webhook_type == "ITEM" and webhook_code == "REMOVE":
        return "ITEM:REMOVE"
    return webhook_code
