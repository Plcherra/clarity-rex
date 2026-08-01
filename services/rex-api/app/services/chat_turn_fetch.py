"""One grounded second pass for whatever the brain asked to fetch (plan 05 §5).

Finance and recall both work the same way — the brain names what it needs, the
body reads it, and a second call answers from that text alone. They share this
runner so a turn that wants a number and an old chat still costs one extra call,
not one per capability.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Awaitable, Callable, Iterable, Optional

from app.services.brain_action_schema import BrainAction, parse_brain_actions

LOGGER = logging.getLogger("clarity.turn_fetch")


@dataclass(frozen=True)
class FetchPacks:
    """What one capability found, plus what Truth needs to know about it.

    `unavailable_reply` is the honest copy for a fetch the body could not run.
    It only becomes the whole answer when nothing else was fetched; alongside
    real packs it rides along as a line so the gap is stated, not swallowed.
    """

    packs: tuple[str, ...] = ()
    unavailable_reply: Optional[str] = None
    chat_history_included: bool = False
    source_statuses: tuple[dict, ...] = ()
    degraded: bool = False
    # How many saved items the read actually saw. Set only by a read of Knows,
    # because it is what lets Truth tell "you have this saved" from a claim to
    # have just saved it.
    saved_knowledge_count: Optional[int] = None


@dataclass(frozen=True)
class FetchResult:
    reply: Optional[str] = None
    chat_history_included: bool = False
    memory_status: Optional[dict] = None


FetchSource = Callable[[Iterable[BrainAction]], Awaitable[Optional[FetchPacks]]]
FetchRunner = Callable[
    [Iterable[BrainAction], list[dict]],
    Awaitable[Optional[FetchResult]],
]

_GROUNDING_RULES = (
    "Answer using only the fetched Clarity data above. If what the user asked "
    "for is not in it, say what Clarity does not have instead of estimating or "
    "recalling from memory. Prefer a rounded range over invented precision, and "
    "do not claim any record was created, changed, or deleted."
)


def build_fetch_runner(
    *,
    sources: Iterable[FetchSource],
    grok_turn_brain,
    usage_recorder,
    channel,
    max_tokens: int,
) -> FetchRunner:
    resolved = tuple(sources)

    async def runner(
        actions: Iterable[BrainAction],
        ai_messages: list[dict],
    ) -> Optional[FetchResult]:
        return await run_fetch(
            actions,
            ai_messages=ai_messages,
            sources=resolved,
            grok_turn_brain=grok_turn_brain,
            usage_recorder=usage_recorder,
            channel=channel,
            max_tokens=max_tokens,
        )

    return runner


async def run_fetch(
    actions: Iterable[BrainAction],
    *,
    ai_messages: list[dict],
    sources: Iterable[FetchSource],
    grok_turn_brain,
    usage_recorder,
    channel,
    max_tokens: int,
) -> Optional[FetchResult]:
    """Return a grounded reply when the brain asked to fetch, else None."""
    resolved = tuple(actions)
    outcomes = [
        outcome
        for outcome in [await source(resolved) for source in sources]
        if outcome is not None
    ]
    if not outcomes:
        return None

    packs = [pack for outcome in outcomes for pack in outcome.packs]
    gaps = [
        outcome.unavailable_reply
        for outcome in outcomes
        if outcome.unavailable_reply
    ]
    signals = _signals(outcomes)

    if not packs:
        # Nothing was readable. The honest copy is the answer, and there is
        # nothing for a second call to be grounded in.
        return FetchResult(reply=gaps[0] if gaps else None, **signals)

    body = "\n\n".join([*packs, *gaps])
    messages = [*ai_messages, {"role": "system", "content": _fetch_prompt(body)}]
    result = await _grounded_pass(
        messages,
        grok_turn_brain=grok_turn_brain,
        usage_recorder=usage_recorder,
        channel=channel,
        max_tokens=max_tokens,
    )
    # Fences in the grounded pass are dropped: a fetch answer is text only.
    reply = parse_brain_actions(getattr(result, "text", "") or "").reply_text
    return FetchResult(reply=reply or None, **signals)


def _signals(outcomes: list[FetchPacks]) -> dict:
    statuses = [
        status for outcome in outcomes for status in outcome.source_statuses
    ]
    degraded = any(outcome.degraded for outcome in outcomes)
    counts = [
        outcome.saved_knowledge_count
        for outcome in outcomes
        if outcome.saved_knowledge_count is not None
    ]
    memory_status = None
    if statuses or degraded or counts:
        memory_status = {
            "state": "degraded" if degraded else "ready",
            "source_statuses": statuses,
        }
        if counts:
            memory_status["saved_knowledge_count"] = sum(counts)
    return {
        "chat_history_included": any(
            outcome.chat_history_included for outcome in outcomes
        ),
        "memory_status": memory_status,
    }


async def _grounded_pass(
    messages: list[dict],
    *,
    grok_turn_brain,
    usage_recorder,
    channel,
    max_tokens: int,
):
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
    return result


def _fetch_prompt(body: str) -> str:
    return (
        "Clarity data fetched this turn (the only source for this answer):\n"
        f"{body}\n\n{_GROUNDING_RULES}"
    )