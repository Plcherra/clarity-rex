import logging
import re
import time
from dataclasses import dataclass, field
from typing import Callable, Optional

from app.services.chat_recall_filters import (
    is_chat_search_no_result_message,
    is_chat_search_user_content_message,
)
from app.services.chat_recall_scoring import ChatRecallScorer
from app.services.chat_search_ranking import ChatSearchRanking
from app.services.memory_context_status import safe_error_message


CHAT_SEARCH_RESULTS_LIMIT = 12
PAST_CHAT_SEARCH_PAGE_LIMIT = 200
PAST_CHAT_SEARCH_MAX_PAGES = 3
PAST_CHAT_FULL_SCAN_MAX_PAGES = 3
PAST_CHAT_FULL_SCAN_MAX_MESSAGES = (
    PAST_CHAT_SEARCH_PAGE_LIMIT * PAST_CHAT_FULL_SCAN_MAX_PAGES
)
PAST_CHAT_FULL_SCAN_TIME_BUDGET_SECONDS = 6.0
PAST_CHAT_SHARED_SEARCH_QUERY_LIMIT = 10
SHARED_SEARCH_STRONG_MATCH_SCORE = 6.0
SHARED_SEARCH_MIN_FACTUAL_MATCHES = 3
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
            await self.run_conversation_search(
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
            await self.run_message_search(
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
            full_scan_messages, full_scan_count = await self.full_chat_scan_matches(
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

    async def run_conversation_search(
        self,
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
                    if isinstance(message, dict) and self.scorer.is_current_query_echo(
                        query,
                        message,
                    ):
                        continue
                    self.add_best_message(
                        result.messages_by_id,
                        self.scorer.scored_conversation_search_result(
                            query,
                            item,
                            query_mode=f"conversation_search:{query_mode}",
                        ),
                    )
                self.log(
                    "conversation_search",
                    phase_started,
                    mode=query_mode,
                    result_count=len(conversation_results),
                    raw_match_count=len(result.messages_by_id),
                )
                if self.viable_match_count(result.messages_by_id) >= target_match_count:
                    self.log(
                        "conversation_search_early_stop",
                        raw_match_count=len(result.messages_by_id),
                        viable_match_count=self.viable_match_count(result.messages_by_id),
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
        self,
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
                        if self.scorer.is_current_query_echo(query, message):
                            continue
                        self.add_best_message(
                            result.messages_by_id,
                            self.scorer.scored_chat_message(
                                query,
                                message,
                                query_mode=query_mode,
                            ),
                        )
                    self.log(
                        "search_messages_page",
                        phase_started,
                        mode=query_mode,
                        offset=offset,
                        page_count=page_count + 1,
                        result_count=len(messages),
                        raw_match_count=len(result.messages_by_id),
                    )
                    if self.viable_match_count(result.messages_by_id) >= target_match_count:
                        self.log(
                            "search_messages_early_stop",
                            raw_match_count=len(result.messages_by_id),
                            viable_match_count=self.viable_match_count(
                                result.messages_by_id
                            ),
                            target_match_count=target_match_count,
                        )
                        break
                    if len(messages) < PAST_CHAT_SEARCH_PAGE_LIMIT:
                        break
                    offset += PAST_CHAT_SEARCH_PAGE_LIMIT
                    page_count += 1
                if self.viable_match_count(result.messages_by_id) >= target_match_count:
                    break
            except Exception as exc:
                result.partial = True
                failure = safe_error_message(exc)
                if failure not in result.failures:
                    result.failures.append(failure)
                LOGGER.warning("rex_memory_fetch_failed source=chat_search")

    async def full_chat_scan_matches(
        self,
        *,
        query: str,
        exclude_conversation_id: Optional[str],
        search_queries: Optional[list[tuple[str, str]]] = None,
        target_match_count: int = CHAT_SEARCH_RESULTS_LIMIT,
    ) -> tuple[list[dict], int]:
        list_messages = getattr(self.memory_service, "list_messages", None)
        if list_messages is None:
            return [], 0

        best_by_id: dict[str, dict] = {}
        scanned_messages = 0
        search_queries = search_queries or self.past_chat_search_queries(query)
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
                self.log(
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
                if self.scorer.is_current_query_echo(query, message):
                    continue
                scored = self.scorer.best_scored_chat_message(
                    query,
                    message,
                    search_queries=search_queries,
                )
                if float(scored.get("_chat_search_score") or 0) <= 0:
                    continue
                self.add_best_message(best_by_id, scored)
            self.log(
                "full_scan_page",
                phase_started,
                offset=offset,
                page_count=page_count + 1,
                result_count=len(messages),
                scanned_messages=scanned_messages,
                raw_match_count=len(best_by_id),
            )
            if len(best_by_id) >= target_match_count:
                self.log(
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
                self.scorer.recency_ranked_score(item.get("_chat_search_score")),
                str(item.get("timestamp") or ""),
                float(item.get("_chat_search_score") or 0),
            ),
            reverse=True,
        )
        return ranked[:PAST_CHAT_SEARCH_PAGE_LIMIT], scanned_messages

    def past_chat_search_queries(self, query: str) -> list[tuple[str, str]]:
        return self.scorer.past_chat_search_queries(query)

    def combined_past_chat_search_queries(
        self,
        query: str,
        *,
        raw_query: Optional[str] = None,
    ) -> list[tuple[str, str]]:
        queries: list[tuple[str, str]] = []
        for candidate in (query, raw_query):
            if not str(candidate or "").strip():
                continue
            queries.extend(self.past_chat_search_queries(str(candidate)))
        return self.unique_search_queries(queries)

    def shared_conversation_search_queries(
        self,
        query: str,
        *,
        search_queries: list[tuple[str, str]],
    ) -> list[tuple[str, str]]:
        queries = self.unique_search_queries(
            [
                (query, "exact"),
                *search_queries,
            ]
        )
        priority = {
            "exact": 0,
            "subject": 1,
            "expanded_keywords": 2,
            "keyword": 3,
        }
        queries = sorted(
            queries,
            key=lambda item: (
                priority.get(item[1], 9),
                len(item[0]),
                item[0],
            ),
        )
        return queries[:PAST_CHAT_SHARED_SEARCH_QUERY_LIMIT]

    def unique_search_queries(
        self,
        queries: list[tuple[str, str]],
    ) -> list[tuple[str, str]]:
        unique: list[tuple[str, str]] = []
        seen: set[str] = set()
        for search_query, query_mode in queries:
            normalized = " ".join(str(search_query or "").split())
            if not normalized or normalized.lower() in seen:
                continue
            seen.add(normalized.lower())
            unique.append((normalized, query_mode))
        return unique

    def target_match_count(self, limit: int) -> int:
        return max(limit, min(PAST_CHAT_SEARCH_PAGE_LIMIT, limit * 2))

    def add_best_message(self, messages_by_id: dict[str, dict], message: dict) -> None:
        message_id = str(message.get("id") or "")
        if not message_id:
            return
        existing = messages_by_id.get(message_id)
        if existing is None or (
            message.get("_chat_search_score", 0)
            > existing.get("_chat_search_score", 0)
        ):
            messages_by_id[message_id] = message

    def is_viable_chat_match(self, message: dict) -> bool:
        if is_chat_search_no_result_message(message):
            return False
        if float(message.get("_chat_search_score") or 0) > 0:
            return True
        return bool(str(message.get("content") or "").strip())

    def viable_match_count(self, messages_by_id: dict[str, dict]) -> int:
        return sum(
            1 for message in messages_by_id.values() if self.is_viable_chat_match(message)
        )

    def factual_user_match_count(self, messages_by_id: dict[str, dict]) -> int:
        return sum(
            1
            for message in messages_by_id.values()
            if is_chat_search_user_content_message(message)
        )

    def detail_rich_match_count(self, messages_by_id: dict[str, dict]) -> int:
        return sum(
            1
            for message in messages_by_id.values()
            if is_chat_search_user_content_message(message)
            and self.message_has_recall_detail(message)
        )

    def best_match_score(self, messages_by_id: dict[str, dict]) -> float:
        return max(
            (
                float(message.get("_chat_search_score") or 0)
                for message in messages_by_id.values()
                if self.is_viable_chat_match(message)
            ),
            default=0.0,
        )

    def has_strong_shared_search_signal(
        self,
        query: str,
        messages_by_id: dict[str, dict],
        *,
        target_match_count: int,
    ) -> bool:
        factual_count = self.factual_user_match_count(messages_by_id)
        detail_count = self.detail_rich_match_count(messages_by_id)
        if self.query_needs_detail(query):
            return detail_count >= min(
                SHARED_SEARCH_MIN_FACTUAL_MATCHES,
                target_match_count,
            )
        if detail_count >= min(SHARED_SEARCH_MIN_FACTUAL_MATCHES, target_match_count):
            return True
        if factual_count >= min(SHARED_SEARCH_MIN_FACTUAL_MATCHES, target_match_count):
            return detail_count >= 1
        return (
            factual_count >= 2
            and detail_count >= 1
            and self.best_match_score(messages_by_id) >= SHARED_SEARCH_STRONG_MATCH_SCORE
        )

    def query_needs_detail(self, query: str) -> bool:
        text = str(query or "").lower()
        return bool(
            re.search(
                r"\b(?:amount|birthday|date|for what|how much|june|when|why|\d{1,2})\b",
                text,
            )
        )

    def message_has_recall_detail(self, message: dict) -> bool:
        text = str(message.get("content") or "").lower()
        if not text:
            return False
        return bool(
            re.search(
                r"\$\s*\d|\b\d+(?:\.\d{2})?\b|\b(?:birthday|june|model|for\s+her|"
                r"for\s+his|for\s+their|bought|purchased|downloaded|gog|steam)\b",
                text,
            )
        )

    def log(
        self,
        phase: str,
        started: Optional[float] = None,
        **fields,
    ) -> None:
        if self.log_recall_phase is not None:
            self.log_recall_phase(phase, started, **fields)
