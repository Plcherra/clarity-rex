import logging
import time
from dataclasses import dataclass, field
from typing import Callable, Optional

from app.services.chat_recall_match_helpers import (
    add_best_message,
    best_match_score,
    detail_rich_match_count,
    factual_user_match_count,
    has_strong_shared_search_signal,
    is_viable_chat_match,
    message_has_recall_detail,
    query_needs_detail,
    viable_match_count,
)
from app.services.chat_recall_query_builder import (
    PAST_CHAT_SEARCH_PAGE_LIMIT,
    combined_past_chat_search_queries,
    shared_conversation_search_queries,
    target_match_count,
    unique_search_queries,
)
from app.services.chat_recall_scoring import ChatRecallScorer
from app.services.chat_recall_search_runners import (
    full_chat_scan_matches,
    run_conversation_search,
    run_message_search,
)
from app.services.chat_search_ranking import ChatSearchRanking
from app.services.memory_context_status import safe_error_message


PAST_CHAT_SEARCH_MAX_PAGES = 3
PAST_CHAT_FULL_SCAN_MAX_PAGES = 3
PAST_CHAT_FULL_SCAN_MAX_MESSAGES = (
    PAST_CHAT_SEARCH_PAGE_LIMIT * PAST_CHAT_FULL_SCAN_MAX_PAGES
)
PAST_CHAT_FULL_SCAN_TIME_BUDGET_SECONDS = 6.0
PAST_CHAT_SHARED_SEARCH_QUERY_LIMIT = 10
CHAT_SEARCH_RESULTS_LIMIT = 12
LOGGER = logging.getLogger("rex.context")


@dataclass
class ChatRecallSearchResult:
    messages_by_id: dict[str, dict] = field(default_factory=dict)
    query_modes: set[str] = field(default_factory=set)
    attempted_queries: list[dict] = field(default_factory=list)
    scanned_messages: int = 0
    partial: bool = False
    failures: list[str] = field(default_factory=list)
    full_scan_used: bool = False
    error_message: Optional[str] = None


