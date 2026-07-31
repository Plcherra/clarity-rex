"""Parse finance fetch / mutate payloads from Grok actions (plan 05 Phase F)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from app.services.brain_action_schema import BrainAction

FINANCE_FETCH_ACTIONS = frozenset({"fetch_spend_insight", "fetch_account_summary"})
FINANCE_MUTATE_ACTIONS = frozenset(
    {
        "categorize_transaction",
        "bulk_categorize",
        "create_category",
        "update_category",
        "delete_category",
        "create_budget",
        "update_budget",
        "delete_budget",
    }
)

CATEGORY_TYPES = frozenset({"expense", "income"})
BUDGET_PERIODS = frozenset({"monthly", "weekly", "custom"})


@dataclass(frozen=True)
class FinanceFetchRequest:
    name: str
    category: Optional[str] = None
    merchant: Optional[str] = None
    account_reference: Optional[str] = None
    period: Optional[str] = None

    @property
    def is_account_summary(self) -> bool:
        return self.name == "fetch_account_summary"


@dataclass(frozen=True)
class CategorizeFields:
    transaction_ids: tuple[str, ...]
    merchant: Optional[str]
    category_id: Optional[str]
    category_name: Optional[str]
    force_bulk: bool


@dataclass(frozen=True)
class CategoryFields:
    category_id: Optional[str]
    reference: Optional[str]
    name: Optional[str]
    category_type: Optional[str]
    color: Optional[str]
    icon: Optional[str]


@dataclass(frozen=True)
class BudgetFields:
    budget_id: Optional[str]
    reference: Optional[str]
    name: Optional[str]
    amount: Optional[float]
    period: Optional[str]
    category_id: Optional[str]
    category_name: Optional[str]
    start_date: Optional[str]


def fetch_request_from_action(action: BrainAction) -> Optional[FinanceFetchRequest]:
    if action.name not in FINANCE_FETCH_ACTIONS:
        return None
    payload = action.payload if isinstance(action.payload, dict) else {}
    return FinanceFetchRequest(
        name=action.name,
        category=_optional_str(
            payload.get("category")
            or payload.get("category_name")
            or payload.get("topic")
        ),
        merchant=_optional_str(
            payload.get("merchant")
            or payload.get("merchant_name")
            or payload.get("query")
        ),
        account_reference=_optional_str(
            payload.get("account_id")
            or payload.get("account")
            or payload.get("account_name")
        ),
        period=_optional_str(
            payload.get("period")
            or payload.get("month")
            or payload.get("timeframe")
        ),
    )


def categorize_fields_from_payload(
    payload: dict[str, Any],
    *,
    force_bulk: bool,
) -> Optional[CategorizeFields]:
    ids = _string_list(
        payload.get("transaction_ids"),
        payload.get("ids"),
        payload.get("transaction_id"),
        payload.get("id"),
    )
    merchant = _optional_str(
        payload.get("merchant")
        or payload.get("merchant_name")
        or payload.get("description")
        or payload.get("reference")
    )
    category_id = _optional_str(payload.get("category_id"))
    category_name = _optional_str(
        payload.get("category")
        or payload.get("category_name")
        or payload.get("new_category")
        or payload.get("to_category")
    )
    if not ids and not merchant:
        return None
    if not category_id and not category_name:
        return None
    return CategorizeFields(
        transaction_ids=ids,
        merchant=merchant,
        category_id=category_id,
        category_name=category_name,
        force_bulk=force_bulk,
    )


def category_fields_from_payload(payload: dict[str, Any]) -> Optional[CategoryFields]:
    category_id = _optional_str(payload.get("category_id") or payload.get("id"))
    reference = _optional_str(
        payload.get("reference")
        or payload.get("existing_name")
        or payload.get("existing_title")
        or payload.get("target_name")
        or payload.get("category")
        or payload.get("category_name")
    )
    name = _optional_str(payload.get("new_name") or payload.get("name"))
    raw_type = _optional_str(payload.get("type") or payload.get("category_type"))
    category_type = raw_type.lower() if raw_type and raw_type.lower() in CATEGORY_TYPES else None
    if not category_id and not reference and not name:
        return None
    return CategoryFields(
        category_id=category_id,
        reference=reference,
        name=name,
        category_type=category_type,
        color=_optional_str(payload.get("color")),
        icon=_optional_str(payload.get("icon")),
    )


def budget_fields_from_payload(payload: dict[str, Any]) -> Optional[BudgetFields]:
    budget_id = _optional_str(payload.get("budget_id") or payload.get("id"))
    reference = _optional_str(
        payload.get("reference")
        or payload.get("existing_name")
        or payload.get("budget")
        or payload.get("budget_name")
        or payload.get("target_name")
    )
    name = _optional_str(payload.get("new_name") or payload.get("name"))
    raw_period = _optional_str(payload.get("period") or payload.get("period_type"))
    period = raw_period.lower() if raw_period and raw_period.lower() in BUDGET_PERIODS else None
    category_name = _optional_str(
        payload.get("category") or payload.get("category_name")
    )
    if not budget_id and not reference and not name and not category_name:
        return None
    return BudgetFields(
        budget_id=budget_id,
        reference=reference,
        name=name,
        amount=_optional_amount(payload.get("amount") or payload.get("limit")),
        period=period,
        category_id=_optional_str(payload.get("category_id")),
        category_name=category_name,
        start_date=_optional_str(payload.get("start_date")),
    )


def _optional_str(value: Any) -> Optional[str]:
    if isinstance(value, (list, tuple, dict)):
        return None
    text = str(value or "").strip()
    return text or None


def _optional_amount(value: Any) -> Optional[float]:
    if value is None or isinstance(value, (list, tuple, dict, bool)):
        return None
    text = str(value).strip().replace("$", "").replace(",", "")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _string_list(*values: Any) -> tuple[str, ...]:
    collected: list[str] = []
    for value in values:
        if isinstance(value, (list, tuple)):
            candidates = list(value)
        else:
            candidates = [value]
        for candidate in candidates:
            text = _optional_str(candidate)
            if text and text not in collected:
                collected.append(text)
    return tuple(collected)
