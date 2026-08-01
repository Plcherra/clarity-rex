"""Read old chats and the Knows inventory when Grok asks (plan 05 Phase G).

Both reads used to ride along on every turn. They are expensive and usually
unwanted, so now the brain names them and only then does the body go looking.

Neither read writes anything, and both stay labelled: chat hits are chat hits,
inventory is what the Knows tab already shows. Nothing here may be presented as
remembered unless the user can see it there.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Iterable, Optional

from app.services.brain_action_schema import BrainAction
from app.services.capabilities.recall_action_payload import (
    RecallFetchRequest,
    recall_fetch_requests,
)
from app.services.chat_turn_fetch import FetchPacks, FetchSource
from app.services.memory_context_status import CONTEXT_ERROR_KEY, CONTEXT_STATUS_KEY
from app.services.prompt_constants import CHAT_SEARCH_RESULTS_PREFIX
from app.services.prompt_inventory_context import format_inventory_context

LOGGER = logging.getLogger("clarity.recall_fetch")

# A search is worth its tokens only if the excerpts survive intact; a dozen
# clipped ones answer nothing. Fewer, whole, is the trade.
CHAT_EXCERPT_LIMIT = 6
CHAT_PACK_CHAR_BUDGET = 3000
INVENTORY_PACK_CHAR_BUDGET = 2400

SEARCH_UNAVAILABLE_REPLY = (
    "I tried to search our past chats and the search itself failed, so I can't "
    "tell you whether we talked about that. Ask me again in a moment."
)
# Deliberately avoids "saved"/"in Knows": the memory Truth guard reads those as
# a write claim and would replace this honest copy with its own.
INVENTORY_UNAVAILABLE_REPLY = (
    "I couldn't reach your Knows data just now, so I'd rather not guess at "
    "what's there. Try again in a moment."
)


def build_recall_fetch_source(
    *,
    recall_service,
    overview_service,
    conversation_id: str,
    user_message: str = "",
) -> FetchSource:
    async def source(actions: Iterable[BrainAction]) -> Optional[FetchPacks]:
        return await run_recall_fetch(
            actions,
            recall_service=recall_service,
            overview_service=overview_service,
            conversation_id=conversation_id,
            user_message=user_message,
        )

    return source


async def run_recall_fetch(
    actions: Iterable[BrainAction],
    *,
    recall_service,
    overview_service,
    conversation_id: str,
    user_message: str = "",
) -> Optional[FetchPacks]:
    requests = recall_fetch_requests(actions, user_message=user_message)
    if not requests:
        return None

    packs: list[str] = []
    gaps: list[str] = []
    statuses: list[dict] = []
    degraded = False
    chat_history_included = False
    saved_knowledge_count: Optional[int] = None

    for request in requests:
        if request.is_inventory:
            inventory = await _inventory_pack(overview_service)
            if inventory is None:
                gaps.append(INVENTORY_UNAVAILABLE_REPLY)
            else:
                pack, saved_knowledge_count = inventory
                packs.append(pack)
            continue

        found = await _chat_pack(
            request,
            recall_service=recall_service,
            conversation_id=conversation_id,
        )
        if found.status is not None:
            statuses.append(found.status)
        degraded = degraded or found.degraded
        if found.pack:
            packs.append(found.pack)
            chat_history_included = True
        elif found.degraded:
            gaps.append(SEARCH_UNAVAILABLE_REPLY)
        else:
            # A search that ran and found nothing is an answer, not a gap: the
            # grounded pass says so, and Truth already owns the empty copy.
            packs.append(_empty_search_pack(request))

    return FetchPacks(
        packs=tuple(packs),
        unavailable_reply=gaps[0] if gaps else None,
        chat_history_included=chat_history_included,
        source_statuses=tuple(statuses),
        degraded=degraded,
        saved_knowledge_count=saved_knowledge_count,
    )


@dataclass(frozen=True)
class _ChatSearchOutcome:
    pack: Optional[str] = None
    status: Optional[dict] = None
    degraded: bool = False


async def _chat_pack(
    request: RecallFetchRequest,
    *,
    recall_service,
    conversation_id: str,
) -> _ChatSearchOutcome:
    if not request.query:
        return _ChatSearchOutcome(pack=None, status=None, degraded=True)
    try:
        items = await recall_service.fetch_relevant_chat_excerpts(
            query=request.query,
            limit=CHAT_EXCERPT_LIMIT,
            exclude_conversation_id=conversation_id,
            raw_query=request.query,
        )
    except Exception:
        LOGGER.warning("recall_fetch_failed capability=search_chats", exc_info=True)
        return _ChatSearchOutcome(pack=None, status=None, degraded=True)

    status: Optional[dict] = None
    excerpts: list[dict] = []
    for item in items or []:
        if not isinstance(item, dict):
            continue
        if item.get(CONTEXT_ERROR_KEY) is True:
            return _ChatSearchOutcome(pack=None, status=None, degraded=True)
        if item.get(CONTEXT_STATUS_KEY) is True:
            status = item
            continue
        excerpts.append(item)

    if not excerpts:
        return _ChatSearchOutcome(pack=None, status=status, degraded=False)

    body = _capped(
        "\n\n".join(
            str(excerpt.get("content") or "").strip()
            for excerpt in excerpts
            if str(excerpt.get("content") or "").strip()
        ),
        CHAT_PACK_CHAR_BUDGET,
    )
    if not body:
        return _ChatSearchOutcome(pack=None, status=status, degraded=False)
    pack = (
        f"search_chats (query: {request.query})\n"
        f"{CHAT_SEARCH_RESULTS_PREFIX}{body}"
    )
    return _ChatSearchOutcome(pack=pack, status=status, degraded=False)


def _empty_search_pack(request: RecallFetchRequest) -> str:
    return (
        f"search_chats (query: {request.query})\n"
        "No past conversation matched. Say the search found nothing rather than "
        "answering from memory."
    )


async def _inventory_pack(overview_service) -> Optional[tuple[str, int]]:
    """The Knows snapshot and how many items it holds, or None if the read failed."""
    try:
        overview = await overview_service.get_overview()
    except Exception:
        LOGGER.warning(
            "recall_fetch_failed capability=list_knows_summary",
            exc_info=True,
        )
        return None
    body = _capped(format_inventory_context(overview), INVENTORY_PACK_CHAR_BUDGET)
    if not body:
        return None
    counts = overview.get("counts") if isinstance(overview, dict) else None
    total = int((counts or {}).get("total") or 0)
    return f"list_knows_summary\n{body}", total


def _capped(text: str, budget: int) -> str:
    cleaned = (text or "").strip()
    if len(cleaned) <= budget:
        return cleaned
    return f"{cleaned[:budget].rstrip()}\n(truncated — more exists in Clarity)"
