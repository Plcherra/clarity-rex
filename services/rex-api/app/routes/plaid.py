from __future__ import annotations

from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import (
    get_plaid_api_client,
    get_plaid_sync_service,
    get_usage_tracking_service,
)
from app.services.plaid_api_client import (
    PlaidApiClient,
    PlaidApiClientError,
    PlaidLinkTokenPayload,
)
from app.services.plaid_config import PlaidConfigurationError
from app.services.plaid_sync_service import PlaidSyncService, PlaidSyncServiceError
from app.services.usage_tracking_service import UsageTrackingService

router = APIRouter(prefix="/plaid", tags=["plaid"])


class PlaidLinkTokenRequest(BaseModel):
    account_id: Optional[str] = None
    user_id: Optional[str] = None


class PlaidLinkTokenResponse(BaseModel):
    link_token: str
    expiration: Optional[str] = None


class PlaidExchangeTokenRequest(BaseModel):
    public_token: str
    institution_id: Optional[str] = None
    institution_name: Optional[str] = None


class PlaidExchangeTokenResponse(BaseModel):
    plaid_item_record_id: str
    status: str
    institution_name: Optional[str] = None
    accounts: list[dict[str, str]] = Field(default_factory=list)


class PlaidItemStatusResponse(BaseModel):
    plaid_item_record_id: str
    status: str
    institution_name: Optional[str] = None
    last_synced_at: Optional[str] = None
    webhook_last_received_at: Optional[str] = None


class PlaidSyncItemResponse(BaseModel):
    plaid_item_record_id: str
    accounts_synced: int
    transactions_added: int
    transactions_modified: int
    transactions_removed: int
    next_cursor: Optional[str] = None


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
        data = await plaid_client.create_link_token(
            PlaidLinkTokenPayload(user_id=current_user.id),
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

    return _safe_link_token_response(data)


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

    return PlaidExchangeTokenResponse(
        plaid_item_record_id=result.plaid_item_record_id,
        status=result.status,
        institution_name=result.institution_name,
        accounts=[],
    )


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


@router.post("/sync-item/{item_id}", response_model=PlaidSyncItemResponse)
async def sync_item(
    item_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    plaid_sync_service: PlaidSyncService = Depends(get_plaid_sync_service),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> PlaidSyncItemResponse:
    if not await usage_tracking_service.is_usage_owner(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Owner Plaid sync access required.",
        )

    try:
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
