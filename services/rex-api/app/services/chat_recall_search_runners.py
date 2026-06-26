"""Conversation, message, and full-scan runners for chat recall search."""

from __future__ import annotations

import logging
import time
from typing import TYPE_CHECKING, Optional

from app.services.chat_recall_filters import is_chat_search_no_result_message
from app.services.chat_recall_match_helpers import viable_match_count
from app.services.chat_recall_query_builder import PAST_CHAT_SEARCH_PAGE_LIMIT
from app.services.memory_context_status import safe_error_message

if TYPE_CHECKING:
    from app.services.chat_recall_search import ChatRecallSearch, ChatRecallSearchResult

LOGGER = logging.getLogger("rex.context")

PAST_CHAT_SEARCH_MAX_PAGES = 3
PAST_CHAT_FULL_SCAN_MAX_PAGES = 3
PAST_CHAT_FULL_SCAN_MAX_MESSAGES = PAST_CHAT_SEARCH_PAGE_LIMIT * PAST_CHAT_FULL_SCAN_MAX_PAGES
PAST_CHAT_FULL_SCAN_TIME_BUDGET_SECONDS = 6.0
CHAT_SEARCH_RESULTS_LIMIT = 12


async def run_conversation_search(
    search: ChatRecallSearch,
    result: ChatRecallSearchResult,
    *,
    query: str,
    search_queries: list[tuple[str, str]],
    target_match_count: int,
    search_conversations,
) -> None:
    for search_query, query_mode in search_queries:
        phase_started = time.perf_counter()
        result.query_modes.add("conversation_search")
        result.attempted_queries.append(
            {
                "query": search_query,
                "mode": f"conversation_search:{query_mode}",
            }
        )
        try:
            conversation_results = await search_conversations(
                search_query,
                limit=PAST_CHAT_SEARCH_PAGE_LIMIT,
            )
            result.scanned_messages += len(conversation_results)
            for item in conversation_results:
                message = item.get("message")
                if isinstance(message, dict) and search.scorer.is_current_query_echo(
                    query,
                    message,
                ):
                    continue
                search.add_best_message(
                    result.messages_by_id,
                    search.scorer.scored_conversation_search_result(
                        query,
                        item,
                        query_mode=f"conversation_search:{query_mode}",
                    ),
                )
            search.log(
                "conversation_search",
                phase_started,
                mode=query_mode,
                result_count=len(conversation_results),
                raw_match_count=len(result.messages_by_id),
            )
            if viable_match_count(result.messages_by_id) >= target_match_count:
                search.log(
                    "conversation_search_early_stop",
                    raw_match_count=len(result.messages_by_id),
                    viable_match_count=viable_match_count(result.messages_by_id),
                    target_match_count=target_match_count,
                )
                break
        except Exception as exc:
            result.partial = True
            failure = safe_error_message(exc)
            if failure not in result.failures:
                result.failures.append(failure)
            LOGGER.warning("rex_memory_fetch_failed source=conversation_search")


async def run_message_search(
    search: ChatRecallSearch,
    result: ChatRecallSearchResult,
    *,
    query: str,
    exclude_conversation_id: Optional[str],
    search_queries: list[tuple[str, str]],
    target_match_count: int,
    search_messages,
) -> None:
    for search_query, query_mode in search_queries:
        result.query_modes.add(query_mode)
        result.attempted_queries.append({"query": search_query, "mode": query_mode})
        try:
            offset = 0
            page_count = 0
            while page_count < PAST_CHAT_SEARCH_MAX_PAGES:
                phase_started = time.perf_counter()
                messages = await search_messages(
                    search_query,
                    limit=PAST_CHAT_SEARCH_PAGE_LIMIT,
                    exclude_conversation_id=exclude_conversation_id,
                    offset=offset,
                )
                result.scanned_messages += len(messages)
                for message in messages:
                    if is_chat_search_no_result_message(message):
                        continue
                    if search.scorer.is_current_query_echo(query, message):
                        continue
                    search.add_best_message(
                        result.messages_by_id,
                        search.scorer.scored_chat_message(
                            query,
                            message,
                            query_mode=query_mode,
                        ),
                    )
                search.log(
                    "search_messages_page",
                    phase_started,
                    mode=query_mode,
                    offset=offset,
                    page_count=page_count + 1,
                    result_count=len(messages),
                    raw_match_count=len(result.messages_by_id),
                )
                if viable_match_count(result.messages_by_id) >= target_match_count:
                    search.log(
                        "search_messages_early_stop",
                        raw_match_count=len(result.messages_by_id),
                        viable_match_count=viable_match_count(result.messages_by_id),
                        target_match_count=target_match_count,
                    )
                    break
                if len(messages) < PAST_CHAT_SEARCH_PAGE_LIMIT:
                    break
                offset += PAST_CHAT_SEARCH_PAGE_LIMIT
                page_count += 1
            if viable_match_count(result.messages_by_id) >= target_match_count:
                break
        except Exception as exc:
            result.partial = True
            failure = safe_error_message(exc)
            if failure not in result.failures:
                result.failures.append(failure)
            LOGGER.warning("rex_memory_fetch_failed source=chat_search")


