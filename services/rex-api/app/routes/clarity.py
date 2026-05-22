from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import get_clarity_control_service
from app.models.clarity_action import ClarityActionRequest, ClarityActionResponse
from app.services.clarity_control_service import (
    ClarityControlService,
    ClarityControlServiceError,
)

router = APIRouter(prefix="/clarity", tags=["clarity"])


@router.post("/actions", response_model=ClarityActionResponse)
async def execute_clarity_action(
    request: ClarityActionRequest,
    service: ClarityControlService = Depends(get_clarity_control_service),
) -> ClarityActionResponse:
    try:
        result = await service.execute(
            request.action,
            request.payload,
            confirmed=request.confirmed,
        )
    except ClarityControlServiceError as error:
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error

    return ClarityActionResponse(
        action=request.action,
        status="applied",
        result=result,
    )
