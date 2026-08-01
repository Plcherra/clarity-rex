"""Capped finance packs for the grounded pass (plan 05 §5 fetch).

The second Grok call lives in `chat_turn_fetch`; this module only decides
whether the app-provided finance data is quotable and turns it into text.
"""

from __future__ import annotations

import logging
from typing import Iterable, Optional

from app.services.brain_action_schema import BrainAction
from app.services.capabilities.finance_capability import finance_fetch_requests
from app.services.capabilities.finance_capability_fetch import (
    build_finance_fetch_pack,
)
from app.services.chat_financial_guard import (
    FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE,
    ChatFinancialGuard,
)
from app.services.chat_turn_fetch import FetchPacks, FetchSource

LOGGER = logging.getLogger("clarity.finance_fetch")

_MAX_FETCHES_PER_TURN = 2


def build_finance_fetch_source(
    *,
    financial_guard: ChatFinancialGuard,
    financial_context: Optional[dict],
) -> FetchSource:
    async def source(actions: Iterable[BrainAction]) -> Optional[FetchPacks]:
        return finance_fetch_packs(
            actions,
            financial_context=financial_context,
            financial_guard=financial_guard,
        )

    return source


def finance_fetch_packs(
    actions: Iterable[BrainAction],
    *,
    financial_context: Optional[dict],
    financial_guard: ChatFinancialGuard,
) -> Optional[FetchPacks]:
    """Finance text for the grounded pass, or the honest gap. None = not asked."""
    requests = finance_fetch_requests(actions)
    if not requests:
        return None

    unreliable_reason = financial_guard.unreliable_reason(financial_context)
    if unreliable_reason is not None:
        LOGGER.warning(
            "finance_fetch_unavailable actions=%s reason=%s",
            ",".join(request.name for request in requests),
            unreliable_reason,
        )
        return FetchPacks(unavailable_reply=FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE)

    packs = [
        pack
        for pack in (
            build_finance_fetch_pack(request, financial_context)
            for request in requests[:_MAX_FETCHES_PER_TURN]
        )
        if pack
    ]
    if not packs:
        LOGGER.warning("finance_fetch_unavailable reason=empty_pack")
        return FetchPacks(unavailable_reply=FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE)
    return FetchPacks(packs=tuple(packs))
