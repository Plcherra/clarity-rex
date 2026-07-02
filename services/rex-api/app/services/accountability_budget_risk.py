from typing import Any, Optional

from app.models.accountability import AccountabilitySignal, AccountabilitySourceRef


def detect_budget_risk_signals(
    budget_performance: Optional[dict[str, Any]],
) -> list[AccountabilitySignal]:
    if not isinstance(budget_performance, dict) or not budget_performance:
        return []

    overspending_rows = overspending_categories(budget_performance)
    if not overspending_rows:
        return []

    period_key = str(budget_performance.get("period_key") or "").strip()
    signals = []
    for row in overspending_rows:
        category = str(row.get("category") or "Category").strip()
        budgeted = _money(row.get("budgeted"))
        spent = _money(row.get("spent"))
        overspent = _money(row.get("overspent"))
        if overspent <= 0 or budgeted <= 0:
            continue

        severity = _severity_for_overspend(budgeted=budgeted, overspent=overspent)
        signals.append(
            AccountabilitySignal(
                signal_type="budget_risk",
                title=f"Over budget: {category}",
                summary=(
                    f"{category} is over budget by ${overspent:.2f} "
                    f"(${spent:.2f} spent of ${budgeted:.2f})."
                ),
                reason=(
                    "Category spending exceeds the active budget for the current period."
                ),
                severity=severity,
                confidence=0.95,
                source_refs=[
                    AccountabilitySourceRef(
                        source_type="system",
                        title=category,
                        excerpt=(
                            f"Budgeted ${budgeted:.2f}, spent ${spent:.2f}, "
                            f"overspent ${overspent:.2f}."
                        ),
                        metadata={
                            "category": category,
                            "period_key": period_key,
                        },
                    )
                ],
                suggested_prompt=(
                    f"{category} is ${overspent:.2f} over budget this period. "
                    "What should we adjust?"
                ),
                recommended_action=(
                    "Review recent spending in this category and confirm whether "
                    "the budget still fits."
                ),
                metadata={
                    "category": category,
                    "budgeted": budgeted,
                    "spent": spent,
                    "overspent": overspent,
                    "period_key": period_key,
                    "period_type": budget_performance.get("period_type"),
                },
            )
        )
    return signals


def overspending_categories(budget_performance: dict[str, Any]) -> list[dict[str, Any]]:
    top_rows = budget_performance.get("top_overspending_categories")
    if isinstance(top_rows, list) and top_rows:
        return [row for row in top_rows if isinstance(row, dict)]

    categories = budget_performance.get("categories")
    if not isinstance(categories, list):
        return []

    overspending = [
        row
        for row in categories
        if isinstance(row, dict) and _money(row.get("overspent")) > 0
    ]
    overspending.sort(key=lambda row: _money(row.get("overspent")), reverse=True)
    return overspending[:3]


def _severity_for_overspend(*, budgeted: float, overspent: float) -> str:
    ratio = overspent / budgeted if budgeted > 0 else 0
    if overspent >= 50 or ratio >= 0.25:
        return "high"
    if overspent >= 10 or ratio >= 0.1:
        return "medium"
    return "low"


def _money(value: Any) -> float:
    if isinstance(value, bool):
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value.strip())
        except ValueError:
            return 0.0
    return 0.0


def financial_budget_performance(
    financial_context: Optional[dict[str, Any]],
) -> Optional[dict[str, Any]]:
    if not isinstance(financial_context, dict):
        return None
    budget = financial_context.get("budget")
    return budget if isinstance(budget, dict) else None
