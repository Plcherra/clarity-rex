"""Second Grok pass grounded in a capped finance pack (plan 05 §5 fetch)."""

from __future__ import annotations

import logging
import time
from typing import Awaitable, Callable, Iterable, Optional

from app.services.brain_action_schema import BrainAction, parse_brain_actions
from app.services.capabilities.finance_capability import finance_fetch_requests
from app.services.capabilities.finance_capability_fetch import (
    build_finance_fetch_pack,
)
from app.services.chat_financial_guard import (
    FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE,
    ChatFinancialGuard,
)

LOGGER = logging.getLogger("clarity.finance_fetch")

FinanceFetchRunner = Callable[
    [Iterable[BrainAction], list[dict]],
    Awaitable[Optional[str]],
]

_MAX_FETCHES_PER_TURN = 2
_GROUNDING_RULES = (
    "Answer using only the fetched Clarity data above. If a number the user "
    "asked for is not in it, say what Clarity does not have instead of "
    "estimating. Prefer a rounded range over invented precision, and do not "
    "claim any financial record was created, changed, or deleted."
)


def build_finance_fetch_runner(
    *,
    grok_turn_brain,
    financial_guard: ChatFinancialGuard,
    financial_context: Optional[dict],
    usage_recorder,
    channel,
    max_tokens: int,
) -> FinanceFetchRunner:
    async def runner(
        actions: Iterable[BrainAction],
        ai_messages: list[dict],
    ) -> Optional[str]:
        return await run_finance_fetch(
            actions,
            ai_messages=ai_messages,
            financial_context=financial_context,
            financial_guard=financial_guard,
            grok_turn_brain=grok_turn_brain,
            usage_recorder=usage_recorder,
            channel=channel,
            max_tokens=max_tokens,
        )

    return runner


async def run_finance_fetch(
    actions: Iterable[BrainAction],
    *,
    ai_messages: list[dict],
    financial_context: Optional[dict],
    financial_guard: ChatFinancialGuard,
    grok_turn_brain,
    usage_recorder,
    channel,
    max_tokens: int,
) -> Optional[str]:
    """Return a grounded reply when Grok asked for finance data, else None."""
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
        return FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE

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
        return FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE

    messages = [*ai_messages, {"role": "system", "content": _fetch_prompt(packs)}]
    started_at = time.perf_counter()
    try:
        result = await grok_turn_brain.generate(messages, max_tokens=max_tokens)
    except Exception as error:
        await usage_recorder.record_llm_usage(
            channel=channel,
            ai_kwargs={"max_tokens": max_tokens},
            latency_ms=usage_recorder.elapsed_ms(started_at),
            status="failure",
            error_class=error.__class__.__name__,
        )
        raise
    await usage_recorder.record_llm_usage(
        channel=channel,
        ai_kwargs={"max_tokens": max_tokens},
        latency_ms=usage_recorder.elapsed_ms(started_at),
        usage=getattr(result, "usage", None),
    )
    # Fences in the grounded pass are dropped: the fetch answer is text only.
    reply = parse_brain_actions(getattr(result, "text", "") or "").reply_text
    return reply or None


def _fetch_prompt(packs: list[str]) -> str:
    body = "\n\n".join(packs)
    return (
        "Clarity finance data fetched this turn (the only source for numbers):\n"
        f"{body}\n\n{_GROUNDING_RULES}"
    )
