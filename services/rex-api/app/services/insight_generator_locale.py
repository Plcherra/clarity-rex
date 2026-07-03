"""Localized copy for deterministic insight generation."""

from __future__ import annotations


def insight_strip_title(locale: str | None) -> str:
    if _is_spanish(locale):
        return "Qué vigilar"
    return "What to watch"


def net_cash_flow_body(
    *,
    locale: str | None,
    available: float,
    format_money,
) -> tuple[str, str]:
    if available < 0:
        if _is_spanish(locale):
            return (
                "negative",
                f"El gasto supera los ingresos en {format_money(-available)} este mes.",
            )
        return (
            "negative",
            f"Spending exceeds income by {format_money(-available)} this month.",
        )
    if available > 0:
        if _is_spanish(locale):
            return (
                "positive",
                f"El flujo de caja neto va {format_money(available)} por delante este mes.",
            )
        return (
            "positive",
            f"Net cash flow is {format_money(available)} ahead this month.",
        )
    if _is_spanish(locale):
        return ("balanced", "Los ingresos y el gasto están equilibrados este mes.")
    return ("balanced", "Income and spending are balanced this month.")


def mom_leak_new_body(
    *,
    locale: str | None,
    category: str,
    spent: str,
) -> str:
    if _is_spanish(locale):
        return f"{category} es una nueva presión de gasto de {spent} este mes."
    return f"{category} is new spending pressure at {spent} this month."


def mom_leak_up_body(
    *,
    locale: str | None,
    category: str,
    percent: str,
    spent: str,
) -> str:
    if _is_spanish(locale):
        return (
            f"{category} subió {percent} mes a mes ({spent})."
        )
    return f"{category} rose {percent} month-over-month ({spent})."


def budget_overspend_body(
    *,
    locale: str | None,
    category: str,
    overspent: str,
) -> str:
    if _is_spanish(locale):
        return f"{category} supera el presupuesto en {overspent}."
    return f"{category} is over budget by {overspent}."


def accountability_default_title(locale: str | None) -> str:
    if _is_spanish(locale):
        return "Requiere atención"
    return "Needs attention"


def _is_spanish(locale: str | None) -> bool:
    return isinstance(locale, str) and locale.lower().startswith("es")