async def full_chat_scan_matches(
    search: ChatRecallSearch,
    *,
    query: str,
    exclude_conversation_id: Optional[str],
    search_queries: Optional[list[tuple[str, str]]] = None,
    target_match_count: int = CHAT_SEARCH_RESULTS_LIMIT,
) -> tuple[list[dict], int]:
    list_messages = getattr(search.memory_service, "list_messages", None)
    if list_messages is None:
        return [], 0

    best_by_id: dict[str, dict] = {}
    scanned_messages = 0
    search_queries = search_queries or search.past_chat_search_queries(query)
    full_scan_started = time.perf_counter()
    offset = 0
    page_count = 0
    while (
        page_count < PAST_CHAT_FULL_SCAN_MAX_PAGES
        and scanned_messages < PAST_CHAT_FULL_SCAN_MAX_MESSAGES
    ):
        if (
            page_count > 0
            and time.perf_counter() - full_scan_started
            >= PAST_CHAT_FULL_SCAN_TIME_BUDGET_SECONDS
        ):
            search.log(
                "full_scan_soft_budget_stop",
                scanned_messages=scanned_messages,
                raw_match_count=len(best_by_id),
                time_budget_seconds=PAST_CHAT_FULL_SCAN_TIME_BUDGET_SECONDS,
            )
            break
        phase_started = time.perf_counter()
        try:
            messages = await list_messages(
                limit=PAST_CHAT_SEARCH_PAGE_LIMIT,
                offset=offset,
                exclude_conversation_id=exclude_conversation_id,
            )
        except Exception:
            LOGGER.warning("rex_memory_fetch_failed source=chat_search_full_scan")
            return [], scanned_messages
        scanned_messages += len(messages)
        for message in messages:
            if is_chat_search_no_result_message(message):
                continue
            if search.scorer.is_current_query_echo(query, message):
                continue
            scored = search.scorer.best_scored_chat_message(
                query,
                message,
                search_queries=search_queries,
            )
            if float(scored.get("_chat_search_score") or 0) <= 0:
                continue
            search.add_best_message(best_by_id, scored)
        search.log(
            "full_scan_page",
            phase_started,
            offset=offset,
            page_count=page_count + 1,
            result_count=len(messages),
            scanned_messages=scanned_messages,
            raw_match_count=len(best_by_id),
        )
        if len(best_by_id) >= target_match_count:
            search.log(
                "full_scan_early_stop",
                raw_match_count=len(best_by_id),
                target_match_count=target_match_count,
            )
            break
        if len(messages) < PAST_CHAT_SEARCH_PAGE_LIMIT:
            break
        offset += PAST_CHAT_SEARCH_PAGE_LIMIT
        page_count += 1

    ranked = sorted(
        best_by_id.values(),
        key=lambda item: (
            search.scorer.recency_ranked_score(item.get("_chat_search_score")),
            str(item.get("timestamp") or ""),
            float(item.get("_chat_search_score") or 0),
        ),
        reverse=True,
    )
    return ranked[:PAST_CHAT_SEARCH_PAGE_LIMIT], scanned_messages
