from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.dependencies import get_accountability_service, get_memory_service
from app.models.accountability import (
    AccountabilityOverviewResponse,
    AccountabilitySeverity,
    AccountabilitySignalResponse,
    AccountabilitySignalType,
    AccountabilitySourceType,
    AccountabilityStatus,
)
from app.routes.accountability_context_loader import load_accountability_context
from app.routes.accountability_overview_builder import build_accountability_overview
from app.routes.accountability_signal_filters import analyze_signals, filter_signals
from app.services.accountability_service import AccountabilityService
from app.services.memory_service import MemoryServiceError, SupabaseMemoryService


router = APIRouter(prefix="/accountability", tags=["accountability"])

DEFAULT_ACCOUNTABILITY_MESSAGE = "Review my current accountability context."


@router.get("/signals", response_model=list[AccountabilitySignalResponse])
async def list_accountability_signals(
    message: str = Query(default=DEFAULT_ACCOUNTABILITY_MESSAGE, min_length=1),
    signal_type: Optional[AccountabilitySignalType] = Query(default=None),
    severity: Optional[AccountabilitySeverity] = Query(default=None),
    status: Optional[AccountabilityStatus] = Query(default="active"),
    source_type: Optional[AccountabilitySourceType] = Query(default=None),
    limit: int = Query(default=25, ge=1, le=100),
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
    accountability_service: AccountabilityService = Depends(get_accountability_service),
) -> list[AccountabilitySignalResponse]:
    context = await _load_context(memory_service, message)
    signals = await analyze_signals(accountability_service, message, context)
    return filter_signals(
        signals,
        signal_type=signal_type,
        severity=severity,
        status=status,
        source_type=source_type,
        limit=limit,
    )


@router.get("/rule-risks", response_model=list[AccountabilitySignalResponse])
async def list_rule_risks(
    message: str = Query(default=DEFAULT_ACCOUNTABILITY_MESSAGE, min_length=1),
    severity: Optional[AccountabilitySeverity] = Query(default=None),
    limit: int = Query(default=25, ge=1, le=100),
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
    accountability_service: AccountabilityService = Depends(get_accountability_service),
) -> list[AccountabilitySignalResponse]:
    context = await _load_context(memory_service, message)
    signals = await analyze_signals(accountability_service, message, context)
    return filter_signals(
        signals,
        signal_type="rule_violation",
        severity=severity,
        status="active",
        source_type=None,
        limit=limit,
    )


@router.get("/plan-risks", response_model=list[AccountabilitySignalResponse])
async def list_plan_risks(
    message: str = Query(default=DEFAULT_ACCOUNTABILITY_MESSAGE, min_length=1),
    severity: Optional[AccountabilitySeverity] = Query(default=None),
    limit: int = Query(default=25, ge=1, le=100),
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
    accountability_service: AccountabilityService = Depends(get_accountability_service),
) -> list[AccountabilitySignalResponse]:
    context = await _load_context(memory_service, message)
    signals = await analyze_signals(accountability_service, message, context)
    plan_signals = [
        signal
        for signal in signals
        if signal.signal_type in {"plan_drift", "upcoming_deadline"}
    ]
    return filter_signals(
        plan_signals,
        signal_type=None,
        severity=severity,
        status="active",
        source_type=None,
        limit=limit,
    )


@router.get("/patterns", response_model=list[AccountabilitySignalResponse])
async def list_recent_patterns(
    message: str = Query(default=DEFAULT_ACCOUNTABILITY_MESSAGE, min_length=1),
    severity: Optional[AccountabilitySeverity] = Query(default=None),
    limit: int = Query(default=25, ge=1, le=100),
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
    accountability_service: AccountabilityService = Depends(get_accountability_service),
) -> list[AccountabilitySignalResponse]:
    context = await _load_context(memory_service, message)
    signals = await analyze_signals(accountability_service, message, context)
    return filter_signals(
        signals,
        signal_type="repeated_pattern",
        severity=severity,
        status="active",
        source_type=None,
        limit=limit,
    )


@router.get("/overview", response_model=AccountabilityOverviewResponse)
async def accountability_overview(
    message: str = Query(default=DEFAULT_ACCOUNTABILITY_MESSAGE, min_length=1),
    limit: int = Query(default=25, ge=1, le=100),
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
    accountability_service: AccountabilityService = Depends(get_accountability_service),
) -> AccountabilityOverviewResponse:
    context = await _load_context(memory_service, message)
    signals = await analyze_signals(accountability_service, message, context)
    return build_accountability_overview(
        message=message,
        context=context,
        signals=signals,
        limit=limit,
    )


async def _load_context(
    memory_service: SupabaseMemoryService,
    message: str,
) -> dict:
    try:
        return await load_accountability_context(memory_service, message)
    except MemoryServiceError as error:
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
