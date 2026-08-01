import json
from typing import Any, Optional

from app.services.prompt_constants import (
    FINANCIAL_CONTEXT_PREFIX,
    MAX_FINANCIAL_CONTEXT_CHARACTERS,
)
from app.services.prompt_financial_write_playbook import FINANCIAL_WRITE_PLAYBOOK

_TRANSACTION_CHAR_BUDGET_RATIO = 0.4


class PromptFinancialContextMixin:
    def _financial_context_section(
        self, financial_context: Optional[dict]
    ) -> Optional[str]:
        if not financial_context:
            return None

        write_playbook = FINANCIAL_WRITE_PLAYBOOK
        write_rule = (
            "For create/update/delete requests, ask for confirmation and append a "
            "fenced ```clarity_action``` JSON object with action, payload, "
            "confirmation_text, and risk_level. Use only actions listed in "
            "available_controls."
        )

        header = (
            "Rex is inside Clarity. Use this as first-party Clarity financial context. "
            "It may include specific accounts, account names, budgets, categories, merchants, "
            "descriptions, matched_transactions, and transaction rows. You may reference "
            "specific records when they are present. Prefer matched_transactions and "
            "category_spend_this_month when answering merchant/category/budget questions. "
            "Do not offer to pull, check, fetch, or list transaction details later unless "
            "the details are already present in this context or an execution result provides "
            "them. If this context says data is unavailable, degraded, stale, partial, or "
            "incomplete, say that clearly before answering and do not guess missing accounts, "
            "balances, budgets, categories, or transactions. When freshness is stale, quote "
            "exact current_balance values from account rows only; do not estimate payoff "
            "amounts, interest, or fees. "
            f"{write_rule} "
            "Never claim a financial record was changed unless an "
            "execution result says it succeeded."
            f"\n{write_playbook}"
        )
        priority_lines, transaction_lines, metadata_lines = (
            self._financial_context_line_groups(financial_context)
        )

        lines = [header]
        used_characters = len(header) + 1
        tx_budget = int(MAX_FINANCIAL_CONTEXT_CHARACTERS * _TRANSACTION_CHAR_BUDGET_RATIO)
        tx_used = 0

        for line in priority_lines:
            used_characters, appended = self._append_financial_line(
                lines,
                line,
                used_characters=used_characters,
                max_characters=MAX_FINANCIAL_CONTEXT_CHARACTERS,
            )
            if not appended:
                break

        for line in transaction_lines:
            if tx_used >= tx_budget:
                break
            remaining_total = MAX_FINANCIAL_CONTEXT_CHARACTERS - used_characters
            remaining_tx = tx_budget - tx_used
            if remaining_total <= 0 or remaining_tx <= 0:
                break
            line_budget = min(remaining_total, remaining_tx)
            clipped = self._clip_financial_line(line, line_budget)
            if not clipped:
                break
            lines.append(clipped)
            used_characters += len(clipped) + 1
            tx_used += len(clipped) + 1

        for line in metadata_lines:
            used_characters, appended = self._append_financial_line(
                lines,
                line,
                used_characters=used_characters,
                max_characters=MAX_FINANCIAL_CONTEXT_CHARACTERS,
            )
            if not appended:
                break

        if len(lines) == 1:
            return None
        return f"{FINANCIAL_CONTEXT_PREFIX}{chr(10).join(lines)}"

    def _financial_context_line_groups(
        self, financial_context: dict
    ) -> tuple[list[str], list[str], list[str]]:
        priority: list[str] = []
        transactions: list[str] = []
        metadata: list[str] = []

        schema = financial_context.get("schema")
        generated_at = financial_context.get("generated_at")
        if schema or generated_at:
            priority.append(
                f"- Context: schema={schema}; generated_at={generated_at}"
            )

        status = self._financial_status_summary(financial_context)
        if status:
            priority.append(status)

        freshness = self._dict_value(financial_context, "freshness")
        guidance = freshness.get("guidance")
        if isinstance(guidance, str) and guidance.strip():
            priority.append(f"- Freshness guidance: {guidance.strip()}")

        matched = self._list_value(financial_context, "matched_transactions")
        if matched:
            priority.append(
                f"- Matched transactions ({len(matched)} for this question):"
            )
            transactions.extend(
                f"  - {self._compact_json(transaction)}"
                for transaction in matched
                if isinstance(transaction, dict)
            )

        category_spend = self._list_value(
            financial_context,
            "category_spend_this_month",
        )
        if category_spend:
            priority.append(
                "- Category spend this month: "
                + "; ".join(
                    self._category_spend_summary(item)
                    for item in category_spend[:8]
                    if isinstance(item, dict)
                )
            )

        period = self._dict_value(financial_context, "period")
        if period:
            priority.append(
                "- Period: "
                f"reference_month={period.get('reference_month')}; "
                f"transaction_count={period.get('transaction_count')}; "
                f"included={period.get('included_transaction_count')}; "
                f"matched={period.get('included_matched_transaction_count')}; "
                f"range={period.get('first_transaction_date')} to {period.get('last_transaction_date')}"
            )

        cash_flow = self._dict_value(financial_context, "cash_flow")
        if cash_flow:
            priority.append(
                "- Cash flow: "
                f"balance={cash_flow.get('total_balance')}; "
                f"income_this_month={cash_flow.get('income_this_month')}; "
                f"spent_this_month={cash_flow.get('spent_this_month')}; "
                f"available_this_month={cash_flow.get('available_this_month')}; "
                f"burn_runway_days={cash_flow.get('burn_runway_days')}"
            )

        budget = self._dict_value(financial_context, "budget")
        if budget:
            priority.append(
                "- Budget: "
                f"period={budget.get('period_type')}:{budget.get('period_key')}; "
                f"budgeted={budget.get('total_budgeted')}; "
                f"spent={budget.get('total_spent')}; "
                f"remaining={budget.get('total_remaining')}; "
                f"overspent={budget.get('total_overspent')}; "
                f"categories={budget.get('budgeted_category_count')}"
            )

        top_categories = self._list_value(financial_context, "top_spending_categories")
        if top_categories:
            priority.append(
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
            priority.append(
                "- Biggest month-over-month increases: "
                + "; ".join(
                    self._financial_increase_summary(item)
                    for item in increases[:3]
                    if isinstance(item, dict)
                )
            )

        overspending = self._list_value(budget or {}, "top_overspending_categories")
        if overspending:
            priority.append(
                "- Top overspending categories: "
                + "; ".join(
                    f"{item.get('category')} overspent={item.get('overspent')}"
                    for item in overspending[:3]
                    if isinstance(item, dict)
                )
            )

        retrieval = self._dict_value(financial_context, "retrieval")
        if retrieval:
            metadata.append("- Retrieval: " + self._compact_json(retrieval))

        controls = self._dict_value(financial_context, "available_controls")
        if controls:
            metadata.append("- Available controls: " + self._compact_json(controls))

        rows = self._list_value(financial_context, "transactions")
        if rows:
            transactions.append(f"- Transactions ({len(rows)}, newest first):")
            transactions.extend(
                f"  - {self._compact_json(transaction)}"
                for transaction in rows
                if isinstance(transaction, dict)
            )

        slices = self._dict_value(financial_context, "transaction_slices")
        if slices:
            metadata.extend(self._financial_slice_lines(slices))

        accounts = self._list_value(financial_context, "accounts")
        if accounts:
            metadata.append(f"- Accounts ({len(accounts)}):")
            metadata.extend(
                f"  - {self._compact_account(account)}"
                for account in accounts
                if isinstance(account, dict)
            )

        categories = self._list_value(financial_context, "categories")
        if categories:
            metadata.append(f"- Categories ({len(categories)}):")
            metadata.extend(
                f"  - {self._compact_json(category)}"
                for category in categories[:12]
                if isinstance(category, dict)
            )

        budgets = self._list_value(financial_context, "budgets")
        if budgets:
            metadata.append(f"- Budget records ({len(budgets)}):")
            metadata.extend(
                f"  - {self._compact_json(budget_record)}"
                for budget_record in budgets[:12]
                if isinstance(budget_record, dict)
            )

        integration = self._dict_value(financial_context, "integration")
        if integration:
            metadata.append("- Integration: " + self._compact_json(integration))

        return priority, transactions, metadata

    def _append_financial_line(
        self,
        lines: list[str],
        line: str,
        *,
        used_characters: int,
        max_characters: int,
    ) -> tuple[int, bool]:
        if not line:
            return used_characters, False
        clipped = self._clip_financial_line(line, max_characters - used_characters)
        if not clipped:
            return used_characters, False
        lines.append(clipped)
        return used_characters + len(clipped) + 1, True

    def _clip_financial_line(self, line: str, remaining_characters: int) -> str:
        if remaining_characters <= 0:
            return ""
        if len(line) <= remaining_characters:
            return line
        if remaining_characters < 40:
            return ""
        return f"{line[: remaining_characters - 22].rstrip()} [truncated]"

    def _compact_account(self, account: dict) -> str:
        compact = {
            key: account.get(key)
            for key in (
                "id",
                "name",
                "display_name",
                "type",
                "current_balance",
                "available_balance",
                "institution",
                "mask",
                "last_synced_at",
                "sync_status",
            )
            if account.get(key) is not None
        }
        return self._compact_json(compact)

    def _category_spend_summary(self, item: dict) -> str:
        summary = (
            f"{item.get('category')} spent={item.get('spent')} "
            f"count={item.get('transaction_count')}"
        )
        merchants = self._list_value(item, "top_merchants")
        if merchants:
            summary = (
                f"{summary} merchants={self._compact_json(merchants[:3])}"
            )
        return summary

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
            warning = (
                " Rex must explicitly tell the user this financial data is not fully "
                "reliable."
            )
        elif str(freshness_state).lower() in {"stale", "unknown"}:
            warning = (
                " Rex must explicitly tell the user the financial sync freshness is stale "
                "or unknown and must quote exact current_balance values from account rows "
                "only."
            )
        return "- Data status: " + "; ".join(parts) + f".{warning}"

    def _financial_slice_lines(self, slices: dict) -> list[str]:
        lines: list[str] = []
        for key, label in (
            ("months", "Month slices"),
            ("accounts", "Account slices"),
            ("categories", "Category slices"),
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
        label = str(item.get("label") or "")
        summary = (
            f"{label} count={item.get('transaction_count')} "
            f"spend={item.get('spend')} income={item.get('income')} "
            f"net={item.get('net')} latest={item.get('latest_date')}"
        )
        detail_status = item.get("detail_status")
        if detail_status:
            summary = f"{summary} detail_status={detail_status}"
        included_sample_count = item.get("included_sample_count")
        if included_sample_count is not None:
            summary = f"{summary} included_sample_count={included_sample_count}"
        samples = self._list_value(item, "sample_transactions")
        if samples:
            summary = f"{summary} samples={self._compact_json(samples[:5])}"
        elif item.get("key"):
            summary = f"{summary} detail_status=aggregate_only"
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
