from __future__ import annotations

from typing import Optional


FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE = (
    "I don't have reliable Clarity financial data available for this turn, so I "
    "can't answer that without guessing. Please refresh your financial data or "
    "try again in a moment."
)


class ChatFinancialGuard:
    def financial_context_for_intent(
        self,
        intent_decision,
        financial_context: Optional[dict],
    ) -> Optional[dict]:
        if intent_decision is None:
            return None
        if getattr(intent_decision, "should_use_financial_context", False):
            return financial_context
        return None

    def guard_response(
        self,
        intent_decision,
        financial_context: Optional[dict],
    ) -> Optional[str]:
        if intent_decision is None:
            return None
        if not getattr(intent_decision, "should_use_financial_context", False):
            return None
        if self.is_reliable(financial_context):
            return None
        return FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE

    def is_reliable(self, financial_context: Optional[dict]) -> bool:
        if not isinstance(financial_context, dict) or not financial_context:
            return False

        data_status = financial_context.get("data_status")
        status = data_status if isinstance(data_status, dict) else {}
        state = str(
            status.get("state") or status.get("status") or data_status or ""
        ).strip().lower()
        if not state:
            return False
        if state in {"unavailable", "degraded", "partial", "error", "failed"}:
            return False
        if state != "ready":
            return False

        complete = status.get("financial_context_complete")
        if complete is False or str(complete).strip().lower() == "false":
            return False

        load_errors = status.get("load_errors")
        if load_errors is None:
            load_errors = financial_context.get("load_errors")
        if load_errors:
            return False

        integration = financial_context.get("integration")
        if isinstance(integration, dict):
            full_context = integration.get("full_financial_context_included")
            if full_context is False or str(full_context).strip().lower() == "false":
                return False

        return True
