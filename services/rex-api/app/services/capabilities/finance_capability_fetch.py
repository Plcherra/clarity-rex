"""Capped finance fetch packs for `fetch_spend_insight` / `fetch_account_summary`.

Fetch-on-demand only: the base turn stays thin and these packs are built solely
when Grok asks for them. Every line comes from the app-provided context, so the
reply can quote real numbers instead of inventing them.
"""

from __future__ import annotations

from typing import Optional

from app.services.capabilities.finance_action_payload import FinanceFetchRequest
from app.services.capabilities.finance_context_lookup import (
    context_dict,
    context_list,
    find_account,
    matching_transactions,
    merchant_month_rollups,
    spend_total,
    transaction_coverage,
    transaction_line,
)

FETCH_PACK_CHAR_BUDGET = 2200
_MAX_TRANSACTION_ROWS = 8
_MAX_ACCOUNTS = 8
_MAX_CATEGORIES = 6
_MAX_CATEGORY_MERCHANTS = 6


def build_finance_fetch_pack(
    request: FinanceFetchRequest,
    financial_context: Optional[dict],
) -> Optional[str]:
    if not isinstance(financial_context, dict) or not financial_context:
        return None
    if request.is_account_summary:
        lines = _account_summary_lines(request, financial_context)
    else:
        lines = _spend_insight_lines(request, financial_context)
    if not lines:
        return None
    return _capped("\n".join(lines))


def _spend_insight_lines(
    request: FinanceFetchRequest,
    financial_context: dict,
) -> list[str]:
    lines = [f"fetch_spend_insight ({_scope_label(request)})"]
    lines.extend(_period_lines(financial_context))
    lines.extend(_cash_flow_lines(financial_context))
    lines.extend(_category_lines(request, financial_context))
    lines.extend(_merchant_rollup_lines(request, financial_context))
    lines.extend(_transaction_lines(request, financial_context))
    lines.extend(_budget_lines(financial_context))
    lines.extend(_coverage_lines(financial_context))
    return lines


def _account_summary_lines(
    request: FinanceFetchRequest,
    financial_context: dict,
) -> list[str]:
    accounts = context_list(financial_context, "accounts")
    focused = find_account(financial_context, request.account_reference)
    if focused is not None:
        accounts = [focused]
    lines = [f"fetch_account_summary ({_scope_label(request)})"]
    if not accounts:
        lines.append("- No accounts are connected in Clarity.")
        return lines
    if request.account_reference and focused is None:
        lines.append(
            f"- No account in Clarity matches \"{request.account_reference}\"; "
            "listing what exists."
        )
    for account in accounts[:_MAX_ACCOUNTS]:
        lines.append(f"- Account: {_account_summary(account)}")
    freshness = context_dict(financial_context, "freshness")
    state = str(freshness.get("state") or "").strip()
    if state:
        lines.append(f"- Sync freshness: {state}")
    guidance = str(freshness.get("guidance") or "").strip()
    if guidance:
        lines.append(f"- Freshness guidance: {guidance}")
    lines.extend(_cash_flow_lines(financial_context))
    if focused is not None:
        rows = matching_transactions(
            financial_context,
            account_id=str(focused.get("id") or "") or None,
            limit=5,
        )
        if rows:
            lines.append("- Recent transactions on this account:")
            lines.extend(f"  - {transaction_line(row)}" for row in rows)
    return lines


def _period_lines(financial_context: dict) -> list[str]:
    period = context_dict(financial_context, "period")
    if not period:
        return []
    return [
        "- Period: "
        f"month={period.get('reference_month')}; "
        f"transactions={period.get('transaction_count')}; "
        f"included={period.get('included_transaction_count')}; "
        f"range={period.get('first_transaction_date')} to "
        f"{period.get('last_transaction_date')}"
    ]


def _cash_flow_lines(financial_context: dict) -> list[str]:
    cash_flow = context_dict(financial_context, "cash_flow")
    if not cash_flow:
        return []
    return [
        "- Cash flow: "
        f"balance={cash_flow.get('total_balance')}; "
        f"spent_this_month={cash_flow.get('spent_this_month')}; "
        f"income_this_month={cash_flow.get('income_this_month')}; "
        f"available_this_month={cash_flow.get('available_this_month')}"
    ]


def _category_lines(
    request: FinanceFetchRequest,
    financial_context: dict,
) -> list[str]:
    spend = context_list(financial_context, "category_spend_this_month")
    if not spend:
        top = context_list(financial_context, "top_spending_categories")
        if not top:
            return []
        summary = "; ".join(
            f"{item.get('category')}={item.get('spent')}"
            for item in top[:_MAX_CATEGORIES]
        )
        return [f"- Top spending categories this month: {summary}"]

    if request.category:
        wanted = request.category.strip().lower()
        matches = [
            item
            for item in spend
            if wanted in str(item.get("category") or "").strip().lower()
        ]
        if matches:
            return [f"- {_category_spend_line(item)}" for item in matches]
        return [
            f"- No category named \"{request.category}\" has spend this month in "
            "Clarity.",
            "- Categories with spend this month: "
            + "; ".join(
                str(item.get("category") or "") for item in spend[:_MAX_CATEGORIES]
            ),
        ]
    return [f"- {_category_spend_line(item)}" for item in spend[:_MAX_CATEGORIES]]


