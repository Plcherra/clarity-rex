from fastapi import APIRouter, Depends, HTTPException

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_clarity_control_service, get_financial_audit_service
from app.models.clarity_action import ClarityActionRequest, ClarityActionResponse
from app.services.clarity_control_service import (
    ClarityControlService,
    ClarityControlServiceError,
)
from app.services.clarity_finance_audit import record_assistant_finance_audit
from app.services.financial_audit_service import FinancialAuditService

router = APIRouter(prefix="/clarity", tags=["clarity"])


@router.post("/actions", response_model=ClarityActionResponse)
async def execute_clarity_action(
    request: ClarityActionRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: ClarityControlService = Depends(get_clarity_control_service),
    audit_service: FinancialAuditService = Depends(get_financial_audit_service),
) -> ClarityActionResponse:
    try:
        result = await service.execute(
            request.action,
            request.payload,
            confirmed=request.confirmed,
        )
    except ClarityControlServiceError as error:
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error

    await record_assistant_finance_audit(
        user_id=current_user.id,
        action=request.action,
        payload=request.payload,
        result=result,
        audit_service=audit_service,
    )

    return ClarityActionResponse(
        action=request.action,
        status="applied",
        result=result,
    )
