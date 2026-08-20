from __future__ import annotations

from typing import Any, Awaitable, Callable

from app.services.plaid_api_client import PlaidApiClientError
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_item_auth_status import webhook_auth_status
from app.services.plaid_sync_models import (
    PlaidSyncServiceError,
    PlaidWebhookResult,
    string_or_none,
)

SyncItem = Callable[[str], Awaitable[Any]]


async def handle_plaid_webhook_event(
    *,
    payload: dict[str, Any],
    cursor_service: PlaidCursorService,
    sync_item: SyncItem,
) -> PlaidWebhookResult:
    event = webhook_event_key(payload)
    plaid_item_id = string_or_none(payload.get("item_id"))
    if not plaid_item_id:
        return PlaidWebhookResult(accepted=True, action="ignored_missing_item")

    auth_status = webhook_auth_status(payload)
    if auth_status:
        await cursor_service.update_items_by_plaid_id(
            plaid_item_id,
            status=auth_status,
            metadata={"last_webhook_event": event},
        )
        return PlaidWebhookResult(accepted=True, action=f"item_{auth_status}")

    if event in {"ITEM_LOGIN_REPAIRED", "LOGIN_REPAIRED"}:
        await cursor_service.update_items_by_plaid_id(
            plaid_item_id,
            status="active",
            metadata={"last_webhook_event": event},
        )
        return PlaidWebhookResult(accepted=True, action="item_login_repaired")

    if event in {"SYNC_UPDATES_AVAILABLE", "DEFAULT_UPDATE", "PRODUCT_READY"}:
        return await _sync_available_event(
            cursor_service=cursor_service,
            sync_item=sync_item,
            plaid_item_id=plaid_item_id,
            event=event,
        )

    if event in {"ITEMS:REMOVE", "ITEM:REMOVE", "REMOVE"}:
        await cursor_service.update_items_by_plaid_id(
            plaid_item_id,
            status="disconnected",
            metadata={"last_webhook_event": event},
        )
        return PlaidWebhookResult(accepted=True, action="item_removed")

    return PlaidWebhookResult(accepted=True, action="ignored")


def webhook_event_key(payload: dict[str, Any]) -> str:
    webhook_type = str(payload.get("webhook_type") or "").strip().upper()
    webhook_code = str(payload.get("webhook_code") or "").strip().upper()
    if webhook_type == "ITEMS" and webhook_code == "REMOVE":
        return "ITEMS:REMOVE"
    if webhook_type == "ITEM" and webhook_code == "REMOVE":
        return "ITEM:REMOVE"
    return webhook_code


async def _sync_available_event(
    *,
    cursor_service: PlaidCursorService,
    sync_item: SyncItem,
    plaid_item_id: str,
    event: str,
) -> PlaidWebhookResult:
    await cursor_service.update_items_by_plaid_id(
        plaid_item_id,
        status="active",
        metadata={"last_webhook_event": event, "sync_requested": True},
    )
    items = await cursor_service.list_syncable_items_by_plaid_id(plaid_item_id)
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
            await sync_item(item_id)
            synced += 1
        except PlaidSyncServiceError as error:
            if error.status_code == 429:
                retryable += 1
                await _mark_webhook_sync_degraded(
                    cursor_service,
                    item_id=item_id,
                    event=event,
                    reason="rate_limited",
                    retryable=True,
                )
            else:
                failed += 1
                await _mark_webhook_sync_degraded(
                    cursor_service,
                    item_id=item_id,
                    event=event,
                    reason="sync_failed",
                    retryable=False,
                )
        except PlaidApiClientError:
            failed += 1
            await _mark_webhook_sync_degraded(
                cursor_service,
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


async def _mark_webhook_sync_degraded(
    cursor_service: PlaidCursorService,
    *,
    item_id: str,
    event: str,
    reason: str,
    retryable: bool,
) -> None:
    await cursor_service.update_item_status(
        item_id,
        status="degraded",
        metadata={
            "last_webhook_event": event,
            "sync_requested": True,
            "last_sync_error": reason,
            "retryable": retryable,
        },
    )
