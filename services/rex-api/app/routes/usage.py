from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_usage_tracking_service
from app.services.usage_tracking_service import UsageTrackingService

router = APIRouter(prefix="/usage", tags=["usage"])


@router.get("/me")
async def get_my_usage(
    current_user: AuthenticatedUser = Depends(get_current_user),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> dict:
    return await usage_tracking_service.get_user_voice_usage(user_id=current_user.id)


@router.get("/admin/access")
async def get_owner_access(
    current_user: AuthenticatedUser = Depends(get_current_user),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> dict:
    authorized = await usage_tracking_service.is_usage_owner(current_user.id)
    return {"authorized": authorized}


@router.get("/admin/summary")
async def get_owner_platform_summary(
    current_user: AuthenticatedUser = Depends(get_current_user),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> dict:
    result = await usage_tracking_service.get_owner_platform_summary(
        requester_user_id=current_user.id,
    )
    if not result.get("authorized"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Owner usage access required.",
        )
    return result


@router.get("/admin/users")
async def get_all_user_usage(
    current_user: AuthenticatedUser = Depends(get_current_user),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> dict:
    result = await usage_tracking_service.get_owner_usage(
        requester_user_id=current_user.id,
    )
    if not result["authorized"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Owner usage access required.",
        )
    return {"users": result["users"]}


@router.get("/admin/users/{user_id}/daily")
async def get_owner_user_daily_usage(
    user_id: str,
    start: date | None = Query(default=None),
    end: date | None = Query(default=None),
    current_user: AuthenticatedUser = Depends(get_current_user),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> dict:
    month_start = date.today().replace(day=1)
    result = await usage_tracking_service.get_owner_user_daily(
        requester_user_id=current_user.id,
        user_id=user_id,
        start_date=start or month_start,
        end_date=end,
    )
    if not result["authorized"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Owner usage access required.",
        )
    return result
