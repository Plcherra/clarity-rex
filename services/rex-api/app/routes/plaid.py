from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import (
    get_plaid_api_client,
    get_plaid_sync_service,
)
from app.services.plaid_api_client import (
    PlaidApiClient,
    PlaidApiClientError,
    PlaidLinkTokenPayload,
)
from app.services.plaid_config import PlaidConfigurationError
from app.services.plaid_sync_service import (
    PlaidSyncResult,
    PlaidSyncService,
    PlaidSyncServiceError,
)

router = APIRouter(prefix="/plaid", tags=["plaid"])
logger = logging.getLogger(__name__)


class PlaidLinkTokenRequest(BaseModel):
    account_id: Optional[str] = None
    user_id: Optional[str] = None
    platform: Optional[str] = None


class PlaidLinkTokenResponse(BaseModel):
    link_token: str
    expiration: Optional[str] = None


class PlaidExchangeTokenRequest(BaseModel):
    public_token: str
    institution_id: Optional[str] = None
    institution_name: Optional[str] = None


class PlaidExchangeAccountSummary(BaseModel):
    linked_account_id: str
    plaid_item_record_id: str
    institution_name: Optional[str] = None
    name: str
    official_name: Optional[str] = None
    mask: Optional[str] = None
    account_type: Optional[str] = None
    account_subtype: Optional[str] = None
    status: str
    current_balance: Optional[float] = None
    available_balance: Optional[float] = None
    iso_currency_code: Optional[str] = None


class PlaidExchangeTokenResponse(BaseModel):
    plaid_item_record_id: str
    status: str
    institution_name: Optional[str] = None
    accounts: list[PlaidExchangeAccountSummary] = Field(default_factory=list)
    accounts_synced: int = 0
    transactions_added: int = 0
    transactions_modified: int = 0
    transactions_removed: int = 0


class PlaidItemStatusResponse(BaseModel):
    plaid_item_record_id: str
    status: str
    institution_name: Optional[str] = None
    last_synced_at: Optional[str] = None
    webhook_last_received_at: Optional[str] = None


class PlaidDisconnectItemResponse(BaseModel):
    plaid_item_record_id: str
    status: str
    institution_name: Optional[str] = None


class PlaidSyncItemResponse(BaseModel):
    plaid_item_record_id: str
    accounts_synced: int
    transactions_added: int
    transactions_modified: int
    transactions_removed: int
    next_cursor: Optional[str] = None


@router.get("/oauth", include_in_schema=False)
async def plaid_oauth_redirect(request: Request) -> HTMLResponse:
    logger.warning(
        "Plaid OAuth redirect reached method=GET path=%s query_present=%s",
        request.url.path,
        bool(request.url.query),
    )
    return _plaid_oauth_fallback_response()


@router.post("/oauth", include_in_schema=False)
async def plaid_oauth_redirect_post(request: Request) -> HTMLResponse:
    body = await request.body()
    logger.warning(
        "Plaid OAuth redirect reached method=POST path=%s body_bytes=%s query_present=%s",
        request.url.path,
        len(body),
        bool(request.url.query),
    )
    return _plaid_oauth_fallback_response()


@router.post("/link-token", response_model=PlaidLinkTokenResponse)
async def create_link_token(
    request: Optional[PlaidLinkTokenRequest] = None,
    current_user: AuthenticatedUser = Depends(get_current_user),
    plaid_client: PlaidApiClient = Depends(get_plaid_api_client),
) -> PlaidLinkTokenResponse:
    request = request or PlaidLinkTokenRequest()
    if request.user_id and request.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot create a Plaid Link token for another user.",
        )

    try:
        logger.info(
            "Plaid link token requested user=%s account_id_present=%s platform=%s",
            _safe_user_label(current_user.id),
            bool(request.account_id),
            _safe_log_value(request.platform),
        )
        data = await plaid_client.create_link_token(
            PlaidLinkTokenPayload(user_id=current_user.id, platform=request.platform),
        )
    except PlaidConfigurationError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Plaid is not configured. Add backend Plaid credentials before connecting banks.",
        ) from error
    except PlaidApiClientError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error

    response = _safe_link_token_response(data)
    logger.info(
        "Plaid link token created user=%s expiration_present=%s",
        _safe_user_label(current_user.id),
        bool(response.expiration),
    )
    return response


