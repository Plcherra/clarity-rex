from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_usage_tracking_service
from app.services.usage_admin_period import resolve_usage_admin_period
from app.services.usage_tracking_service import UsageTrackingService

router = APIRouter(prefix="/usage", tags=["usage"])


def _resolve_admin_period(
    *,
    period: str = Query(default="all"),
    year: int | None = Query(default=None),
    month: int | None = Query(default=None, ge=1, le=12),
    day: date | None = Query(default=None),
) -> dict:
    try:
        resolved = resolve_usage_admin_period(
            period=period,
            year=year,
            month=month,
            day=day,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error
    return {
        "period": resolved.kind.value,
        "year": year,
        "month": month,
        "day": day,
    }


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
    period: str = Query(default="all"),
    year: int | None = Query(default=None),
    month: int | None = Query(default=None, ge=1, le=12),
    day: date | None = Query(default=None),
) -> dict:
    _resolve_admin_period(period=period, year=year, month=month, day=day)
    result = await usage_tracking_service.get_owner_platform_summary(
        requester_user_id=current_user.id,
        period=period,
        year=year,
        month=month,
        day=day,
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
    period: str = Query(default="all"),
    year: int | None = Query(default=None),
    month: int | None = Query(default=None, ge=1, le=12),
    day: date | None = Query(default=None),
) -> dict:
    _resolve_admin_period(period=period, year=year, month=month, day=day)
    result = await usage_tracking_service.get_owner_usage(
        requester_user_id=current_user.id,
        period=period,
        year=year,
        month=month,
        day=day,
    )
    if not result["authorized"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Owner usage access required.",
        )
    return {
        "users": result["users"],
        "period": result.get("period"),
        "start_date": result.get("start_date"),
        "end_date": result.get("end_date"),
        "registered_user_count": result.get("registered_user_count", 0),
    }


@router.get("/admin/users/{user_id}/daily")
async def get_owner_user_daily_usage(
    user_id: str,
    start: date | None = Query(default=None),
    end: date | None = Query(default=None),
    period: str = Query(default="all"),
    year: int | None = Query(default=None),
    month: int | None = Query(default=None, ge=1, le=12),
    day: date | None = Query(default=None),
    current_user: AuthenticatedUser = Depends(get_current_user),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> dict:
    if start is None and end is None:
        resolved = resolve_usage_admin_period(
            period=period,
            year=year,
            month=month,
            day=day,
        )
        start = resolved.start_date
        end = resolved.end_date
    else:
        start = start or date.today().replace(day=1)
        end = end or date.today()

    result = await usage_tracking_service.get_owner_user_daily(
        requester_user_id=current_user.id,
        user_id=user_id,
        start_date=start,
        end_date=end,
    )
    if not result["authorized"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Owner usage access required.",
        )
    result["period"] = period
    result["start_date"] = start.isoformat()
    result["end_date"] = end.isoformat()
    return result
