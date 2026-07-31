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
        return self.unreliable_reason(financial_context) is None

    def unreliable_reason(self, financial_context: Optional[dict]) -> Optional[str]:
        """Short reason this pack cannot be quoted, or None when it can.

        A pack the app trimmed to fit the request size limit still reports real
        accounts, totals, and budgets, so it stays quotable and the fetch pack
        declares the missing row-level detail. Only a load failure or a
        non-ready sync makes the numbers untrustworthy.
        """
        if not isinstance(financial_context, dict) or not financial_context:
            return "missing"

        data_status = financial_context.get("data_status")
        status = data_status if isinstance(data_status, dict) else {}
        state = str(
            status.get("state") or status.get("status") or data_status or ""
        ).strip().lower()
        if not state:
            return "no_data_status"
        if state != "ready":
            return f"state={state}"

        complete = status.get("financial_context_complete")
        if complete is False or str(complete).strip().lower() == "false":
            return "financial_context_incomplete"

        load_errors = status.get("load_errors")
        if load_errors is None:
            load_errors = financial_context.get("load_errors")
        if load_errors:
            return "load_errors"

        return None
