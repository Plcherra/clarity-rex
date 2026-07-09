from fastapi import APIRouter, Depends, HTTPException

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_financial_audit_service
from app.models.financial_audit import (
    FinancialAuditEventRequest,
    FinancialAuditEventResponse,
)
from app.services.financial_audit_service import (
    FinancialAuditService,
    FinancialAuditValidationError,
    build_audit_event_payload,
)

router = APIRouter(prefix="/finance", tags=["finance"])


@router.post("/audit-events", response_model=FinancialAuditEventResponse)
async def record_financial_audit_event(
    request: FinancialAuditEventRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    audit_service: FinancialAuditService = Depends(get_financial_audit_service),
) -> FinancialAuditEventResponse:
    try:
        payload = build_audit_event_payload(
            user_id=current_user.id,
            event_type=request.event_type,
            entity_type=request.entity_type,
            source=request.source,
            entity_id=request.entity_id,
            previous_value=request.previous_value,
            new_value=request.new_value,
            metadata=request.metadata,
            allow_assistant_source=False,
        )
    except FinancialAuditValidationError as error:
        raise HTTPException(status_code=400, detail=error.detail) from error

    try:
        await audit_service.record_event(payload)
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail="Could not record financial audit event.",
        ) from error

    return FinancialAuditEventResponse()
