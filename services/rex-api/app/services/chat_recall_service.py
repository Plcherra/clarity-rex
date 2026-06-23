import logging
import time
from datetime import datetime, timezone
from typing import Optional

from app.services.chat_recall_filters import (
    chat_search_candidate_rank,
    is_chat_search_no_result_message,
    is_chat_search_user_content_message,
    is_memory_rejection_message,
)
from app.services.chat_search_ranking import ChatSearchRanking
from app.services.memory_context_status import (
    CONTEXT_STATUS_KEY,
    ContextFetchError,
    safe_error_message,
)


CHAT_SEARCH_RESULTS_LIMIT = 12
PAST_CHAT_SEARCH_PAGE_LIMIT = 200
PAST_CHAT_SEARCH_MAX_PAGES = 3
PAST_CHAT_FULL_SCAN_MAX_PAGES = 3
PAST_CHAT_FULL_SCAN_MAX_MESSAGES = (
    PAST_CHAT_SEARCH_PAGE_LIMIT * PAST_CHAT_FULL_SCAN_MAX_PAGES
)
PAST_CHAT_FULL_SCAN_TIME_BUDGET_SECONDS = 6.0
CHAT_EXCERPT_CONTEXT_BEFORE = 6
CHAT_EXCERPT_CONTEXT_AFTER = 8
CHAT_EXCERPT_CONVERSATION_LIMIT = 500
CHAT_TITLE_MATCH_CONTEXT_LIMIT = 24
LOGGER = logging.getLogger("rex.context")


