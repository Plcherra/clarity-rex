import json
from typing import Any, Optional

from app.services.prompt_constants import (
    FINANCIAL_CONTEXT_PREFIX,
    MAX_FINANCIAL_CONTEXT_CHARACTERS,
)


class PromptFinancialContextMixin:
    def _financial_context_section(
        self, financial_context: Optional[dict]
    ) -> Optional[str]:
        if not financial_context:
            return None

        lines = [
            "Rex is inside Clarity. Use this as first-party Clarity financial context. It may include specific accounts, account names, budgets, categories, merchants, descriptions, and transaction rows. You may reference specific records when they are present. Review queues are not user-facing categories; describe them as app review states, and use included transaction rows or sample_transactions to list names/descriptions when present. If this context says data is unavailable, degraded, stale, partial, or incomplete, say that clearly before answering and do not guess missing accounts, balances, budgets, categories, or transactions. For create/update/delete requests, ask for confirmation and append a fenced ```clarity_action``` JSON object with action, payload, confirmation_text, and risk_level. Use only actions listed in available_controls. Never claim a financial record was changed unless an execution result says it succeeded."
        ]
        used_characters = len(lines[0]) + 1

        for line in self._financial_context_lines(financial_context):
            if not line:
                continue
            remaining_characters = MAX_FINANCIAL_CONTEXT_CHARACTERS - used_characters
            if remaining_characters <= 0:
                break
            if len(line) > remaining_characters:
                if remaining_characters < 40:
                    break
                line = f"{line[: remaining_characters - 22].rstrip()} [truncated]"
            lines.append(line)
            used_characters += len(line) + 1

        if len(lines) == 1:
            return None
        return f"{FINANCIAL_CONTEXT_PREFIX}{chr(10).join(lines)}"

    def _financial_context_lines(self, financial_context: dict) -> list[str]:
        lines: list[str] = []
        schema = financial_context.get("schema")
        generated_at = financial_context.get("generated_at")
        if schema or generated_at:
            lines.append(f"- Context: schema={schema}; generated_at={generated_at}")

        status = self._financial_status_summary(financial_context)
        if status:
            lines.append(status)

        integration = self._dict_value(financial_context, "integration")
        if integration:
            lines.append("- Integration: " + self._compact_json(integration))

        retrieval = self._dict_value(financial_context, "retrieval")
        if retrieval:
            lines.append("- Retrieval: " + self._compact_json(retrieval))

        controls = self._dict_value(financial_context, "available_controls")
        if controls:
            lines.append("- Available controls: " + self._compact_json(controls))

        period = self._dict_value(financial_context, "period")
        if period:
            lines.append(
                "- Period: "
                f"reference_month={period.get('reference_month')}; "
                f"transaction_count={period.get('transaction_count')}; "
                f"range={period.get('first_transaction_date')} to {period.get('last_transaction_date')}"
            )

        cash_flow = self._dict_value(financial_context, "cash_flow")
        if cash_flow:
            lines.append(
                "- Cash flow: "
                f"balance={cash_flow.get('total_balance')}; "
                f"income_this_month={cash_flow.get('income_this_month')}; "
                f"spent_this_month={cash_flow.get('spent_this_month')}; "
                f"available_this_month={cash_flow.get('available_this_month')}; "
                f"burn_runway_days={cash_flow.get('burn_runway_days')}"
            )

        budget = self._dict_value(financial_context, "budget")
        if budget:
            lines.append(
                "- Budget: "
                f"period={budget.get('period_type')}:{budget.get('period_key')}; "
                f"budgeted={budget.get('total_budgeted')}; "
                f"spent={budget.get('total_spent')}; "
                f"remaining={budget.get('total_remaining')}; "
                f"overspent={budget.get('total_overspent')}; "
                f"categories={budget.get('budgeted_category_count')}"
            )

        accounts = self._list_value(financial_context, "accounts")
        if accounts:
            lines.append(f"- Accounts ({len(accounts)}):")
            lines.extend(
                f"  - {self._compact_json(account)}"
                for account in accounts
                if isinstance(account, dict)
            )

        categories = self._list_value(financial_context, "categories")
        if categories:
            lines.append(f"- Categories ({len(categories)}):")
            lines.extend(
                f"  - {self._compact_json(category)}"
                for category in categories
                if isinstance(category, dict)
            )

        budgets = self._list_value(financial_context, "budgets")
        if budgets:
            lines.append(f"- Budget records ({len(budgets)}):")
            lines.extend(
                f"  - {self._compact_json(budget_record)}"
                for budget_record in budgets
                if isinstance(budget_record, dict)
            )

        top_categories = self._list_value(financial_context, "top_spending_categories")
        if top_categories:
            lines.append(
                "- Top spending categories: "
                + "; ".join(
                    f"{item.get('category')}={item.get('spent')}"
                    for item in top_categories[:5]
                    if isinstance(item, dict)
                )
            )

        increases = self._list_value(
            financial_context,
            "biggest_month_over_month_increases",
        )
        if increases:
            lines.append(
                "- Biggest month-over-month increases: "
                + "; ".join(
                    self._financial_increase_summary(item)
                    for item in increases[:3]
                    if isinstance(item, dict)
                )
            )

        overspending = self._list_value(budget or {}, "top_overspending_categories")
        if overspending:
            lines.append(
                "- Top overspending categories: "
                + "; ".join(
                    f"{item.get('category')} overspent={item.get('overspent')}"
                    for item in overspending[:3]
                    if isinstance(item, dict)
                )
            )

        slices = self._dict_value(financial_context, "transaction_slices")
        if slices:
            lines.extend(self._financial_slice_lines(slices))

        transactions = self._list_value(financial_context, "transactions")
        if transactions:
            lines.append(f"- Transactions ({len(transactions)}, newest first):")
            lines.extend(
                f"  - {self._compact_json(transaction)}"
                for transaction in transactions
                if isinstance(transaction, dict)
            )

        return lines

    def _financial_status_summary(self, financial_context: dict) -> str:
        data_status = self._dict_value(financial_context, "data_status")
        state = (
            data_status.get("state")
            if data_status
            else financial_context.get("data_status")
        )
        complete = data_status.get("financial_context_complete")
        load_errors = data_status.get("load_errors")
        if load_errors is None:
            load_errors = financial_context.get("load_errors")
        freshness = self._dict_value(financial_context, "freshness")
        freshness_state = freshness.get("state")

        parts = []
        if state is not None:
            parts.append(f"state={state}")
        if complete is not None:
            parts.append(f"complete={complete}")
        if freshness_state is not None:
            parts.append(f"freshness={freshness_state}")
        if load_errors:
            parts.append(f"load_errors={self._compact_json(load_errors)}")
        if freshness:
            stale_accounts = self._list_value(freshness, "stale_plaid_accounts")
            unknown_accounts = self._list_value(freshness, "unknown_sync_accounts")
            if stale_accounts:
                parts.append(f"stale_accounts={self._compact_json(stale_accounts)}")
            if unknown_accounts:
                parts.append(
                    f"unknown_sync_accounts={self._compact_json(unknown_accounts)}"
                )
        if not parts:
            return ""

        warning = ""
        if str(state).lower() in {"unavailable", "degraded", "partial"}:
            warning = " Rex must explicitly tell the user this financial data is not fully reliable."
        elif str(freshness_state).lower() in {"stale", "unknown"}:
            warning = " Rex must explicitly tell the user the financial sync freshness is stale or unknown."
        return "- Data status: " + "; ".join(parts) + f".{warning}"

    def _financial_slice_lines(self, slices: dict) -> list[str]:
        lines: list[str] = []
        for key, label in (
            ("months", "Month slices"),
            ("accounts", "Account slices"),
            ("categories", "Category slices"),
            ("review_queues", "Review queues"),
        ):
            items = self._list_value(slices, key)
            if not items:
                continue
            lines.append(
                f"- {label}: "
                + "; ".join(
                    self._financial_slice_summary(item)
                    for item in items[:8]
                    if isinstance(item, dict)
                )
            )
        return lines

    def _financial_slice_summary(self, item: dict) -> str:
        summary = (
            f"{item.get('label')} count={item.get('transaction_count')} "
            f"spend={item.get('spend')} income={item.get('income')} "
            f"net={item.get('net')} latest={item.get('latest_date')}"
        )
        samples = self._list_value(item, "sample_transactions")
        if samples:
            summary = f"{summary} samples={self._compact_json(samples[:5])}"
        return summary

    def _financial_increase_summary(self, item: dict) -> str:
        summary = (
            f"{item.get('category')}: "
            f"{item.get('spent_last_month')} -> {item.get('spent_this_month')}"
        )
        percent_change = item.get("percent_change")
        if percent_change is not None:
            summary = f"{summary} ({percent_change}%)"
        return summary

    def _dict_value(self, value: dict, key: str) -> dict:
        nested = value.get(key)
        return nested if isinstance(nested, dict) else {}

    def _list_value(self, value: dict, key: str) -> list:
        nested = value.get(key)
        return nested if isinstance(nested, list) else []

    def _compact_json(self, value: Any) -> str:
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"), default=str)
