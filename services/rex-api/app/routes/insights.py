from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_insight_sync_service
from app.services.insight_sync_service import InsightSyncResult, InsightSyncService
from app.services.memory_errors import MemoryServiceError


router = APIRouter(prefix="/insights", tags=["insights"])


class InsightRecordResponse(BaseModel):
    id: str
    fingerprint: str
    source: str
    insight_type: str
    title: str
    body: str
    period_key: str
    anchor_key: Optional[str] = None
    payload_json: dict[str, Any] = Field(default_factory=dict)
    generated_at: Optional[str] = None
    read_at: Optional[str] = None
    dismissed_at: Optional[str] = None


class InsightListResponse(BaseModel):
    items: list[InsightRecordResponse]


class InsightSyncRequest(BaseModel):
    financial_context: Optional[dict[str, Any]] = None
    accountability_signals: Optional[list[dict[str, Any]]] = None


class InsightSyncResponse(BaseModel):
    skipped: bool = False
    reason: Optional[str] = None
    created: int = 0
    updated: int = 0
    total_generated: int = 0


@router.get("", response_model=InsightListResponse)
async def list_insights(
    limit: int = 50,
    service: InsightSyncService = Depends(get_insight_sync_service),
) -> InsightListResponse:
    try:
        rows = await service.list_insights(limit=min(max(limit, 1), 100))
    except MemoryServiceError as error:
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
    return InsightListResponse(items=[InsightRecordResponse(**row) for row in rows])


@router.post("/sync", response_model=InsightSyncResponse)
async def sync_insights(
    payload: InsightSyncRequest,
    service: InsightSyncService = Depends(get_insight_sync_service),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> InsightSyncResponse:
    try:
        proactive_enabled = await service.fetch_proactive_enabled()
        result: InsightSyncResult = await service.sync(
            proactive_insights_enabled=proactive_enabled,
            financial_context=payload.financial_context,
            accountability_signals=payload.accountability_signals,
        )
    except MemoryServiceError as error:
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
    _ = current_user
    return InsightSyncResponse(
        skipped=result.skipped,
        reason=result.reason,
        created=result.created,
        updated=result.updated,
        total_generated=result.total_generated,
    )


@router.patch("/{insight_id}/read", response_model=InsightRecordResponse)
async def mark_insight_read(
    insight_id: str,
    service: InsightSyncService = Depends(get_insight_sync_service),
) -> InsightRecordResponse:
    try:
        row = await service.mark_read(insight_id)
    except MemoryServiceError as error:
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
    if row is None:
        raise HTTPException(status_code=404, detail="Insight not found.")
    return InsightRecordResponse(**row)
