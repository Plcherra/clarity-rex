"""Finance mutate proposals (clarity actions), not durable writes.

Grok names an app-level capability (`categorize_transaction`, budget/category
CRUD); this module turns it into a `ClarityControlService` action the user can
confirm from the cards strip. Nothing is applied here — `/clarity/actions`
applies only after the user confirms.
"""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_OFF,
    AssistantProposalSettings,
)
from app.services.brain_action_schema import BrainAction
from app.services.capabilities.finance_action_payload import (
    BudgetFields,
    CategorizeFields,
    CategoryFields,
    budget_fields_from_payload,
    categorize_fields_from_payload,
    category_fields_from_payload,
)
from app.services.capabilities.finance_context_lookup import (
    find_budget,
    find_category,
    matching_transactions,
    transaction_ids,
    value_or_none,
)

DEFAULT_CATEGORY_TYPE = "expense"
DEFAULT_BUDGET_PERIOD = "monthly"

_RISK_BY_ACTION = {
    "update_transaction": "low",
    "bulk_update_transaction_category": "medium",
    "create_category": "low",
    "update_category": "medium",
    "delete_category": "high",
    "create_budget": "medium",
    "update_budget": "medium",
    "delete_budget": "high",
}


def finance_mutate_allowed(
    action: BrainAction,
    settings: AssistantProposalSettings,
) -> bool:
    """Off mode surfaces finance changes only on explicit user commands."""
    if settings.mode != AUTO_PROPOSALS_OFF:
        return True
    return action.explicit


def clarity_proposal_for_action(
    action: BrainAction,
    *,
    financial_context: Optional[dict],
) -> Optional[dict]:
    payload = action.payload if isinstance(action.payload, dict) else {}
    if action.name in {"categorize_transaction", "bulk_categorize"}:
        fields = categorize_fields_from_payload(
            payload,
            force_bulk=action.name == "bulk_categorize",
        )
        return None if fields is None else _categorize(fields, financial_context)
    if action.name in {"create_category", "update_category", "delete_category"}:
        fields = category_fields_from_payload(payload)
        if fields is None:
            return None
        if action.name == "create_category":
            return _create_category(fields)
        if action.name == "update_category":
            return _update_category(fields, financial_context)
        return _delete_category(fields, financial_context)
    if action.name in {"create_budget", "update_budget", "delete_budget"}:
        fields = budget_fields_from_payload(payload)
        if fields is None:
            return None
        if action.name == "create_budget":
            return _create_budget(fields, financial_context)
        if action.name == "update_budget":
            return _update_budget(fields, financial_context)
        return _delete_budget(fields, financial_context)
    return None


def _categorize(
    fields: CategorizeFields,
    financial_context: Optional[dict],
) -> Optional[dict]:
    ids = list(fields.transaction_ids)
    if not ids and fields.merchant:
        ids = transaction_ids(
            matching_transactions(financial_context, merchant=fields.merchant)
        )
    if not ids:
        return None
    category = find_category(financial_context, fields.category_name)
    category_id = fields.category_id or value_or_none(
        (category or {}).get("id")
    )
    if not category_id:
        return None
    label = (
        value_or_none((category or {}).get("name"))
        or fields.category_name
        or category_id
    )
    scope = f" matching {fields.merchant}" if fields.merchant else ""
    if fields.force_bulk or len(ids) > 1:
        return _proposal(
            "bulk_update_transaction_category",
            {"ids": ids, "category_id": category_id},
            f"Move {len(ids)} transactions{scope} to {label}?",
        )
    return _proposal(
        "update_transaction",
        {"id": ids[0], "category_id": category_id},
        f"Move 1 transaction{scope} to {label}?",
    )


def _create_category(fields: CategoryFields) -> Optional[dict]:
    name = fields.name or fields.reference
    if not name:
        return None
    category_type = fields.category_type or DEFAULT_CATEGORY_TYPE
    payload: dict[str, Any] = {"name": name, "type": category_type}
    _set_optional(payload, color=fields.color, icon=fields.icon)
    return _proposal(
        "create_category",
        payload,
        f"Create the {name} {category_type} category?",
    )


