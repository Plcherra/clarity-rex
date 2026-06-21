import logging
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
from app.services.recall_intent_helper import MEMORY_INVENTORY_QUERY


CHAT_SEARCH_RESULTS_LIMIT = 12
PAST_CHAT_SEARCH_PAGE_LIMIT = 200
CHAT_EXCERPT_CONTEXT_BEFORE = 6
CHAT_EXCERPT_CONTEXT_AFTER = 8
CHAT_EXCERPT_CONVERSATION_LIMIT = 500
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

        if search_messages is not None:
            for search_query, query_mode in search_queries:
                query_modes.add(query_mode)
                attempted_queries.append({"query": search_query, "mode": query_mode})
                try:
                    offset = 0
                    while True:
                        messages = await search_messages(
                            search_query,
                            limit=PAST_CHAT_SEARCH_PAGE_LIMIT,
                            exclude_conversation_id=exclude_conversation_id,
                            offset=offset,
                        )
                        scanned_messages += len(messages)
                        for message in messages:
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
                        if len(messages) < PAST_CHAT_SEARCH_PAGE_LIMIT:
                            break
                        offset += PAST_CHAT_SEARCH_PAGE_LIMIT
                except Exception as exc:
                    partial = True
                    failures.append(safe_error_message(exc))
                    LOGGER.warning("rex_memory_fetch_failed source=chat_search")
                    break

        if search_conversations is not None:
            for search_query, query_mode in search_queries:
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
                        if not isinstance(message, dict):
                            continue
                        message_id = str(message.get("id") or "")
                        if not message_id:
                            continue
                        scored_message = self.scored_chat_message(
                            query,
                            message,
                            query_mode=f"conversation_search:{query_mode}",
                        )
                        existing = messages_by_id.get(message_id)
                        if existing is None or (
                            scored_message.get("_chat_search_score", 0)
                            > existing.get("_chat_search_score", 0)
                        ):
                            messages_by_id[message_id] = scored_message
                except Exception as exc:
                    partial = True
                    failures.append(safe_error_message(exc))
                    LOGGER.warning("rex_memory_fetch_failed source=conversation_search")
                    break

        full_scan_used = False
        if list_messages is not None:
            full_scan_used = True
            query_modes.add("full_scan")
            full_scan_messages, full_scan_count = await self.full_chat_scan_matches(
                query=query,
                exclude_conversation_id=exclude_conversation_id,
                search_queries=search_queries,
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
        elif failures:
            return [
                ContextFetchError(
                    source="chat_search",
                    message=failures[0],
                ).as_dict()
            ]

        excerpts = await self.chat_conversation_excerpts(
            list(messages_by_id.values()),
            limit=limit,
        )
        return [
            {
                CONTEXT_STATUS_KEY: True,
                "source": "chat_search",
                "attempted": True,
                "succeeded": True,
                "result_count": len(excerpts),
                "raw_match_count": len(messages_by_id),
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
    ) -> tuple[list[dict], int]:
        list_messages = getattr(self.memory_service, "list_messages", None)
        if list_messages is None:
            return [], 0

        best_by_id: dict[str, dict] = {}
        scanned_messages = 0
        search_queries = search_queries or self.past_chat_search_queries(query)
        offset = 0
        while True:
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
            if len(messages) < PAST_CHAT_SEARCH_PAGE_LIMIT:
                break
            offset += PAST_CHAT_SEARCH_PAGE_LIMIT

        ranked = sorted(
            best_by_id.values(),
            key=lambda item: (
                float(item.get("_chat_search_score") or 0),
                str(item.get("timestamp") or ""),
            ),
            reverse=True,
        )
        return ranked[:PAST_CHAT_SEARCH_PAGE_LIMIT], scanned_messages

    def past_chat_search_queries(self, query: str) -> list[tuple[str, str]]:
        return [
            (item.query, item.mode)
            for item in self.chat_search_ranking.build_queries(
                query,
                inventory_query=MEMORY_INVENTORY_QUERY,
                max_terms=10,
            )
        ]

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
        grouped: dict[str, list[dict]] = {}
        without_conversation = []
        for message in sorted(matched_messages, key=chat_search_candidate_rank):
            conversation_id = str(message.get("conversation_id") or "")
            if conversation_id:
                grouped.setdefault(conversation_id, []).append(message)
            else:
                without_conversation.append(message)

        excerpts = []
        for conversation_id, matches in grouped.items():
            if await self.chat_cluster_was_rejected(matches):
                continue
            context_messages = await self.conversation_cluster_context(
                conversation_id,
                matches,
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
            context_messages = await self.chat_excerpt_context(message)
            content = self.chat_excerpt_content(context_messages)
            if not content:
                continue
            if await self.chat_excerpt_was_rejected(message):
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

    async def chat_cluster_was_rejected(self, matched_messages: list[dict]) -> bool:
        for message in matched_messages:
            if not is_chat_search_user_content_message(message):
                continue
            if await self.chat_excerpt_was_rejected(message):
                return True
        return False

    async def conversation_cluster_context(
        self, conversation_id: str, matched_messages: list[dict]
    ) -> list[dict]:
        get_messages = getattr(self.memory_service, "get_conversation_messages", None)
        if get_messages is None:
            return matched_messages

        try:
            conversation_messages = await get_messages(
                conversation_id,
                limit=CHAT_EXCERPT_CONVERSATION_LIMIT,
            )
        except Exception:
            return matched_messages
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
                if message_id:
                    seen_ids.add(message_id)
                context_messages.append(message)
        return context_messages

    async def chat_excerpt_context(
        self, message: dict, *, before: int = CHAT_EXCERPT_CONTEXT_BEFORE,
        after: int = CHAT_EXCERPT_CONTEXT_AFTER,
    ) -> list[dict]:
        conversation_id = str(message.get("conversation_id") or "")
        message_id = str(message.get("id") or "")
        if not conversation_id or not message_id:
            return [message]

        get_messages = getattr(self.memory_service, "get_conversation_messages", None)
        if get_messages is None:
            return [message]

        try:
            conversation_messages = await get_messages(conversation_id, limit=80)
        except Exception:
            return [message]
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
            if is_chat_search_no_result_message(message):
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

    def chat_excerpt_has_user_content(self, messages: list[dict]) -> bool:
        return any(
            is_chat_search_user_content_message(message) for message in messages
        )

    async def chat_excerpt_was_rejected(self, message: dict) -> bool:
        conversation_id = str(message.get("conversation_id") or "")
        message_id = str(message.get("id") or "")
        if not conversation_id or not message_id:
            return False

        get_messages = getattr(self.memory_service, "get_conversation_messages", None)
        if get_messages is None:
            return False

        try:
            conversation_messages = await get_messages(conversation_id, limit=40)
        except Exception:
            return False
        if not conversation_messages:
            return False

        message_index = self.message_index(conversation_messages, message_id)
        if message_index is None:
            return False

        following_messages = conversation_messages[message_index + 1 : message_index + 7]
        return any(
            is_memory_rejection_message(item) for item in following_messages
        )

    def message_index(
        self, conversation_messages: list[dict], message_id: str
    ) -> Optional[int]:
        for index, item in enumerate(conversation_messages):
            if str(item.get("id") or "") == message_id:
                return index
        return None
