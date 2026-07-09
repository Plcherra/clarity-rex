"""Map applied Clarity finance actions to financial_audit_events."""

from __future__ import annotations

from typing import Any, Optional

from app.services.clarity_control_service import MUTATING_ACTIONS
from app.services.financial_audit_service import (
    ASSISTANT_SOURCE,
    FinancialAuditService,
    FinancialAuditValidationError,
    build_audit_event_payload,
)

_ACTION_EVENT_MAP: dict[str, tuple[str, str]] = {
    "create_transaction": ("transaction_created", "transaction"),
    "update_transaction": ("transaction_updated", "transaction"),
    "delete_transaction": ("transaction_deleted", "transaction"),
    "bulk_update_transaction_category": (
        "transaction_category_bulk_updated",
        "transaction",
    ),
    "delete_import_batch": ("import_batch_deleted", "import_batch"),
    "create_category": ("category_created", "category"),
    "update_category": ("category_updated", "category"),
    "delete_category": ("category_deleted", "category"),
    "create_budget": ("budget_created", "budget"),
    "update_budget": ("budget_updated", "budget"),
    "delete_budget": ("budget_deleted", "budget"),
    "create_account": ("account_created", "account"),
    "update_account": ("account_updated", "account"),
    "delete_account": ("account_deleted", "account"),
}


def _first_entity_id(result: list[dict[str, Any]], payload: dict[str, Any]) -> str | None:
    for row in result:
        entity_id = str(row.get("id") or "").strip()
        if entity_id:
            return entity_id
    for key in ("id", "category_id", "account_id", "import_id"):
        value = str(payload.get(key) or "").strip()
        if value:
            return value
    return None


def _refine_update_transaction_event(
    payload: dict[str, Any],
) -> tuple[str, str]:
    if "category_id" in payload or "category_key" in payload:
        return "transaction_category_updated", "transaction"
    return "transaction_updated", "transaction"


def build_assistant_audit_payload(
    *,
    user_id: str,
    action: str,
    payload: dict[str, Any],
    result: list[dict[str, Any]],
) -> dict[str, Any] | None:
    cleaned_action = str(action or "").strip()
    if cleaned_action not in MUTATING_ACTIONS:
        return None
    if cleaned_action == "update_transaction":
        event_type, entity_type = _refine_update_transaction_event(payload)
    else:
        mapped = _ACTION_EVENT_MAP.get(cleaned_action)
        if mapped is None:
            return None
        event_type, entity_type = mapped

    try:
        return build_audit_event_payload(
            user_id=user_id,
            event_type=event_type,
            entity_type=entity_type,
            source=ASSISTANT_SOURCE,
            entity_id=_first_entity_id(result, payload),
            new_value={
                "action": cleaned_action,
                "result_count": len(result),
                "payload_keys": sorted(str(key) for key in payload.keys()),
            },
            metadata={"clarity_action": cleaned_action},
            allow_assistant_source=True,
        )
    except FinancialAuditValidationError:
        return None


async def record_assistant_finance_audit(
    *,
    user_id: str,
    action: str,
    payload: dict[str, Any],
    result: list[dict[str, Any]],
    audit_service: Optional[FinancialAuditService] = None,
) -> None:
    event = build_assistant_audit_payload(
        user_id=user_id,
        action=action,
        payload=payload,
        result=result,
    )
    if event is None:
        return
    service = audit_service or FinancialAuditService()
    await service.record_event_best_effort(event)
