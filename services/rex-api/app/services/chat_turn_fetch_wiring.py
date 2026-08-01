"""Assemble the fetch sources a turn can draw on (plan 05 §5).

Kept out of the orchestrator so adding a capability means editing a list here,
not growing the turn loop.
"""

from __future__ import annotations

from typing import Optional

from app.services.capabilities.recall_capability import build_recall_fetch_source
from app.services.chat_financial_guard import ChatFinancialGuard
from app.services.chat_turn_fetch import FetchRunner, build_fetch_runner
from app.services.chat_turn_finance_fetch import build_finance_fetch_source


def build_turn_fetch_runner(
    *,
    grok_turn_brain,
    financial_guard: ChatFinancialGuard,
    financial_context: Optional[dict],
    recall_service,
    overview_service,
    usage_recorder,
    channel,
    max_tokens: int,
    conversation_id: str,
    user_message: str,
) -> FetchRunner:
    return build_fetch_runner(
        sources=(
            build_finance_fetch_source(
                financial_guard=financial_guard,
                financial_context=financial_context,
            ),
            build_recall_fetch_source(
                recall_service=recall_service,
                overview_service=overview_service,
                conversation_id=conversation_id,
                user_message=user_message,
            ),
        ),
        grok_turn_brain=grok_turn_brain,
        usage_recorder=usage_recorder,
        channel=channel,
        max_tokens=max_tokens,
    )