class ChatRecallSearch:
    def __init__(
        self,
        memory_service,
        *,
        chat_search_ranking: Optional[ChatSearchRanking] = None,
        log_recall_phase: Optional[Callable[..., None]] = None,
    ) -> None:
        self.memory_service = memory_service
        self.scorer = ChatRecallScorer(chat_search_ranking=chat_search_ranking)
        self.log_recall_phase = log_recall_phase

    async def search(
        self,
        *,
        query: str,
        limit: int,
        exclude_conversation_id: Optional[str],
        search_queries: Optional[list[tuple[str, str]]] = None,
        target_match_count: Optional[int] = None,
    ) -> ChatRecallSearchResult:
        search_messages = getattr(self.memory_service, "search_messages", None)
        search_conversations = getattr(self.memory_service, "search_conversations", None)
        list_messages = getattr(self.memory_service, "list_messages", None)
        if search_messages is None and search_conversations is None and list_messages is None:
            return ChatRecallSearchResult(
                error_message="Past chat search is unavailable.",
            )

        result = ChatRecallSearchResult()
        search_queries = search_queries or self.past_chat_search_queries(query)
        target_match_count = target_match_count or self.target_match_count(limit)
        shared_conversation_search = getattr(
            self.memory_service,
            "search_conversations",
            None,
        )
        shared_search_used = False

        if shared_conversation_search is not None:
            shared_search_used = True
            result.query_modes.add("shared_conversation_search")
            for search_query, query_mode in self.shared_conversation_search_queries(
                query,
                search_queries=search_queries,
            ):
                shared_mode = (
                    "shared_conversation_search"
                    if query_mode == "exact"
                    else f"shared_conversation_search:{query_mode}"
                )
                result.attempted_queries.append(
                    {"query": search_query, "mode": shared_mode}
                )
                phase_started = time.perf_counter()
                try:
                    conversation_results = await shared_conversation_search(
                        search_query,
                        limit=PAST_CHAT_SEARCH_PAGE_LIMIT,
                        exclude_conversation_id=exclude_conversation_id,
                    )
                    result.scanned_messages += len(conversation_results)
                    for item in conversation_results:
                        message = item.get("message")
                        if isinstance(
                            message,
                            dict,
                        ) and self.scorer.is_current_query_echo(
                            query,
                            message,
                        ):
                            continue
                        self.add_best_message(
                            result.messages_by_id,
                            self.scorer.scored_conversation_search_result(
                                search_query,
                                item,
                                query_mode=shared_mode,
                            ),
                        )
                    self.log(
                        "shared_conversation_search",
                        phase_started,
                        mode=query_mode,
                        result_count=len(conversation_results),
                        raw_match_count=len(result.messages_by_id),
                    )
                except Exception as exc:
                    failure = safe_error_message(exc)
                    LOGGER.warning(
                        "rex_memory_fetch_failed source=shared_conversation_search"
                    )
                    result.error_message = failure
                    return result

        fallback_search_allowed = (
            not shared_search_used
            or not self.has_strong_shared_search_signal(
                query,
                result.messages_by_id,
                target_match_count=target_match_count,
            )
        )

        if (
            search_conversations is not None
            and fallback_search_allowed
            and not shared_search_used
        ):
            await run_conversation_search(
                self,
                result,
                query=query,
                search_queries=search_queries,
                target_match_count=target_match_count,
                search_conversations=search_conversations,
            )

        if (
            search_messages is not None
            and self.viable_match_count(result.messages_by_id) < target_match_count
            and fallback_search_allowed
        ):
            await run_message_search(
                self,
                result,
                query=query,
                exclude_conversation_id=exclude_conversation_id,
                search_queries=search_queries,
                target_match_count=target_match_count,
                search_messages=search_messages,
            )

        should_run_full_scan = (
            list_messages is not None
            and (
                self.viable_match_count(result.messages_by_id) == 0
                or (
                    self.query_needs_detail(query)
                    and self.detail_rich_match_count(result.messages_by_id) == 0
                )
            )
            and fallback_search_allowed
        )
        if should_run_full_scan:
            result.full_scan_used = True
            result.query_modes.add("full_scan")
            phase_started = time.perf_counter()
            full_scan_messages, full_scan_count = await full_chat_scan_matches(
                self,
                query=query,
                exclude_conversation_id=exclude_conversation_id,
                search_queries=search_queries,
                target_match_count=target_match_count,
            )
            result.scanned_messages += full_scan_count
            for message in full_scan_messages:
                self.add_best_message(result.messages_by_id, message)
            self.log(
                "full_scan_complete",
                phase_started,
                scanned_messages=full_scan_count,
                raw_match_count=len(result.messages_by_id),
            )
        elif list_messages is not None:
            self.log(
                "full_scan_skipped",
                raw_match_count=len(result.messages_by_id),
                target_match_count=target_match_count,
            )
        elif result.failures:
            result.error_message = result.failures[0]

        return result

    def past_chat_search_queries(self, query: str) -> list[tuple[str, str]]:
        return self.scorer.past_chat_search_queries(query)

    def combined_past_chat_search_queries(
        self,
        query: str,
        *,
        raw_query: Optional[str] = None,
    ) -> list[tuple[str, str]]:
        return combined_past_chat_search_queries(
            query,
            raw_query=raw_query,
            base_queries_for=self.past_chat_search_queries,
        )

    def shared_conversation_search_queries(
        self,
        query: str,
        *,
        search_queries: list[tuple[str, str]],
    ) -> list[tuple[str, str]]:
        return shared_conversation_search_queries(
            query,
            search_queries=search_queries,
        )

    def unique_search_queries(
        self,
        queries: list[tuple[str, str]],
    ) -> list[tuple[str, str]]:
        return unique_search_queries(queries)

    def target_match_count(self, limit: int) -> int:
        return target_match_count(limit)

    def add_best_message(self, messages_by_id: dict[str, dict], message: dict) -> None:
        add_best_message(messages_by_id, message)

    def is_viable_chat_match(self, message: dict) -> bool:
        return is_viable_chat_match(message)

    def viable_match_count(self, messages_by_id: dict[str, dict]) -> int:
        return viable_match_count(messages_by_id)

    def factual_user_match_count(self, messages_by_id: dict[str, dict]) -> int:
        return factual_user_match_count(messages_by_id)

    def detail_rich_match_count(self, messages_by_id: dict[str, dict]) -> int:
        return detail_rich_match_count(messages_by_id)

    def best_match_score(self, messages_by_id: dict[str, dict]) -> float:
        return best_match_score(messages_by_id)

    def has_strong_shared_search_signal(
        self,
        query: str,
        messages_by_id: dict[str, dict],
        *,
        target_match_count: int,
    ) -> bool:
        return has_strong_shared_search_signal(
            query,
            messages_by_id,
            target_match_count=target_match_count,
        )

    def query_needs_detail(self, query: str) -> bool:
        return query_needs_detail(query)

    def message_has_recall_detail(self, message: dict) -> bool:
        return message_has_recall_detail(message)

    def log(
        self,
        phase: str,
        started: Optional[float] = None,
        **fields,
    ) -> None:
        if self.log_recall_phase is not None:
            self.log_recall_phase(phase, started, **fields)
