from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Any, Optional


DASHBOARD_SOURCE = "dashboard_snapshot"
ACCOUNTABILITY_SOURCE = "accountability"


@dataclass(frozen=True)
class GeneratedInsight:
    fingerprint: str
    source: str
    insight_type: str
    title: str
    body: str
    period_key: str
    anchor_key: Optional[str] = None
    payload_json: Optional[dict[str, Any]] = None


def build_insight_fingerprint(
    *,
    source: str,
    insight_type: str,
    period_key: str,
    detail_key: str = "",
) -> str:
    parts = "|".join([source, insight_type, period_key, detail_key])
    return hashlib.sha256(parts.encode("utf-8")).hexdigest()


def _money(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        cleaned = value.replace("$", "").replace(",", "").strip()
        try:
            return float(cleaned)
        except ValueError:
            return 0.0
    return 0.0


def _format_money(value: float) -> str:
    return f"${abs(value):,.2f}"


def _format_percent(fraction: float) -> str:
    return f"{round(fraction * 100)}%"


def _period_key(financial_context: dict[str, Any]) -> str:
    period = financial_context.get("period") or {}
    reference_month = period.get("reference_month")
    if isinstance(reference_month, str) and reference_month.strip():
        return reference_month.strip()
    budget = financial_context.get("budget") or {}
    period_key = budget.get("period_key")
    if isinstance(period_key, str) and period_key.strip():
        return period_key.strip()
    return "unknown"


def generate_dashboard_insights(
    financial_context: dict[str, Any],
    *,
    strip_title: str = "What to watch",
) -> list[GeneratedInsight]:
    if not financial_context:
        return []

    period_key = _period_key(financial_context)
    cash_flow = financial_context.get("cash_flow") or {}
    income = _money(cash_flow.get("income_this_month"))
    spent = _money(cash_flow.get("spent_this_month"))
    available = _money(cash_flow.get("available_this_month"))

    items: list[GeneratedInsight] = []

    if income > 0 or spent > 0:
        if available < 0:
            body = f"Spending exceeds income by {_format_money(-available)} this month."
            detail_key = "negative"
        elif available > 0:
            body = f"Net cash flow is {_format_money(available)} ahead this month."
            detail_key = "positive"
        else:
            body = "Income and spending are balanced this month."
            detail_key = "balanced"
        items.append(
            GeneratedInsight(
                fingerprint=build_insight_fingerprint(
                    source=DASHBOARD_SOURCE,
                    insight_type="net_cash_flow",
                    period_key=period_key,
                    detail_key=detail_key,
                ),
                source=DASHBOARD_SOURCE,
                insight_type="net_cash_flow",
                title=strip_title,
                body=body,
                period_key=period_key,
                anchor_key="monthly_cash_flow",
            )
        )

    leak = _top_mom_leak(financial_context.get("biggest_month_over_month_increases") or [])
    if leak is not None:
        category = str(leak.get("category") or "Category")
        spent_this_month = _money(leak.get("spent_this_month"))
        percent_change = leak.get("percent_change")
        if spent_this_month <= 0:
            leak = None
        elif percent_change is None:
            body = (
                f"{category} is new spending pressure at "
                f"{_format_money(spent_this_month)} this month."
            )
        else:
            pct = _money(percent_change)
            if pct <= 0:
                leak = None
            else:
                body = (
                    f"{category} rose {_format_percent(pct / 100 if pct > 1 else pct)} "
                    f"month-over-month ({_format_money(spent_this_month)})."
                )
        if leak is not None:
            items.append(
                GeneratedInsight(
                    fingerprint=build_insight_fingerprint(
                        source=DASHBOARD_SOURCE,
                        insight_type="mom_leak",
                        period_key=period_key,
                        detail_key=category.lower(),
                    ),
                    source=DASHBOARD_SOURCE,
                    insight_type="mom_leak",
                    title=strip_title,
                    body=body,
                    period_key=period_key,
                    anchor_key="spending_pressure",
                    payload_json={"category": category},
                )
            )

    budget = financial_context.get("budget") or {}
    overspend_categories = budget.get("top_overspending_categories") or []
    top = overspend_categories[0] if overspend_categories else None
    if isinstance(top, dict):
        overspent = _money(top.get("overspent"))
        category = str(top.get("category") or "Category")
        if overspent > 0:
            items.append(
                GeneratedInsight(
                    fingerprint=build_insight_fingerprint(
                        source=DASHBOARD_SOURCE,
                        insight_type="budget_overspend",
                        period_key=period_key,
                        detail_key=category.lower(),
                    ),
                    source=DASHBOARD_SOURCE,
                    insight_type="budget_overspend",
                    title=strip_title,
                    body=(
                        f"{category} is over budget by {_format_money(overspent)}."
                    ),
                    period_key=period_key,
                    anchor_key="budget_performance",
                    payload_json={"category": category},
                )
            )

    return items[:3]


def generate_accountability_insights(
    signals: list[dict[str, Any]],
    *,
    period_key: str,
) -> list[GeneratedInsight]:
    items: list[GeneratedInsight] = []
    for signal in signals:
        if not isinstance(signal, dict):
            continue
        if signal.get("status") not in (None, "active"):
            continue
        title = str(signal.get("title") or "Needs attention").strip()
        summary = str(signal.get("summary") or signal.get("reason") or title).strip()
        signal_type = str(signal.get("signal_type") or "accountability_signal")
        signal_id = str(signal.get("id") or title).strip()
        items.append(
            GeneratedInsight(
                fingerprint=build_insight_fingerprint(
                    source=ACCOUNTABILITY_SOURCE,
                    insight_type="accountability_signal",
                    period_key=period_key,
                    detail_key=f"{signal_type}:{signal_id}",
                ),
                source=ACCOUNTABILITY_SOURCE,
                insight_type="accountability_signal",
                title=title,
                body=summary,
                period_key=period_key,
                payload_json={"signal_type": signal_type, "signal_id": signal_id},
            )
        )
    return items


def _top_mom_leak(leaks: list[Any]) -> Optional[dict[str, Any]]:
    best: Optional[dict[str, Any]] = None
    best_score = float("-inf")
    for leak in leaks:
        if not isinstance(leak, dict):
            continue
        spent_this_month = _money(leak.get("spent_this_month"))
        if spent_this_month <= 0:
            continue
        percent_change = leak.get("percent_change")
        if percent_change is None:
            score = float("inf")
        else:
            pct = _money(percent_change)
            score = pct / 100 if pct > 1 else pct
            if score <= 0:
                continue
        if best is None or score > best_score:
            best = leak
            best_score = score
    return best
