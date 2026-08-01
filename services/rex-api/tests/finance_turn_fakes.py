"""Shared fakes for Phase F finance turns (fetch packs + clarity proposals)."""

from __future__ import annotations

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.chat_financial_guard import ChatFinancialGuard
from app.services.chat_turn_finance_fetch import build_finance_fetch_source
from turn_fetch_fakes import (
    FakeGrokBrain,
    FakeUsageRecorder,
    NoPendingStore,
    finalize_turn,
    rex_action,
)

__all__ = [
    "FakeGrokBrain",
    "FakeUsageRecorder",
    "NoPendingStore",
    "clarity_proposals",
    "financial_context",
    "finalize_finance_turn",
    "rex_action",
]


def financial_context(**overrides) -> dict:
    context = {
        "schema": "clarity_unified_financial_context_v1",
        "generated_at": "2026-07-30T12:00:00Z",
        "data_status": {
            "state": "ready",
            "financial_context_complete": True,
            "load_errors": [],
        },
        "load_errors": [],
        "freshness": {"state": "fresh"},
        "integration": {"full_financial_context_included": True},
        "period": {
            "reference_month": "2026-07",
            "transaction_count": 24,
            "included_transaction_count": 24,
            "first_transaction_date": "2026-07-01",
            "last_transaction_date": "2026-07-29",
        },
        "cash_flow": {
            "total_balance": 4210.55,
            "spent_this_month": 1830.42,
            "income_this_month": 3200.0,
            "available_this_month": 1369.58,
        },
        "accounts": [
            {
                "id": "acct-1",
                "name": "Everyday Checking",
                "display_name": "Everyday Checking",
                "type": "depository",
                "institution": "Chase",
                "mask": "1234",
                "current_balance": 2210.55,
                "sync_status": "healthy",
            },
            {
                "id": "acct-2",
                "name": "Travel Card",
                "display_name": "Travel Card",
                "type": "credit",
                "institution": "Amex",
                "current_balance": -320.10,
            },
        ],
        "categories": [
            {"id": "cat-coffee", "name": "Coffee", "type": "expense"},
            {"id": "cat-grocery", "name": "Groceries", "type": "expense"},
        ],
        "budgets": [
            {
                "id": "budget-1",
                "name": "Groceries",
                "category_id": "cat-grocery",
                "amount": 400.0,
                "period": "monthly",
            }
        ],
        "budget": {
            "period_type": "monthly",
            "period_key": "2026-07",
            "total_budgeted": 900.0,
            "total_spent": 640.25,
            "total_remaining": 259.75,
            "total_overspent": 0.0,
        },
        "category_spend_this_month": [
            {
                "category": "Coffee",
                "spent": 42.5,
                "transaction_count": 7,
                "top_merchants": [{"merchant": "Starbucks"}],
            },
            {"category": "Groceries", "spent": 320.1, "transaction_count": 9},
        ],
        "transactions": [
            {
                "id": "tx-1",
                "date": "2026-07-28",
                "account_id": "acct-1",
                "merchant": "Starbucks",
                "amount": 6.25,
                "category_name": "Uncategorized",
            },
            {
                "id": "tx-2",
                "date": "2026-07-21",
                "account_id": "acct-1",
                "merchant": "Starbucks",
                "amount": 5.50,
                "category_name": "Uncategorized",
            },
            {
                "id": "tx-3",
                "date": "2026-07-20",
                "account_id": "acct-2",
                "merchant": "Whole Foods",
                "amount": 82.13,
                "category_name": "Groceries",
            },
        ],
    }
    context.update(overrides)
    return context


async def finalize_finance_turn(
    rex_response: str,
    *,
    settings: AssistantProposalSettings,
    context: dict | None = None,
    user_text: str = "How much did I spend on coffee?",
    brain: FakeGrokBrain | None = None,
) -> dict:
    return await finalize_turn(
        rex_response,
        settings=settings,
        sources=(
            build_finance_fetch_source(
                financial_guard=ChatFinancialGuard(),
                financial_context=context,
            ),
        ),
        user_text=user_text,
        brain=brain,
        financial_context=context,
    )


def clarity_proposals(finalized: dict) -> list[dict]:
    changes = finalized.get("memory_changes") or {}
    return changes.get("clarity_action_proposals") or []
