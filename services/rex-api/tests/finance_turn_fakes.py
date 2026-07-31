"""Shared fakes for Phase F finance turns (fetch packs + clarity proposals)."""

from __future__ import annotations

import json
from types import SimpleNamespace

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.chat_financial_guard import ChatFinancialGuard
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_finalize import finalize_grok_turn
from app.services.chat_turn_finance_fetch import build_finance_fetch_runner
from app.services.clarity_action_parser import ClarityActionParser
from app.services.durable_write_service import DurableWriteService


class NoPendingStore:
    """Minimal store so finalize can run Truth without durable writes."""

    def __init__(self) -> None:
        self.user_id = "user-1"
        self.access_token = "token"
        self.pending: dict = {}
        self.messages: list[dict] = []

    async def get_conversation_pending_action(self, conversation_id: str):
        return self.pending.get(conversation_id)

    async def set_conversation_pending_action(
        self,
        conversation_id: str,
        pending_action,
    ) -> None:
        if pending_action is None:
            self.pending.pop(conversation_id, None)
        else:
            self.pending[conversation_id] = pending_action

    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        message = {
            "id": f"msg-{len(self.messages) + 1}",
            "conversation_id": conversation_id,
            "role": role,
            "content": content,
        }
        self.messages.append(message)
        return message

    async def get_recent_messages(self, conversation_id: str, limit: int = 20) -> list:
        _ = conversation_id
        return list(self.messages)[-limit:]

    async def _list_records(self, table: str, **kwargs) -> list[dict]:
        _ = table, kwargs
        return []


class FakeGrokBrain:
    def __init__(self, text: str = "Grounded answer.") -> None:
        self.text = text
        self.calls: list[list[dict]] = []

    async def generate(self, messages, *, max_tokens=None):
        _ = max_tokens
        self.calls.append(list(messages))
        return SimpleNamespace(text=self.text, usage=None)

    @property
    def last_fetch_pack(self) -> str:
        return self.calls[-1][-1]["content"]


class FakeUsageRecorder:
    def __init__(self) -> None:
        self.records: list[dict] = []

    async def record_llm_usage(self, **kwargs) -> None:
        self.records.append(kwargs)

    def elapsed_ms(self, started_at: float) -> int:
        _ = started_at
        return 1


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


def rex_action(
    action: str,
    payload: dict,
    *,
    explicit: bool = False,
    auto: bool = False,
) -> str:
    body: dict = {"action": action, "payload": payload}
    if explicit:
        body["explicit"] = True
    if auto:
        body["auto"] = True
    return "```rex_action\n" + json.dumps(body) + "\n```"


async def finalize_finance_turn(
    rex_response: str,
    *,
    settings: AssistantProposalSettings,
    context: dict | None = None,
    user_text: str = "How much did I spend on coffee?",
    brain: FakeGrokBrain | None = None,
) -> dict:
    runner = build_finance_fetch_runner(
        grok_turn_brain=brain or FakeGrokBrain(),
        financial_guard=ChatFinancialGuard(),
        financial_context=context,
        usage_recorder=FakeUsageRecorder(),
        channel=SimpleNamespace(value="chat"),
        max_tokens=1200,
    )
    return await finalize_grok_turn(
        rex_response,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=DurableWriteService(memory_service=NoPendingStore()),
        proposal_settings=settings,
        brain_message=user_text,
        user_message={"id": "u1", "content": user_text},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[{"role": "system", "content": "tiny"}],
        financial_context=context,
        finance_fetch_runner=runner,
    )


def clarity_proposals(finalized: dict) -> list[dict]:
    changes = finalized.get("memory_changes") or {}
    return changes.get("clarity_action_proposals") or []
