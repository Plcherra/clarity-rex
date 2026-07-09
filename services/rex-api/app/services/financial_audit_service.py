"""Validated financial audit event payloads and recording."""

from __future__ import annotations

import logging
from typing import Any, Optional

from app.config import Settings, get_settings
from app.services.financial_audit_transport import FinancialAuditTransport

LOGGER = logging.getLogger("rex.financial_audit")

ALLOWED_EVENT_TYPES = frozenset(
    {
        "transaction_category_updated",
        "transaction_category_bulk_updated",
        "transaction_role_override_updated",
        "transaction_created",
        "transaction_updated",
        "transaction_deleted",
        "category_created",
        "category_deleted",
        "category_merged",
        "category_visibility_updated",
        "category_renamed",
        "category_updated",
        "budget_created",
        "budget_updated",
        "budget_deleted",
        "merchant_rule_category_updated",
        "merchant_rule_disabled_updated",
        "merchant_rule_deleted",
        "import_batch_deleted",
        "account_created",
        "account_updated",
        "account_deleted",
    }
)

# Client/native sources only. Assistant is server-owned.
ALLOWED_CLIENT_SOURCES = frozenset(
    {
        "app",
        "manual",
        "manual_bulk",
        "manual_merchant_rule",
    }
)

ASSISTANT_SOURCE = "assistant"


class FinancialAuditValidationError(Exception):
    def __init__(self, detail: str) -> None:
        super().__init__(detail)
        self.detail = detail


def build_audit_event_payload(
    *,
    user_id: str,
    event_type: str,
    entity_type: str,
    source: str,
    entity_id: str | None = None,
    previous_value: dict[str, Any] | None = None,
    new_value: dict[str, Any] | None = None,
    metadata: dict[str, Any] | None = None,
    allow_assistant_source: bool = False,
) -> dict[str, Any]:
    cleaned_type = str(event_type or "").strip()
    cleaned_entity = str(entity_type or "").strip()
    cleaned_source = str(source or "").strip() or "app"
    if not cleaned_type or cleaned_type not in ALLOWED_EVENT_TYPES:
        raise FinancialAuditValidationError("Unsupported financial audit event type.")
    if not cleaned_entity:
        raise FinancialAuditValidationError("Audit entity type is required.")
    if cleaned_source == ASSISTANT_SOURCE:
        if not allow_assistant_source:
            raise FinancialAuditValidationError("Assistant audit source is server-owned.")
    elif cleaned_source not in ALLOWED_CLIENT_SOURCES:
        raise FinancialAuditValidationError("Unsupported financial audit source.")

    payload: dict[str, Any] = {
        "user_id": user_id,
        "event_type": cleaned_type,
        "entity_type": cleaned_entity,
        "source": cleaned_source,
        "previous_value": previous_value or {},
        "new_value": new_value or {},
        "metadata": metadata or {},
    }
    entity = str(entity_id or "").strip()
    if entity:
        payload["entity_id"] = entity
    return payload


class FinancialAuditService:
    def __init__(
        self,
        settings: Optional[Settings] = None,
        transport: Optional[FinancialAuditTransport] = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.transport = transport or FinancialAuditTransport(self.settings)

    async def record_event(self, payload: dict[str, Any]) -> None:
        await self.transport.insert_event(payload)

    async def record_event_best_effort(self, payload: dict[str, Any]) -> None:
        try:
            await self.record_event(payload)
        except Exception as exc:
            LOGGER.warning(
                "financial_audit_record_failed error_class=%s",
                type(exc).__name__,
            )
