from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_plaid_sync_service
from app.routes.plaid import PlaidSyncItemResponse
from app.services.plaid_api_client import PlaidApiClientError
from app.services.plaid_sync_service import PlaidSyncService, PlaidSyncServiceError

router = APIRouter(prefix="/plaid", tags=["plaid"])


@router.post("/complete-update/{item_id}", response_model=PlaidSyncItemResponse)
async def complete_item_update(
    item_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    plaid_sync_service: PlaidSyncService = Depends(get_plaid_sync_service),
) -> PlaidSyncItemResponse:
    try:
        result = await plaid_sync_service.complete_item_update(
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

    return PlaidSyncItemResponse(
        plaid_item_record_id=result.plaid_item_record_id,
        accounts_synced=result.accounts_synced,
        transactions_added=result.transactions_added,
        transactions_modified=result.transactions_modified,
        transactions_removed=result.transactions_removed,
        next_cursor=result.next_cursor,
        balances_refreshed=result.balances_refreshed,
        transactions_refresh_status=result.transactions_refresh_status,
    )