class ChatRecallService:
    def __init__(
        self, memory_service, *, chat_search_ranking: Optional[ChatSearchRanking] = None
    ) -> None:
        self.memory_service = memory_service
        self.chat_search_ranking = chat_search_ranking or ChatSearchRanking()

    async def fetch_relevant_chat_excerpts(
        self, *, query: str, limit: int, exclude_conversation_id: Optional[str]
    ) -> list[dict]:
        recall_started = time.perf_counter()
        search_messages = getattr(self.memory_service, "search_messages", None)
        search_conversations = getattr(self.memory_service, "search_conversations", None)
        list_messages = getattr(self.memory_service, "list_messages", None)
        if search_messages is None and search_conversations is None and list_messages is None:
            return [
                ContextFetchError(
                    source="chat_search",
                    message="Past chat search is unavailable.",
                ).as_dict()
            ]

        messages_by_id: dict[str, dict] = {}
        query_modes: set[str] = set()
        attempted_queries: list[dict] = []
        scanned_messages = 0
        partial = False
        failures: list[str] = []
        search_queries = self.past_chat_search_queries(query)
        target_match_count = self.target_match_count(limit)
        ranked_chat_search = getattr(self.memory_service, "search_chat_history", None)
        ranked_search_used = False
        self.log_recall_phase(
            "fetch_relevant_chat_excerpts_start",
            query_length=len(query or ""),
            query_count=len(search_queries),
            limit=limit,
            target_match_count=target_match_count,
        )

        if ranked_chat_search is not None:
            ranked_search_used = True
            query_modes.add("indexed_search")
            attempted_queries.append({"query": query, "mode": "indexed_search"})
            phase_started = time.perf_counter()
            try:
                conversation_results = await ranked_chat_search(
                    query,
                    limit=target_match_count,
                    exclude_conversation_id=exclude_conversation_id,
                )
                scanned_messages += len(conversation_results)
                for result in conversation_results:
                    message = result.get("message")
                    if isinstance(message, dict) and self.is_current_query_echo(
                        query,
                        message,
                    ):
                        continue
                    scored_message = self.scored_conversation_search_result(
                        query,
                        result,
                        query_mode="indexed_search",
                    )
                    message_id = str(scored_message.get("id") or "")
                    if not message_id:
                        continue
                    existing = messages_by_id.get(message_id)
                    if existing is None or (
                        scored_message.get("_chat_search_score", 0)
                        > existing.get("_chat_search_score", 0)
                    ):
                        messages_by_id[message_id] = scored_message
                self.log_recall_phase(
                    "indexed_chat_search",
                    phase_started,
                    result_count=len(conversation_results),
                    raw_match_count=len(messages_by_id),
                )
            except Exception as exc:
                failure = safe_error_message(exc)
                LOGGER.warning("rex_memory_fetch_failed source=indexed_chat_search")
                return [
                    ContextFetchError(
                        source="chat_search",
                        message=failure,
                    ).as_dict()
                ]

        if search_conversations is not None and not ranked_search_used:
            for search_query, query_mode in search_queries:
                phase_started = time.perf_counter()
                query_modes.add("conversation_search")
                attempted_queries.append(
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
                    scanned_messages += len(conversation_results)
                    for result in conversation_results:
                        message = result.get("message")
                        if isinstance(message, dict) and self.is_current_query_echo(
                            query,
                            message,
                        ):
                            continue
                        scored_message = self.scored_conversation_search_result(
                            query,
                            result,
                            query_mode=f"conversation_search:{query_mode}",
                        )
                        message_id = str(scored_message.get("id") or "")
                        if not message_id:
                            continue
                        existing = messages_by_id.get(message_id)
                        if existing is None or (
                            scored_message.get("_chat_search_score", 0)
                            > existing.get("_chat_search_score", 0)
                        ):
                            messages_by_id[message_id] = scored_message
                    self.log_recall_phase(
                        "conversation_search",
                        phase_started,
                        mode=query_mode,
                        result_count=len(conversation_results),
                        raw_match_count=len(messages_by_id),
                    )
                    if self.viable_match_count(messages_by_id) >= target_match_count:
                        self.log_recall_phase(
                            "conversation_search_early_stop",
                            raw_match_count=len(messages_by_id),
                            viable_match_count=self.viable_match_count(messages_by_id),
                            target_match_count=target_match_count,
                        )
                        break
                except Exception as exc:
                    partial = True
                    failure = safe_error_message(exc)
                    if failure not in failures:
                        failures.append(failure)
                    LOGGER.warning("rex_memory_fetch_failed source=conversation_search")
                    continue

        if (
            search_messages is not None
            and self.viable_match_count(messages_by_id) < target_match_count
            and not ranked_search_used
        ):
            for search_query, query_mode in search_queries:
                query_modes.add(query_mode)
                attempted_queries.append({"query": search_query, "mode": query_mode})
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
                        scanned_messages += len(messages)
                        for message in messages:
                            if is_chat_search_no_result_message(message):
                                continue
                            if self.is_current_query_echo(query, message):
                                continue
                            message_id = str(message.get("id") or "")
                            if not message_id:
                                continue
                            scored_message = self.scored_chat_message(
                                query,
                                message,
                                query_mode=query_mode,
                            )
                            existing = messages_by_id.get(message_id)
                            if existing is None or (
                                scored_message.get("_chat_search_score", 0)
                                > existing.get("_chat_search_score", 0)
                            ):
                                messages_by_id[message_id] = scored_message
                        self.log_recall_phase(
                            "search_messages_page",
                            phase_started,
                            mode=query_mode,
                            offset=offset,
                            page_count=page_count + 1,
                            result_count=len(messages),
                            raw_match_count=len(messages_by_id),
                        )
                        if self.viable_match_count(messages_by_id) >= target_match_count:
                            self.log_recall_phase(
                                "search_messages_early_stop",
                                raw_match_count=len(messages_by_id),
                                viable_match_count=self.viable_match_count(
                                    messages_by_id
                                ),
                                target_match_count=target_match_count,
                            )
                            break
                        if len(messages) < PAST_CHAT_SEARCH_PAGE_LIMIT:
                            break
                        offset += PAST_CHAT_SEARCH_PAGE_LIMIT
                        page_count += 1
                    if self.viable_match_count(messages_by_id) >= target_match_count:
                        break
                except Exception as exc:
                    partial = True
                    failure = safe_error_message(exc)
                    if failure not in failures:
                        failures.append(failure)
                    LOGGER.warning("rex_memory_fetch_failed source=chat_search")
                    continue

        full_scan_used = False
        should_run_full_scan = (
            list_messages is not None
            and self.viable_match_count(messages_by_id) == 0
            and not ranked_search_used
        )
        if should_run_full_scan:
            full_scan_used = True
            query_modes.add("full_scan")
            phase_started = time.perf_counter()
            full_scan_messages, full_scan_count = await self.full_chat_scan_matches(
                query=query,
                exclude_conversation_id=exclude_conversation_id,
                search_queries=search_queries,
                target_match_count=target_match_count,
            )
            scanned_messages += full_scan_count
            if full_scan_messages:
                for message in full_scan_messages:
                    message_id = str(message.get("id") or "")
                    if not message_id:
                        continue
                    existing = messages_by_id.get(message_id)
                    if existing is None or (
                        message.get("_chat_search_score", 0)
                        > existing.get("_chat_search_score", 0)
                    ):
                        messages_by_id[message_id] = message
            self.log_recall_phase(
                "full_scan_complete",
                phase_started,
                scanned_messages=full_scan_count,
                raw_match_count=len(messages_by_id),
            )
        elif list_messages is not None:
            self.log_recall_phase(
                "full_scan_skipped",
                raw_match_count=len(messages_by_id),
                target_match_count=target_match_count,
            )
        elif failures:
            return [
                ContextFetchError(
                    source="chat_search",
                    message=failures[0],
                ).as_dict()
            ]

        excerpt_started = time.perf_counter()
        excerpts = await self.chat_conversation_excerpts(
            list(messages_by_id.values()),
            limit=limit,
        )
        self.log_recall_phase(
            "chat_conversation_excerpts",
            excerpt_started,
            excerpt_count=len(excerpts),
            raw_match_count=len(messages_by_id),
        )
        self.log_recall_phase(
            "fetch_relevant_chat_excerpts_complete",
            recall_started,
            result_count=len(excerpts),
            raw_match_count=len(messages_by_id),
            scanned_messages=scanned_messages,
            full_scan_used=full_scan_used,
            partial=partial,
        )
        return [
            {
                CONTEXT_STATUS_KEY: True,
                "source": "chat_search",
                "attempted": True,
                "succeeded": True,
                "result_count": len(excerpts),
                "raw_match_count": len(messages_by_id),
                "filtered_match_count": max(0, len(messages_by_id) - len(excerpts)),
                "filtered_all_matches": bool(messages_by_id) and not excerpts,
                "scanned_messages": scanned_messages,
                "partial": partial,
                "full_scan_used": full_scan_used,
                "query_modes": sorted(query_modes),
                "queries": attempted_queries,
                "failures": [
                    {"source": "chat_search", "message": failure}
                    for failure in failures
                ],
                "status": "found" if excerpts else "empty",
            },
            *excerpts,
        ]

    async def full_chat_scan_matches(
        self, *, query: str, exclude_conversation_id: Optional[str],
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
                self.log_recall_phase(
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
                if self.is_current_query_echo(query, message):
                    continue
                scored = self.best_scored_chat_message(
                    query,
                    message,
                    search_queries=search_queries,
                )
                if float(scored.get("_chat_search_score") or 0) <= 0:
                    continue
                message_id = str(scored.get("id") or "")
                if not message_id:
                    continue
                existing = best_by_id.get(message_id)
                if existing is None or (
                    scored.get("_chat_search_score", 0)
                    > existing.get("_chat_search_score", 0)
                ):
                    best_by_id[message_id] = scored
            self.log_recall_phase(
                "full_scan_page",
                phase_started,
                offset=offset,
                page_count=page_count + 1,
                result_count=len(messages),
                scanned_messages=scanned_messages,
                raw_match_count=len(best_by_id),
            )
            if len(best_by_id) >= target_match_count:
                self.log_recall_phase(
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
                self.recency_ranked_score(item.get("_chat_search_score")),
                str(item.get("timestamp") or ""),
                float(item.get("_chat_search_score") or 0),
            ),
            reverse=True,
        )
        return ranked[:PAST_CHAT_SEARCH_PAGE_LIMIT], scanned_messages

    def past_chat_search_queries(self, query: str) -> list[tuple[str, str]]:
        return [
            (item.query, item.mode)
            for item in self.chat_search_ranking.build_queries(
                query,
                max_terms=10,
            )
        ]

    def target_match_count(self, limit: int) -> int:
        return max(limit, min(PAST_CHAT_SEARCH_PAGE_LIMIT, limit * 2))

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

    def is_current_query_echo(self, query: str, message: dict) -> bool:
        if str(message.get("role") or "") != "user":
            return False
        content = str(message.get("content") or "")
        return self.normalized_echo_text(content) == self.normalized_echo_text(query)

    def normalized_echo_text(self, text: str) -> str:
        return " ".join(str(text or "").lower().strip().strip(".!?").split())

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

    def scored_chat_message(self, query: str, message: dict, *, query_mode: str) -> dict:
        score = self.chat_search_ranking.score_text(
            query,
            str(message.get("content") or ""),
            role=str(message.get("role") or ""),
            timestamp=str(message.get("timestamp") or ""),
        )
        return {
            **message,
            "_chat_search_score": score.score,
            "_chat_search_reason": score.reason,
            "_chat_search_query_mode": query_mode,
            "_chat_search_matched_terms": list(score.matched_terms),
        }

    def scored_conversation_search_result(
        self,
        query: str,
        result: dict,
        *,
        query_mode: str,
    ) -> dict:
        conversation_id = str(result.get("conversation_id") or "")
        match_type = str(result.get("match_type") or "conversation")
        message = result.get("message")
        if not isinstance(message, dict):
            message = {
                "id": f"conversation-{conversation_id}-{match_type}",
                "conversation_id": conversation_id,
                "role": "conversation",
                "content": str(
                    result.get("preview")
                    or result.get("conversation_title")
                    or "Matched conversation."
                ),
                "timestamp": result.get("conversation_timestamp"),
            }

        scored_message = self.scored_chat_message(
            query,
            message,
            query_mode=query_mode,
        )
        repository_score = float(result.get("relevance_score") or 0)
        local_score = float(scored_message.get("_chat_search_score") or 0)
        matched_terms = {
            str(term)
            for term in [
                *list(scored_message.get("_chat_search_matched_terms") or []),
                *list(result.get("matched_terms") or []),
            ]
            if str(term)
        }
        return {
            **scored_message,
            "_chat_search_score": max(repository_score, local_score),
            "_chat_search_reason": (
                result.get("search_reason")
                or scored_message.get("_chat_search_reason")
                or "conversation search match"
            ),
            "_chat_search_matched_terms": sorted(matched_terms),
            "_conversation_search_match_type": match_type,
            "_conversation_search_title": result.get("conversation_title"),
            "_conversation_search_preview": result.get("preview"),
        }

    def best_scored_chat_message(
        self, query: str, message: dict, *, search_queries: list[tuple[str, str]]
    ) -> dict:
        best_message = self.scored_chat_message(
            query,
            message,
            query_mode="full_scan",
        )
        for search_query, query_mode in search_queries:
            scored = self.scored_chat_message(
                search_query,
                message,
                query_mode=f"full_scan:{query_mode}",
            )
            if scored.get("_chat_search_score", 0) > best_message.get(
                "_chat_search_score",
                0,
            ):
                best_message = scored
        return best_message

    async def chat_conversation_excerpts(
        self, matched_messages: list[dict], *, limit: int
    ) -> list[dict]:
        conversation_messages_cache: dict[tuple[str, int], list[dict]] = {}
        grouped: dict[str, list[dict]] = {}
        without_conversation = []
        for message in sorted(matched_messages, key=chat_search_candidate_rank):
            conversation_id = str(message.get("conversation_id") or "")
            if conversation_id:
                grouped.setdefault(conversation_id, []).append(message)
            else:
                without_conversation.append(message)

        excerpts = []
        sorted_groups = sorted(
            grouped.items(),
            key=lambda item: (
                self.recency_ranked_score(
                    max(
                        float(message.get("_chat_search_score") or 0)
                        for message in item[1]
                    )
                ),
                max(str(message.get("timestamp") or "") for message in item[1]),
                max(
                    float(message.get("_chat_search_score") or 0)
                    for message in item[1]
                ),
            ),
            reverse=True,
        )
        for conversation_id, matches in sorted_groups:
            matches = [
                message
                for message in matches
                if not await self.chat_excerpt_was_rejected_by_user(
                    message,
                    conversation_messages_cache=conversation_messages_cache,
                )
            ]
            if not matches:
                continue
            context_messages = await self.conversation_cluster_context(
                conversation_id,
                matches,
                conversation_messages_cache=conversation_messages_cache,
            )
            content = self.chat_excerpt_content(context_messages)
            if not content or not self.chat_excerpt_has_user_content(context_messages):
                continue
            excerpts.append(
                {
                    "id": f"chat-{conversation_id}",
                    "content": content,
                    "timestamp": self.latest_message_timestamp(context_messages),
                    "conversation_id": conversation_id,
                    "source_message_id": matches[0].get("id"),
                    "matched_message_ids": [
                        str(message.get("id"))
                        for message in matches
                        if str(message.get("id") or "")
                    ],
                    "relevance_score": max(
                        float(message.get("_chat_search_score") or 0)
                        for message in matches
                    ),
                    "query_modes": sorted(
                        {
                            str(message.get("_chat_search_query_mode") or "")
                            for message in matches
                            if str(message.get("_chat_search_query_mode") or "")
                        }
                    ),
                    "matched_terms": sorted(
                        {
                            str(term)
                            for message in matches
                            for term in message.get("_chat_search_matched_terms", [])
                            if str(term)
                        }
                    ),
                    "relevance_reason": (
                        "Matched chat history; included nearby conversation context."
                    ),
                }
            )
            if len(excerpts) >= limit:
                return excerpts

        for message in without_conversation:
            if is_chat_search_no_result_message(message):
                continue
            context_messages = await self.chat_excerpt_context(
                message,
                conversation_messages_cache=conversation_messages_cache,
            )
            content = self.chat_excerpt_content(context_messages)
            if not content:
                continue
            if not self.chat_excerpt_has_user_content(context_messages):
                continue
            excerpts.append(
                {
                    "id": f"chat-{message.get('id')}",
                    "content": content,
                    "timestamp": message.get("timestamp"),
                    "conversation_id": message.get("conversation_id"),
                    "source_message_id": message.get("id"),
                    "relevance_score": float(message.get("_chat_search_score") or 0),
                    "query_modes": [
                        str(message.get("_chat_search_query_mode") or "exact")
                    ],
                    "matched_terms": list(
                        message.get("_chat_search_matched_terms") or []
                    ),
                    "relevance_reason": "Matched relevant chat history.",
                }
            )
            if len(excerpts) >= limit:
                break
        return excerpts

    async def conversation_cluster_context(
        self,
        conversation_id: str,
        matched_messages: list[dict],
        *,
        conversation_messages_cache: Optional[dict[tuple[str, int], list[dict]]] = None,
    ) -> list[dict]:
        conversation_messages = await self.cached_conversation_messages(
            conversation_id,
            limit=CHAT_EXCERPT_CONVERSATION_LIMIT,
            conversation_messages_cache=conversation_messages_cache,
        )
        if not conversation_messages:
            return matched_messages

        matched_ids = {
            str(message.get("id") or "")
            for message in matched_messages
            if str(message.get("id") or "")
        }
        matched_indexes = [
            index
            for index, message in enumerate(conversation_messages)
            if str(message.get("id") or "") in matched_ids
        ]
        if not matched_indexes:
            if self.has_conversation_level_match(matched_messages):
                return self.conversation_level_context(conversation_messages)
            return matched_messages

        ranges = []
        for index in matched_indexes:
            start = max(0, index - CHAT_EXCERPT_CONTEXT_BEFORE)
            end = min(
                len(conversation_messages),
                index + CHAT_EXCERPT_CONTEXT_AFTER + 1,
            )
            if ranges and start <= ranges[-1][1]:
                ranges[-1] = (ranges[-1][0], max(ranges[-1][1], end))
            else:
                ranges.append((start, end))

        context_messages = []
        seen_ids = set()
        for start, end in ranges:
            for message in conversation_messages[start:end]:
                message_id = str(message.get("id") or "")
                if message_id and message_id in seen_ids:
                    continue
                if is_chat_search_no_result_message(message):
                    continue
                if is_memory_rejection_message(message):
                    continue
                if await self.chat_excerpt_was_rejected_by_user(
                    message,
                    conversation_messages=conversation_messages,
                ):
                    continue
                if message_id:
                    seen_ids.add(message_id)
                context_messages.append(message)
        return context_messages

    def has_conversation_level_match(self, matched_messages: list[dict]) -> bool:
        return any(
            str(message.get("_conversation_search_match_type") or "")
            in {"title", "conversation"}
            for message in matched_messages
        )

    def conversation_level_context(self, conversation_messages: list[dict]) -> list[dict]:
        filtered = [
            message
            for message in conversation_messages
            if not is_chat_search_no_result_message(message)
            and not is_memory_rejection_message(message)
        ]
        if len(filtered) <= CHAT_TITLE_MATCH_CONTEXT_LIMIT:
            return filtered
        return filtered[:CHAT_TITLE_MATCH_CONTEXT_LIMIT]

    async def cached_conversation_messages(
        self,
        conversation_id: str,
        *,
        limit: int,
        conversation_messages_cache: Optional[dict[tuple[str, int], list[dict]]] = None,
    ) -> list[dict]:
        if not conversation_id:
            return []
        cache_key = (conversation_id, limit)
        if conversation_messages_cache is not None and cache_key in conversation_messages_cache:
            self.log_recall_phase(
                "conversation_messages_cache_hit",
                conversation_id=conversation_id,
                limit=limit,
            )
            return conversation_messages_cache[cache_key]

        get_messages = getattr(self.memory_service, "get_conversation_messages", None)
        if get_messages is None:
            return []

        phase_started = time.perf_counter()
        try:
            conversation_messages = await get_messages(conversation_id, limit=limit)
        except Exception:
            return []
        self.log_recall_phase(
            "conversation_messages_fetch",
            phase_started,
            conversation_id=conversation_id,
            limit=limit,
            result_count=len(conversation_messages or []),
        )
        conversation_messages = conversation_messages or []
        if conversation_messages_cache is not None:
            conversation_messages_cache[cache_key] = conversation_messages
        return conversation_messages

    async def chat_excerpt_context(
        self, message: dict, *, before: int = CHAT_EXCERPT_CONTEXT_BEFORE,
        after: int = CHAT_EXCERPT_CONTEXT_AFTER,
        conversation_messages_cache: Optional[dict[tuple[str, int], list[dict]]] = None,
    ) -> list[dict]:
        conversation_id = str(message.get("conversation_id") or "")
        message_id = str(message.get("id") or "")
        if not conversation_id or not message_id:
            return [message]

        conversation_messages = await self.cached_conversation_messages(
            conversation_id,
            limit=80,
            conversation_messages_cache=conversation_messages_cache,
        )
        if not conversation_messages:
            return [message]

        message_index = self.message_index(conversation_messages, message_id)
        if message_index is None:
            return [message]

        start = max(0, message_index - before)
        end = min(len(conversation_messages), message_index + after + 1)
        return conversation_messages[start:end]

    def chat_excerpt_content(self, messages: list[dict]) -> str:
        lines = []
        for message in messages:
            if (
                is_chat_search_no_result_message(message)
                or is_memory_rejection_message(message)
            ):
                continue
            content = str(message.get("content") or "").strip()
            if not content:
                continue
            role = str(message.get("role") or "message")
            lines.append(f"- {role}: {content}")
        return "\n".join(lines)

    def latest_message_timestamp(self, messages: list[dict]) -> Optional[str]:
        timestamps = [
            str(message.get("timestamp") or "")
            for message in messages
            if str(message.get("timestamp") or "")
        ]
        return max(timestamps) if timestamps else None

    def recency_ranked_score(self, score: object) -> int:
        return round(float(score or 0) * 2)

    def chat_excerpt_has_user_content(self, messages: list[dict]) -> bool:
        return any(
            is_chat_search_user_content_message(message) for message in messages
        )

    async def chat_excerpt_was_rejected_by_user(
        self,
        message: dict,
        *,
        conversation_messages: Optional[list[dict]] = None,
        conversation_messages_cache: Optional[dict[tuple[str, int], list[dict]]] = None,
    ) -> bool:
        if str(message.get("role") or "") != "user":
            return False
        conversation_id = str(message.get("conversation_id") or "")
        message_id = str(message.get("id") or "")
        if not conversation_id or not message_id:
            return False

        if conversation_messages is None:
            conversation_messages = await self.cached_conversation_messages(
                conversation_id,
                limit=40,
                conversation_messages_cache=conversation_messages_cache,
            )
        if not conversation_messages:
            return False

        message_index = self.message_index(conversation_messages, message_id)
        if message_index is None:
            return False

        following_messages = conversation_messages[
            message_index + 1 : message_index + 7
        ]
        return any(
            str(item.get("role") or "") == "user"
            and is_memory_rejection_message(item)
            for item in following_messages
        )

    def message_index(
        self, conversation_messages: list[dict], message_id: str
    ) -> Optional[int]:
        for index, item in enumerate(conversation_messages):
            if str(item.get("id") or "") == message_id:
                return index
        return None