def _merchant_rollup_lines(
    request: FinanceFetchRequest,
    financial_context: dict,
) -> list[str]:
    rollups = merchant_month_rollups(financial_context, request.merchant)
    if not rollups:
        return []
    parts = []
    for rollup in rollups:
        part = f"{rollup['merchant']} ({rollup['category']}): spent={rollup['spent']}"
        count = rollup.get("transaction_count")
        if count is not None:
            part = f"{part}; transactions={count}"
        parts.append(part)
    return [
        "- Merchant totals for the whole period (Clarity's own rollup): "
        + "; ".join(parts)
    ]


def _transaction_lines(
    request: FinanceFetchRequest,
    financial_context: dict,
) -> list[str]:
    needle = request.merchant or request.category
    if not needle:
        return []
    rows = matching_transactions(
        financial_context,
        merchant=request.merchant,
        category=request.category if not request.merchant else None,
    )
    coverage = transaction_coverage(financial_context)
    if not rows:
        # Category totals already answer category questions; only a merchant ask
        # needs the explicit "nothing matched" line.
        if not request.merchant:
            return []
        if coverage:
            return [
                f"- No rows match \"{needle}\" in the transaction detail Clarity "
                f"sent, and that detail is partial ({coverage}), so say the "
                "detail is incomplete rather than that nothing was spent."
            ]
        return [f"- No transactions in this context match \"{needle}\"."]
    total = spend_total(rows)
    if coverage:
        # Counting sampled rows undercounts the period; the totals above do not.
        header = (
            f"- Example rows matching \"{needle}\" — {len(rows)} row(s) out of "
            "the partial detail Clarity sent, NOT every transaction in the "
            "period. Quote the totals above for amounts and present these as "
            "examples"
        )
        if total is not None:
            header = f"{header} (these rows alone add to {total:.2f})"
    else:
        header = (
            f"- Every row matching \"{needle}\" this period: count={len(rows)}"
        )
        if total is not None:
            header = f"{header}; total={total:.2f}"
    lines = [header]
    lines.extend(
        f"  - {transaction_line(row)}" for row in rows[:_MAX_TRANSACTION_ROWS]
    )
    if len(rows) > _MAX_TRANSACTION_ROWS:
        lines.append(
            f"  - (+{len(rows) - _MAX_TRANSACTION_ROWS} more rows not listed)"
        )
    return lines


def _coverage_lines(financial_context: dict) -> list[str]:
    coverage = transaction_coverage(financial_context)
    if not coverage:
        return []
    return [
        f"- Transaction detail coverage: {coverage}. Category and cash-flow "
        "totals above are Clarity's own totals and stay usable."
    ]


def _budget_lines(financial_context: dict) -> list[str]:
    budget = context_dict(financial_context, "budget")
    if not budget:
        return []
    return [
        "- Budget: "
        f"period={budget.get('period_type')}:{budget.get('period_key')}; "
        f"budgeted={budget.get('total_budgeted')}; "
        f"spent={budget.get('total_spent')}; "
        f"remaining={budget.get('total_remaining')}; "
        f"overspent={budget.get('total_overspent')}"
    ]


def _category_spend_line(item: dict) -> str:
    line = (
        f"Category {item.get('category')} for the whole period (Clarity's own "
        f"total): spent={item.get('spent')}; "
        f"transactions={item.get('transaction_count')}"
    )
    breakdown = _merchant_breakdown(item.get("top_merchants"))
    if breakdown:
        # A category label is the user's bucket, not a definition — the split by
        # merchant is what lets the answer separate coffee from fast food.
        line = f"{line}; merchants inside it: {breakdown}"
    return line


def _merchant_breakdown(merchants: object) -> str:
    if not isinstance(merchants, list):
        return ""
    parts: list[str] = []
    for entry in merchants[:_MAX_CATEGORY_MERCHANTS]:
        if not isinstance(entry, dict):
            label = str(entry).strip()
            if label:
                parts.append(label)
            continue
        label = str(entry.get("merchant") or entry.get("name") or "").strip()
        if not label:
            continue
        spent = entry.get("spent")
        count = entry.get("transaction_count")
        if spent is not None:
            label = f"{label} {spent}"
        if count is not None:
            label = f"{label} ({count} tx)"
        parts.append(label)
    return "; ".join(parts)


def _account_summary(account: dict) -> str:
    parts = [str(account.get("display_name") or account.get("name") or "account")]
    for key, label in (
        ("type", "type"),
        ("institution", "institution"),
        ("mask", "mask"),
        ("current_balance", "current_balance"),
        ("available_balance", "available_balance"),
        ("sync_status", "sync_status"),
        ("last_synced_at", "last_synced_at"),
    ):
        value = account.get(key)
        if value is None or str(value).strip() == "":
            continue
        parts.append(f"{label}={value}")
    return "; ".join(parts)


def _scope_label(request: FinanceFetchRequest) -> str:
    parts = [
        f"category={request.category}" if request.category else "",
        f"merchant={request.merchant}" if request.merchant else "",
        f"account={request.account_reference}" if request.account_reference else "",
        f"period={request.period}" if request.period else "",
    ]
    joined = "; ".join(part for part in parts if part)
    return joined or "no filters"


def _capped(pack: str) -> str:
    if len(pack) <= FETCH_PACK_CHAR_BUDGET:
        return pack
    kept: list[str] = []
    used = 0
    for line in pack.split("\n"):
        if used + len(line) + 1 > FETCH_PACK_CHAR_BUDGET:
            kept.append("- (context truncated to stay within the turn budget)")
            break
        kept.append(line)
        used += len(line) + 1
    return "\n".join(kept)
