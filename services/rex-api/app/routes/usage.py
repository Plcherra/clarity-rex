from fastapi import APIRouter, Depends, HTTPException, status

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