def _update_category(
    fields: CategoryFields,
    financial_context: Optional[dict],
) -> Optional[dict]:
    existing = find_category(financial_context, fields.reference or fields.name)
    category_id = fields.category_id or value_or_none((existing or {}).get("id"))
    if not category_id:
        return None
    existing_name = value_or_none((existing or {}).get("name"))
    payload: dict[str, Any] = {"id": category_id}
    if fields.name and fields.name != existing_name:
        payload["name"] = fields.name
    _set_optional(
        payload,
        type=fields.category_type,
        color=fields.color,
        icon=fields.icon,
    )
    if len(payload) == 1:
        return None
    label = existing_name or fields.reference or category_id
    return _proposal(
        "update_category",
        payload,
        f"Update the {label} category?",
    )


def _delete_category(
    fields: CategoryFields,
    financial_context: Optional[dict],
) -> Optional[dict]:
    existing = find_category(financial_context, fields.reference or fields.name)
    category_id = fields.category_id or value_or_none((existing or {}).get("id"))
    if not category_id:
        return None
    label = (
        value_or_none((existing or {}).get("name"))
        or fields.reference
        or fields.name
        or category_id
    )
    return _proposal(
        "delete_category",
        {"id": category_id},
        f"Delete the {label} category?",
    )


def _create_budget(
    fields: BudgetFields,
    financial_context: Optional[dict],
) -> Optional[dict]:
    name = fields.name or fields.reference or fields.category_name
    if not name or fields.amount is None:
        return None
    period = fields.period or DEFAULT_BUDGET_PERIOD
    payload: dict[str, Any] = {
        "name": name,
        "amount": fields.amount,
        "period": period,
    }
    category = find_category(financial_context, fields.category_name or name)
    category_id = fields.category_id or value_or_none((category or {}).get("id"))
    _set_optional(payload, category_id=category_id, start_date=fields.start_date)
    return _proposal(
        "create_budget",
        payload,
        f"Create a {period} {name} budget of {fields.amount:g}?",
    )


def _update_budget(
    fields: BudgetFields,
    financial_context: Optional[dict],
) -> Optional[dict]:
    existing = find_budget(
        financial_context,
        fields.reference or fields.name,
        category_name=fields.category_name,
    )
    budget_id = fields.budget_id or value_or_none((existing or {}).get("id"))
    if not budget_id:
        return None
    existing_name = value_or_none((existing or {}).get("name"))
    payload: dict[str, Any] = {"id": budget_id}
    if fields.name and fields.name != existing_name:
        payload["name"] = fields.name
    category = find_category(financial_context, fields.category_name)
    _set_optional(
        payload,
        amount=fields.amount,
        period=fields.period,
        category_id=fields.category_id or value_or_none((category or {}).get("id")),
        start_date=fields.start_date,
    )
    if len(payload) == 1:
        return None
    label = existing_name or fields.reference or fields.name or budget_id
    amount_text = (
        f" to {fields.amount:g}" if fields.amount is not None else ""
    )
    return _proposal(
        "update_budget",
        payload,
        f"Update the {label} budget{amount_text}?",
    )


def _delete_budget(
    fields: BudgetFields,
    financial_context: Optional[dict],
) -> Optional[dict]:
    existing = find_budget(
        financial_context,
        fields.reference or fields.name,
        category_name=fields.category_name,
    )
    budget_id = fields.budget_id or value_or_none((existing or {}).get("id"))
    if not budget_id:
        return None
    label = (
        value_or_none((existing or {}).get("name"))
        or fields.reference
        or fields.name
        or budget_id
    )
    return _proposal(
        "delete_budget",
        {"id": budget_id},
        f"Delete the {label} budget?",
    )


def _proposal(action: str, payload: dict[str, Any], confirmation: str) -> dict:
    return {
        "action": action,
        "payload": payload,
        "confirmation_text": confirmation,
        "risk_level": _RISK_BY_ACTION.get(action, "medium"),
    }


def _set_optional(payload: dict[str, Any], **values: Any) -> None:
    for key, value in values.items():
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        payload[key] = value
