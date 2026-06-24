import logging
import time
from datetime import datetime, timezone
from typing import Optional

from app.services.chat_recall_excerpts import ChatRecallExcerptBuilder
from app.services.chat_recall_search import CHAT_SEARCH_RESULTS_LIMIT, ChatRecallSearch
from app.services.chat_search_ranking import ChatSearchRanking
from app.services.memory_context_status import (
    CONTEXT_STATUS_KEY,
    ContextFetchError,
)


LOGGER = logging.getLogger("rex.context")


class ChatRecallService:
    def __init__(
        self, memory_service, *, chat_search_ranking: Optional[ChatSearchRanking] = None
    ) -> None:
        self.memory_service = memory_service
        ranking = chat_search_ranking or ChatSearchRanking()
        self.chat_recall_search = ChatRecallSearch(
            memory_service,
            chat_search_ranking=ranking,
            log_recall_phase=self.log_recall_phase,
        )
        self.chat_recall_excerpts = ChatRecallExcerptBuilder(
            memory_service,
            log_recall_phase=self.log_recall_phase,
        )

    async def fetch_relevant_chat_excerpts(
        self,
        *,
        query: str,
        limit: int,
        exclude_conversation_id: Optional[str],
        raw_query: Optional[str] = None,
    ) -> list[dict]:
        recall_started = time.perf_counter()
        search_queries = self.chat_recall_search.combined_past_chat_search_queries(
            query,
            raw_query=raw_query,
        )
        target_match_count = self.chat_recall_search.target_match_count(limit)
        self.log_recall_phase(
            "fetch_relevant_chat_excerpts_start",
            query_length=len(query or ""),
            raw_query_length=len(raw_query or ""),
            query_count=len(search_queries),
            limit=limit,
            target_match_count=target_match_count,
        )

        search_result = await self.chat_recall_search.search(
            query=query,
            limit=limit,
            exclude_conversation_id=exclude_conversation_id,
            search_queries=search_queries,
            target_match_count=target_match_count,
        )
        if search_result.error_message:
            return [
                ContextFetchError(
                    source="chat_search",
                    message=search_result.error_message,
                ).as_dict()
            ]

        excerpt_started = time.perf_counter()
        excerpts = await self.chat_recall_excerpts.chat_conversation_excerpts(
            list(search_result.messages_by_id.values()),
            limit=limit,
        )
        self.log_recall_phase(
            "chat_conversation_excerpts",
            excerpt_started,
            excerpt_count=len(excerpts),
            raw_match_count=len(search_result.messages_by_id),
        )
        self.log_recall_phase(
            "fetch_relevant_chat_excerpts_complete",
            recall_started,
            result_count=len(excerpts),
            raw_match_count=len(search_result.messages_by_id),
            scanned_messages=search_result.scanned_messages,
            full_scan_used=search_result.full_scan_used,
            partial=search_result.partial,
        )
        filtered_all_matches = bool(search_result.messages_by_id) and not excerpts
        status = "found" if excerpts else "filtered" if filtered_all_matches else "empty"
        return [
            {
                CONTEXT_STATUS_KEY: True,
                "source": "chat_search",
                "attempted": True,
                "succeeded": True,
                "result_count": len(excerpts),
                "raw_match_count": len(search_result.messages_by_id),
                "filtered_match_count": max(
                    0,
                    len(search_result.messages_by_id) - len(excerpts),
                ),
                "filtered_all_matches": filtered_all_matches,
                "scanned_messages": search_result.scanned_messages,
                "partial": search_result.partial,
                "full_scan_used": search_result.full_scan_used,
                "query_modes": sorted(search_result.query_modes),
                "queries": search_result.attempted_queries,
                "failures": [
                    {"source": "chat_search", "message": failure}
                    for failure in search_result.failures
                ],
                "status": status,
            },
            *excerpts,
        ]

    def log_recall_phase(
        self,
        phase: str,
        started: Optional[float] = None,
        **fields,
    ) -> None:
        elapsed = {}
        if started is not None:
            elapsed["elapsed_ms"] = round((time.perf_counter() - started) * 1000)
        parts = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "phase": phase,
            **elapsed,
            **fields,
        }
        LOGGER.info(
            "rex_chat_recall_timing %s",
            " ".join(f"{key}={value}" for key, value in parts.items()),
        )