@router.post("/exchange-token", response_model=PlaidExchangeTokenResponse)
async def exchange_public_token(
    request: PlaidExchangeTokenRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    plaid_sync_service: PlaidSyncService = Depends(get_plaid_sync_service),
) -> PlaidExchangeTokenResponse:
    public_token = request.public_token.strip()
    if not public_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="public_token is required.",
        )

    try:
        logger.info(
            "Plaid public token exchange received user=%s public_token_present=%s institution_id=%s institution_name=%s",
            _safe_user_label(current_user.id),
            bool(public_token),
            _safe_log_value(request.institution_id),
            _safe_log_value(request.institution_name),
        )
        result = await plaid_sync_service.exchange_public_token(
            user_id=current_user.id,
            public_token=public_token,
            institution_id=request.institution_id,
            institution_name=request.institution_name,
        )
    except PlaidConfigurationError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Plaid is not configured. Add backend Plaid credentials before connecting banks.",
        ) from error
    except PlaidApiClientError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error
    except PlaidSyncServiceError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error

    sync_status = result.status
    sync_result: PlaidSyncResult | None = None
    accounts: list[dict[str, Any]] = []
    try:
        sync_result = await plaid_sync_service.sync_item(result.plaid_item_record_id)
    except (PlaidApiClientError, PlaidSyncServiceError) as error:
        sync_status = "degraded"
        logger.warning(
            "Plaid initial sync deferred user=%s item=%s error_type=%s status=%s detail=%s",
            _safe_user_label(current_user.id),
            _safe_item_label(result.plaid_item_record_id),
            error.__class__.__name__,
            getattr(error, "status_code", "unknown"),
            _safe_error_detail(getattr(error, "detail", str(error))),
        )
        try:
            await plaid_sync_service.mark_item_sync_degraded(
                result.plaid_item_record_id,
            )
        except PlaidSyncServiceError as degrade_error:
            logger.warning(
                "Plaid item degraded status update failed user=%s item=%s status=%s detail=%s",
                _safe_user_label(current_user.id),
                _safe_item_label(result.plaid_item_record_id),
                degrade_error.status_code,
                _safe_error_detail(degrade_error.detail),
            )

    if sync_result:
        try:
            accounts = await plaid_sync_service.sanitized_accounts_for_item(
                user_id=current_user.id,
                item_id=result.plaid_item_record_id,
            )
        except PlaidSyncServiceError as error:
            logger.warning(
                "Plaid account summary fetch failed user=%s item=%s status=%s detail=%s",
                _safe_user_label(current_user.id),
                _safe_item_label(result.plaid_item_record_id),
                error.status_code,
                _safe_error_detail(error.detail),
            )

    response = PlaidExchangeTokenResponse(
        plaid_item_record_id=result.plaid_item_record_id,
        status=sync_status,
        institution_name=result.institution_name,
        accounts=accounts,
        accounts_synced=sync_result.accounts_synced if sync_result else 0,
        transactions_added=sync_result.transactions_added if sync_result else 0,
        transactions_modified=sync_result.transactions_modified if sync_result else 0,
        transactions_removed=sync_result.transactions_removed if sync_result else 0,
    )
    logger.info(
        "Plaid public token exchange completed user=%s item=%s accounts=%s transactions_added=%s transactions_modified=%s transactions_removed=%s",
        _safe_user_label(current_user.id),
        _safe_item_label(result.plaid_item_record_id),
        response.accounts_synced,
        response.transactions_added,
        response.transactions_modified,
        response.transactions_removed,
    )
    return response


@router.get("/item-status/{item_id}", response_model=PlaidItemStatusResponse)
async def get_item_status(
    item_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    plaid_sync_service: PlaidSyncService = Depends(get_plaid_sync_service),
) -> PlaidItemStatusResponse:
    try:
        item = await plaid_sync_service.get_item_status(
            user_id=current_user.id,
            item_id=item_id,
        )
    except PlaidSyncServiceError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error

    return PlaidItemStatusResponse(
        plaid_item_record_id=item.plaid_item_record_id,
        status=item.status,
        institution_name=item.institution_name,
        last_synced_at=item.last_synced_at,
        webhook_last_received_at=item.webhook_last_received_at,
    )


@router.post(
    "/disconnect-item/{item_id}",
    response_model=PlaidDisconnectItemResponse,
)
async def disconnect_item(
    item_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    plaid_sync_service: PlaidSyncService = Depends(get_plaid_sync_service),
) -> PlaidDisconnectItemResponse:
    try:
        item = await plaid_sync_service.disconnect_item(
            user_id=current_user.id,
            item_id=item_id,
        )
    except PlaidApiClientError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error
    except PlaidSyncServiceError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error

    return PlaidDisconnectItemResponse(
        plaid_item_record_id=item.plaid_item_record_id,
        status=item.status,
        institution_name=item.institution_name,
    )


@router.post("/sync-item/{item_id}", response_model=PlaidSyncItemResponse)
async def sync_item(
    item_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    plaid_sync_service: PlaidSyncService = Depends(get_plaid_sync_service),
) -> PlaidSyncItemResponse:
    try:
        await plaid_sync_service.get_item_status(
            user_id=current_user.id,
            item_id=item_id,
        )
        result = await plaid_sync_service.sync_item(item_id)
    except PlaidApiClientError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error
    except PlaidSyncServiceError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error

    return PlaidSyncItemResponse(
        plaid_item_record_id=result.plaid_item_record_id,
        accounts_synced=result.accounts_synced,
        transactions_added=result.transactions_added,
        transactions_modified=result.transactions_modified,
        transactions_removed=result.transactions_removed,
        next_cursor=result.next_cursor,
    )


def _safe_link_token_response(data: dict[str, Any]) -> PlaidLinkTokenResponse:
    link_token = data.get("link_token")
    if not isinstance(link_token, str) or not link_token:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Plaid returned an invalid Link token response.",
        )

    expiration = data.get("expiration")
    return PlaidLinkTokenResponse(
        link_token=link_token,
        expiration=expiration if isinstance(expiration, str) else None,
    )


def _plaid_oauth_fallback_response() -> HTMLResponse:
    return HTMLResponse(
        """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Return to Clarity</title>
  </head>
  <body style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 24px;">
    <h1>Return to Clarity</h1>
    <p>Your bank sent you back to Clarity. You can return to the app to continue.</p>
  </body>
</html>
        """.strip()
    )


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


def _safe_log_value(value: str | None) -> str:
    normalized = (value or "").strip()
    if not normalized:
        return "none"
    return normalized[:80]


def _safe_error_detail(value: object) -> str:
    normalized = str(value or "").strip()
    if not normalized:
        return "none"
    return normalized[:240]
