from typing import Optional

from fastapi import HTTPException

from app.models.accountability import (
    AccountabilitySeverity,
    AccountabilitySignalResponse,
    AccountabilitySignalType,
    AccountabilitySourceType,
    AccountabilityStatus,
)
from app.services.accountability_service import AccountabilityService


async def analyze_signals(
    accountability_service: AccountabilityService,
    message: str,
    context: dict,
) -> list[AccountabilitySignalResponse]:
    try:
        signals = await accountability_service.analyze_signals(
            message=message,
            time_context=context["time_context"],
            personal_rules=context["personal_rules"],
            plans=context["plans"],
            plan_milestones=context["plan_milestones"],
            entity_events=context["entity_events"],
            relevant_memories=context["relevant_memories"],
            budget_performance=context.get("budget_performance"),
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail="Accountability analysis failed.",
        ) from error

    return [AccountabilitySignalResponse(**signal.model_dump()) for signal in signals]


def filter_signals(
    signals: list[AccountabilitySignalResponse],
    *,
    signal_type: Optional[AccountabilitySignalType],
    severity: Optional[AccountabilitySeverity],
    status: Optional[AccountabilityStatus],
    source_type: Optional[AccountabilitySourceType],
    limit: int,
) -> list[AccountabilitySignalResponse]:
    filtered = []
    for signal in signals:
        if signal_type is not None and signal.signal_type != signal_type:
            continue
        if severity is not None and signal.severity != severity:
            continue
        if status is not None and signal.status != status:
            continue
        if source_type is not None and not any(
            source.source_type == source_type for source in signal.source_refs
        ):
            continue
        filtered.append(signal)
    return filtered[:limit]
