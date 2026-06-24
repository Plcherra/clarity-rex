import time
from typing import Callable, Optional

from app.services.chat_recall_filters import (
    chat_search_candidate_rank,
    is_chat_search_no_result_message,
    is_chat_search_user_content_message,
    is_memory_rejection_message,
)


CHAT_EXCERPT_CONTEXT_BEFORE = 6
CHAT_EXCERPT_CONTEXT_AFTER = 8
CHAT_EXCERPT_CONVERSATION_LIMIT = 500
CHAT_TITLE_MATCH_CONTEXT_LIMIT = 24


class ChatRecallExcerptBuilder:
    def __init__(
        self,
        memory_service,
        *,
        log_recall_phase: Optional[Callable[..., None]] = None,
    ) -> None:
        self.memory_service = memory_service
        self.log_recall_phase = log_recall_phase

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
            in {"title", "conversation", "conversation_summary"}
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
            self.log(
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
        self.log(
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
        self,
        message: dict,
        *,
        before: int = CHAT_EXCERPT_CONTEXT_BEFORE,
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

    def log(
        self,
        phase: str,
        started: Optional[float] = None,
        **fields,
    ) -> None:
        if self.log_recall_phase is not None:
            self.log_recall_phase(phase, started, **fields)
