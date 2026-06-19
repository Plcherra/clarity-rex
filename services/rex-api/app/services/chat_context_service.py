import asyncio
import json
import logging
import re
import time
from dataclasses import dataclass
from typing import Optional

from app.services.accountability_service import AccountabilityService
from app.services.chat_search_ranking import ChatSearchRanking
from app.services.goal_context_service import GoalContextService
from app.services.prompt_service import PromptService
from app.services.rex_intent_router import RexIntentDecision
from app.services.time_context_service import TimeContextService

PROFILE_MEMORY_QUERY = (
    "user profile location timezone where I live state city home current time "
    "important identity facts birthdays family important dates preferences"
)
MEMORY_INVENTORY_QUERY = (
    f"{PROFILE_MEMORY_QUERY} people relationships parents mom mother dad father "
    "sibling friend birthday plans goals commitments personal rules memories "
    "chats conversations preferences"
)
PROFILE_MEMORY_LIMIT = 4
CHAT_SEARCH_RESULTS_LIMIT = 12
PAST_CHAT_SEARCH_PAGE_LIMIT = 200
CHAT_EXCERPT_CONTEXT_BEFORE = 6
CHAT_EXCERPT_CONTEXT_AFTER = 8
CHAT_EXCERPT_CONVERSATION_LIMIT = 120
LOGGER = logging.getLogger("rex.context")
MEMORY_REJECTION_MARKERS = (
    "do not remember",
    "do not save",
    "don't remember",
    "don't save",
    "dont remember",
    "dont save",
    "no problem. i won't save that",
    "no problem. i will not save that",
    "won't save that",
    "will not save that",
)
CHAT_SEARCH_NO_RESULT_MARKERS = (
    "do not have anything saved",
    "don't have anything saved",
    "do not have any info",
    "don't have any info",
    "do not have your",
    "don't have your",
    "nothing about",
    "nothing came up",
    "nothing showed up",
    "found nothing",
    "could not find",
    "couldn't find",
    "did not find",
    "didn't find",
    "no mentions",
    "no mention",
    "not saved",
)
CONTEXT_ERROR_KEY = "_context_error"
CONTEXT_STATUS_KEY = "_context_status"


@dataclass(frozen=True)
class ContextFetchError:
    source: str
    message: str

    def as_dict(self) -> dict:
        return {
            CONTEXT_ERROR_KEY: True,
            "source": self.source,
            "message": self.message,
        }


class ChatContextService:
    def __init__(
        self,
        memory_service,
        *,
        prompt_service: Optional[PromptService] = None,
        time_context_service: Optional[TimeContextService] = None,
        accountability_service: Optional[AccountabilityService] = None,
        goal_context_service: Optional[GoalContextService] = None,
        chat_search_ranking: Optional[ChatSearchRanking] = None,
    ) -> None:
        self.memory_service = memory_service
        self.prompt_service = prompt_service or PromptService()
        self.time_context_service = time_context_service or TimeContextService()
        self.accountability_service = accountability_service or AccountabilityService()
        self.goal_context_service = goal_context_service or GoalContextService()
        self.chat_search_ranking = chat_search_ranking or ChatSearchRanking()

    async def fetch_prompt_context(
        self,
        *,
        message: str,
        conversation_id: Optional[str],
        intent_decision: Optional[RexIntentDecision] = None,
    ) -> tuple[list[dict], list[dict], dict]:
        fetch_started = time.perf_counter()
        timings_ms: dict[str, int] = {}
        memory_failures: list[dict] = []
        context_statuses: list[dict] = []
        load_long_term_memory = self._load_long_term_memory(intent_decision)
        force_chat_search = self.should_force_chat_recall_search(
            message,
            conversation_history=[],
        )
        load_chat_search = load_long_term_memory or force_chat_search
        load_profile_memory = self._load_profile_memory(intent_decision)
        load_structured_memory = self._load_structured_memory(intent_decision)
        load_goal_context = self._load_goal_context(intent_decision)
        memory_query = self.memory_retrieval_query(
            message,
            conversation_history=[],
        )
        load_profile_memory = load_profile_memory and memory_query not in {
            PROFILE_MEMORY_QUERY,
            MEMORY_INVENTORY_QUERY,
        }

        long_term_memory_task = None
        if load_long_term_memory and conversation_id is None:
            long_term_memory_task = self.timed_fetch(
                "long_term_memory",
                self.fetch_relevant_memories(query=memory_query, limit=8),
                timings_ms,
            )
        profile_memory_task = (
            self.timed_fetch(
                "profile_memory",
                self.fetch_relevant_memories(
                    query=PROFILE_MEMORY_QUERY,
                    limit=PROFILE_MEMORY_LIMIT,
                    source="profile_memory",
                ),
                timings_ms,
            )
            if load_profile_memory
            else self.empty_list()
        )
        chat_search_results_task = None
        if load_chat_search and conversation_id is None:
            chat_search_results_task = self.timed_fetch(
                "chat_search",
                self.fetch_relevant_chat_excerpts(
                    query=memory_query,
                    limit=CHAT_SEARCH_RESULTS_LIMIT,
                    exclude_conversation_id=None,
                ),
                timings_ms,
            )
        structured_context_task = self.timed_fetch(
            "structured_context",
            self.fetch_structured_context(
                message,
                include_structured_memory=load_structured_memory,
                include_goal_context=load_goal_context,
            ),
            timings_ms,
        )
        if conversation_id is None:
            (
                raw_long_term_memory,
                raw_profile_memory,
                raw_chat_search_results,
                structured_context,
            ) = await asyncio.gather(
                long_term_memory_task or self.empty_list(),
                profile_memory_task,
                chat_search_results_task or self.empty_list(),
                structured_context_task,
            )
            long_term_memory = self.context_items(
                raw_long_term_memory,
                memory_failures,
            )
            profile_memory = self.context_items(raw_profile_memory, memory_failures)
            chat_search_results = self.context_items(
                raw_chat_search_results,
                memory_failures,
                context_statuses,
            )
            structured_context = self.with_memory_status(
                structured_context,
                memory_failures,
                attempted_sources={
                    "long_term_memory": load_long_term_memory,
                    "profile_memory": load_profile_memory,
                    "chat_search": load_chat_search,
                    "structured_memory": load_structured_memory,
                },
                source_statuses=context_statuses,
            )
            structured_context = self.with_chat_search_results(
                structured_context,
                chat_search_results,
            )
            merged_memory = self.merge_memories(
                long_term_memory,
                profile_memory,
            )
            self.log_context_fetch(
                intent_decision=intent_decision,
                conversation_id=None,
                loaded={
                    "recent_messages": False,
                    "long_term_memory": load_long_term_memory,
                    "profile_memory": load_profile_memory,
                    "chat_search": load_chat_search,
                    "structured_memory": load_structured_memory,
                    "goal_context": load_goal_context,
                },
                counts={
                    "recent_messages": 0,
                    "long_term_memory": len(merged_memory),
                    "chat_search_results": len(chat_search_results),
                    "structured_context_keys": len(structured_context),
                },
                timings_ms=timings_ms,
                total_ms=self.elapsed_ms(fetch_started),
            )
            return (
                [],
                merged_memory,
                structured_context,
            )

        conversation_history = await self.timed_fetch(
            "recent_messages",
            self.fetch_recent_messages(conversation_id, limit=20),
            timings_ms,
        )
        conversation_history = self.context_items(
            conversation_history,
            memory_failures,
        )
        force_chat_search = self.should_force_chat_recall_search(
            message,
            conversation_history=conversation_history,
        )
        load_chat_search = load_long_term_memory or force_chat_search

        if load_long_term_memory:
            memory_query = self.memory_retrieval_query(
                message,
                conversation_history=conversation_history,
            )
            long_term_memory_task = self.timed_fetch(
                "long_term_memory",
                self.fetch_relevant_memories(query=memory_query, limit=8),
                timings_ms,
            )
        else:
            memory_query = self.memory_retrieval_query(
                message,
                conversation_history=conversation_history,
            )
            long_term_memory_task = self.empty_list()

        if load_chat_search:
            chat_search_results_task = self.timed_fetch(
                "chat_search",
                self.fetch_relevant_chat_excerpts(
                    query=memory_query,
                    limit=CHAT_SEARCH_RESULTS_LIMIT,
                    exclude_conversation_id=None,
                ),
                timings_ms,
            )
        else:
            chat_search_results_task = self.empty_list()

        (
            raw_long_term_memory,
            raw_profile_memory,
            raw_chat_search_results,
            structured_context,
        ) = await asyncio.gather(
            long_term_memory_task,
            profile_memory_task,
            chat_search_results_task,
            structured_context_task,
        )
        long_term_memory = self.context_items(raw_long_term_memory, memory_failures)
        profile_memory = self.context_items(raw_profile_memory, memory_failures)
        chat_search_results = self.context_items(
            raw_chat_search_results,
            memory_failures,
            context_statuses,
        )
        structured_context = self.with_memory_status(
            structured_context,
            memory_failures,
            attempted_sources={
                "recent_messages": True,
                "long_term_memory": load_long_term_memory,
                "profile_memory": load_profile_memory,
                "chat_search": load_chat_search,
                "structured_memory": load_structured_memory,
            },
            source_statuses=context_statuses,
        )
        structured_context = self.with_chat_search_results(
            structured_context,
            chat_search_results,
        )
        merged_memory = self.merge_memories(
            long_term_memory,
            profile_memory,
        )
        self.log_context_fetch(
            intent_decision=intent_decision,
            conversation_id=conversation_id,
            loaded={
                "recent_messages": True,
                "long_term_memory": load_long_term_memory,
                "profile_memory": load_profile_memory,
                "chat_search": load_chat_search,
                "structured_memory": load_structured_memory,
                "goal_context": load_goal_context,
            },
            counts={
                "recent_messages": len(conversation_history),
                "long_term_memory": len(merged_memory),
                "chat_search_results": len(chat_search_results),
                "structured_context_keys": len(structured_context),
            },
            timings_ms=timings_ms,
            total_ms=self.elapsed_ms(fetch_started),
        )
        return (
            conversation_history,
            merged_memory,
            structured_context,
        )

    async def fetch_recent_messages(
        self,
        conversation_id: str,
        *,
        limit: int = 20,
    ) -> list[dict]:
        try:
            return await self.memory_service.get_recent_messages(
                conversation_id,
                limit=limit,
            )
        except Exception as exc:
            LOGGER.warning("rex_memory_fetch_failed source=recent_messages")
            return [
                ContextFetchError(
                    source="recent_messages",
                    message=self.safe_error_message(exc),
                ).as_dict()
            ]

    async def fetch_relevant_memories(
        self,
        *,
        query: str,
        limit: int,
        source: str = "long_term_memory",
    ) -> list[dict]:
        try:
            return await self.memory_service.get_relevant_memories(
                query=query,
                limit=limit,
            )
        except Exception as exc:
            LOGGER.warning("rex_memory_fetch_failed source=%s", source)
            return [
                ContextFetchError(
                    source=source,
                    message=self.safe_error_message(exc),
                ).as_dict()
            ]

    async def fetch_relevant_chat_excerpts(
        self,
        *,
        query: str,
        limit: int,
        exclude_conversation_id: Optional[str],
    ) -> list[dict]:
        search_messages = getattr(self.memory_service, "search_messages", None)
        if search_messages is None:
            return [
                ContextFetchError(
                    source="chat_search",
                    message="Past chat search is unavailable.",
                ).as_dict()
            ]
        try:
            messages_by_id: dict[str, dict] = {}
            query_modes: set[str] = set()
            attempted_queries: list[dict] = []
            scanned_messages = 0
            for search_query, query_mode in self.past_chat_search_queries(query):
                query_modes.add(query_mode)
                attempted_queries.append(
                    {
                        "query": search_query,
                        "mode": query_mode,
                    }
                )
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
            LOGGER.warning("rex_memory_fetch_failed source=chat_search")
            return [
                ContextFetchError(
                    source="chat_search",
                    message=self.safe_error_message(exc),
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
                "partial": False,
                "query_modes": sorted(query_modes),
                "queries": attempted_queries,
            },
            *excerpts,
        ]

    def past_chat_search_queries(self, query: str) -> list[tuple[str, str]]:
        return [
            (item.query, item.mode)
            for item in self.chat_search_ranking.build_queries(
                query,
                inventory_query=MEMORY_INVENTORY_QUERY,
                max_terms=10,
            )
        ]

    def scored_chat_message(
        self,
        query: str,
        message: dict,
        *,
        query_mode: str,
    ) -> dict:
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

    def recall_search_terms(self, query: str, *, max_terms: int) -> list[str]:
        return self.chat_search_ranking.expand_terms(query, max_terms=max_terms)

    def normalize_recall_search_term(self, term: str) -> str:
        return self.chat_search_ranking.normalize_term(term)

    def simple_recall_term_variants(self, term: str) -> tuple[str, ...]:
        return self.chat_search_ranking.simple_term_variants(term)

    def subject_only_search_query(self, normalized_query: str) -> str:
        return self.chat_search_ranking.subject_only_query(normalized_query)

    async def chat_conversation_excerpts(
        self,
        matched_messages: list[dict],
        *,
        limit: int,
    ) -> list[dict]:
        grouped: dict[str, list[dict]] = {}
        without_conversation = []
        for message in sorted(matched_messages, key=self.chat_search_candidate_rank):
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
            if self.is_chat_search_no_result_message(message):
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
            if not self.is_chat_search_user_content_message(message):
                continue
            if await self.chat_excerpt_was_rejected(message):
                return True
        return False

    async def conversation_cluster_context(
        self,
        conversation_id: str,
        matched_messages: list[dict],
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
                if self.is_chat_search_no_result_message(message):
                    continue
                if message_id:
                    seen_ids.add(message_id)
                context_messages.append(message)
        return context_messages

    async def chat_excerpt_context(
        self,
        message: dict,
        *,
        before: int = CHAT_EXCERPT_CONTEXT_BEFORE,
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
            if self.is_chat_search_no_result_message(message):
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
            self.is_chat_search_user_content_message(message)
            for message in messages
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

        following_messages = conversation_messages[
            message_index + 1 : message_index + 7
        ]
        return any(
            self.is_memory_rejection_message(item) for item in following_messages
        )

    def message_index(
        self,
        conversation_messages: list[dict],
        message_id: str,
    ) -> Optional[int]:
        for index, item in enumerate(conversation_messages):
            if str(item.get("id") or "") == message_id:
                return index
        return None

    def is_memory_rejection_message(self, message: dict) -> bool:
        content = str(message.get("content") or "").strip().lower()
        if not content:
            return False
        return any(marker in content for marker in MEMORY_REJECTION_MARKERS)

    def is_chat_search_no_result_message(self, message: dict) -> bool:
        content = str(message.get("content") or "").strip().lower()
        if not content:
            return False
        return any(marker in content for marker in CHAT_SEARCH_NO_RESULT_MARKERS)

    def is_chat_search_user_content_message(self, message: dict) -> bool:
        if str(message.get("role") or "") != "user":
            return False
        content = str(message.get("content") or "").strip().lower()
        if not content or self.is_chat_search_no_result_message(message):
            return False
        if any(
            marker in content
            for marker in (
                "do you know",
                "do you remember",
                "can you search",
                "search old",
                "search the old",
                "check old",
                "check the old",
                "look into the chats",
                "looked through",
                "double checked",
                "double-checked",
                "pretty sure",
                "i told you",
                "already told",
                "have access to the chat",
            )
        ):
            return False
        return True

    def with_chat_search_results(
        self,
        structured_context: dict,
        chat_search_results: list[dict],
    ) -> dict:
        if not chat_search_results:
            return structured_context
        return {
            **structured_context,
            "chat_search_results": chat_search_results,
        }

    def merge_memories(self, *memory_groups: list[dict]) -> list[dict]:
        merged: list[dict] = []
        seen_ids: set[str] = set()
        for memories in memory_groups:
            for memory in memories:
                memory_id = str(memory.get("id") or "")
                if memory_id and memory_id in seen_ids:
                    continue
                if memory_id:
                    seen_ids.add(memory_id)
                merged.append(memory)
        return merged[:8]

    async def empty_list(self) -> list[dict]:
        return []

    def context_items(
        self,
        items: list[dict],
        failures: list[dict],
        statuses: Optional[list[dict]] = None,
    ) -> list[dict]:
        clean_items = []
        for item in items:
            if item.get(CONTEXT_ERROR_KEY) is True:
                failures.append(
                    {
                        "source": item.get("source") or "memory",
                        "message": item.get("message") or "Memory lookup failed.",
                    }
                )
                continue
            if item.get(CONTEXT_STATUS_KEY) is True:
                if statuses is not None:
                    statuses.append(
                        {
                            key: value
                            for key, value in item.items()
                            if key != CONTEXT_STATUS_KEY
                        }
                    )
                continue
            clean_items.append(item)
        return clean_items

    def with_memory_status(
        self,
        structured_context: dict,
        failures: list[dict],
        *,
        attempted_sources: dict,
        source_statuses: Optional[list[dict]] = None,
    ) -> dict:
        attempted_memory_sources = {
            key: value
            for key, value in attempted_sources.items()
            if key != "recent_messages"
        }
        if not failures and not any(attempted_memory_sources.values()):
            return structured_context

        status = {
            "state": "degraded" if failures else "ready",
            "message": (
                "Some memory sources could not be searched."
                if failures
                else "Memory sources searched successfully."
            ),
            "attempted_sources": attempted_sources,
            "failures": failures,
            "source_statuses": source_statuses or [],
        }
        existing = structured_context.get("memory_status")
        if isinstance(existing, dict):
            existing_failures = existing.get("failures")
            if isinstance(existing_failures, list):
                status["failures"] = [*existing_failures, *status["failures"]]
            existing_attempted = existing.get("attempted_sources")
            if isinstance(existing_attempted, dict):
                status["attempted_sources"] = {
                    **existing_attempted,
                    **status["attempted_sources"],
                }
            existing_statuses = existing.get("source_statuses")
            if isinstance(existing_statuses, list):
                status["source_statuses"] = [
                    *existing_statuses,
                    *status["source_statuses"],
                ]
            if status["failures"]:
                status["state"] = "degraded"
                status["message"] = "Some memory sources could not be searched."
        if not structured_context:
            return {"memory_status": status}
        return {**structured_context, "memory_status": status}

    def safe_error_message(self, exc: Exception) -> str:
        message = str(exc).strip()
        return message or exc.__class__.__name__

    def memory_retrieval_query(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> str:
        normalized = " ".join(str(message or "").lower().split())
        if self.is_memory_inventory_query(normalized):
            return MEMORY_INVENTORY_QUERY
        if self.is_contextual_memory_followup(normalized):
            subject = self.recent_memory_subject(conversation_history)
            if subject:
                return f"{subject} {message}".strip()
        return message

    def is_memory_inventory_query(self, normalized_message: str) -> bool:
        broad_inventory_questions = {
            "what do you know",
            "what do you know about me",
            "what do you remember",
            "what do you remember about me",
            "what does clarity know",
            "what does clarity know about me",
            "what information do you have",
            "what information do you have about me",
            "what have you saved",
            "what do you have saved",
            "what do you have saved about me",
            "what rex knows",
            "what does rex know",
            "what does rex know about me",
            "what does rex remember",
            "what does rex remember about me",
            "what does hackrex know",
            "what does hackrex know about me",
            "what information do you know",
            "what information do you know about me",
        }
        normalized = normalized_message.rstrip("?.! ")
        if normalized not in broad_inventory_questions:
            return False
        return " about " not in f" {normalized} " or normalized.endswith(" about me")

    def is_contextual_memory_followup(self, normalized_message: str) -> bool:
        stripped = normalized_message.strip("?.! ")
        if stripped in {
            "chat",
            "chats",
            "the chat",
            "the chats",
            "conversation",
            "conversations",
            "the conversation",
            "the conversations",
        }:
            return True
        return any(
            phrase in normalized_message
            for phrase in (
                "check old chat",
                "check old chats",
                "check chat",
                "check chats",
                "check the chat",
                "check the chats",
                "old chat",
                "old chats",
                "old conversation",
                "old conversations",
                "anything else",
                "what else",
                "about that",
                "past chat",
                "past chats",
                "past conversation",
                "past conversations",
                "previous chat",
                "previous chats",
                "previous conversation",
                "previous conversations",
                "search chat",
                "search chats",
                "search your chat",
                "search your chats",
                "search conversations",
            )
        )

    def should_force_chat_recall_search(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> bool:
        normalized = " ".join(str(message or "").lower().split())
        stripped = normalized.strip("?.! ")
        if not stripped:
            return False
        if self.is_memory_inventory_query(normalized):
            return True
        if self.is_contextual_memory_followup(normalized):
            return True

        recall_phrases = (
            "all chats",
            "any chats",
            "anything about",
            "can you find",
            "can you search",
            "check chat",
            "check chats",
            "did i mention",
            "did i say",
            "do you know anything",
            "do you know about",
            "do you remember",
            "find chats",
            "from chats",
            "have i mentioned",
            "have i said",
            "have i told you",
            "old chat",
            "old chats",
            "previous chat",
            "previous chats",
            "search chat",
            "search chats",
            "what did i say",
            "what did i tell you",
            "what do you know about",
            "what do you remember about",
            "what games do i play",
            "what have i said",
            "what have i told you",
            "what was the",
            "what were the",
        )
        if any(phrase in normalized for phrase in recall_phrases):
            return True

        if re.search(r"\bwhat\s+.+\b(?:did|do)\s+i\s+(?:play|buy|want|mention|say|tell)", normalized):
            return True

        if conversation_history and any(
            term in normalized
            for term in (
                "that",
                "else",
                "it",
                "her",
                "him",
                "them",
                "this",
            )
        ):
            return bool(self.recent_memory_subject(conversation_history))

        return False

    def chat_search_candidate_rank(self, message: dict) -> tuple[int, str]:
        if self.is_chat_search_user_content_message(message):
            priority = 0
        elif str(message.get("role") or "") == "assistant":
            priority = 1
        else:
            priority = 2
        timestamp = str(message.get("timestamp") or "")
        score = float(message.get("_chat_search_score") or 0)
        return (priority, f"{9999 - score:09.4f}", timestamp)

    def recent_memory_subject(self, conversation_history: list[dict]) -> str:
        for message in reversed(conversation_history[-8:]):
            if message.get("role") != "user":
                continue
            content = str(message.get("content") or "").strip()
            if not content:
                continue
            normalized = " ".join(content.lower().split())
            if self.is_contextual_memory_followup(normalized):
                continue
            if any(
                phrase in normalized
                for phrase in (
                    "do you know",
                    "do you remember",
                    "did i mention",
                    "did i say",
                    "anything about",
                    "talking about",
                    "information about",
                    "what do you know about",
                    "what do you remember about",
                )
            ):
                return content
        return ""

    async def timed_fetch(self, name: str, awaitable, timings_ms: dict[str, int]):
        started = time.perf_counter()
        result = await awaitable
        timings_ms[name] = self.elapsed_ms(started)
        return result

    async def fetch_structured_context(
        self,
        message: str,
        *,
        include_structured_memory: bool = True,
        include_goal_context: bool = True,
    ) -> dict:
        structured_context: dict = {}
        if include_structured_memory:
            get_structured_context = getattr(
                self.memory_service,
                "get_structured_memory_context",
                None,
            )
            if get_structured_context is not None:
                try:
                    structured_context = await get_structured_context(message)
                except Exception as exc:
                    LOGGER.warning("rex_memory_fetch_failed source=structured_memory")
                    structured_context = {
                        "memory_status": {
                            "state": "degraded",
                            "message": "Structured memory could not be searched.",
                            "attempted_sources": {
                                "structured_memory": True,
                            },
                            "failures": [
                                {
                                    "source": "structured_memory",
                                    "message": self.safe_error_message(exc),
                                }
                            ],
                        }
                    }

        goal_context = {}
        if include_goal_context:
            goal_context = await self.goal_context_service.fetch_goal_context(
                self.memory_service,
                message,
            )
        return self.goal_context_service.merge_structured_context(
            structured_context,
            goal_context,
        )

    def build_prompt_messages(
        self,
        *,
        message: str,
        conversation_id: str,
        conversation_history: list[dict],
        long_term_memory: list[dict],
        structured_context: dict,
        accountability_signals: list,
        file_text: Optional[str],
        time_context: dict,
        financial_context: Optional[dict],
        max_context_characters: Optional[int] = None,
    ) -> list[dict]:
        last_message_timestamp = self.last_message_timestamp(conversation_history)
        return self.prompt_service.build_messages(
            user_message=message,
            recent_messages=conversation_history,
            relevant_memories=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            file_context=file_text,
            conversation_metadata={
                "id": conversation_id,
                "timestamp": self.conversation_timestamp(conversation_history),
                "last_message_timestamp": last_message_timestamp,
            },
            time_context=time_context,
            financial_context=financial_context,
            max_context_characters=max_context_characters,
        )

    def current_time_context(self, conversation_history: list[dict]) -> dict:
        return self.time_context_service.current_context(
            previous_timestamp=self.last_message_timestamp(conversation_history),
        )

    async def accountability_signals(
        self,
        *,
        message: str,
        time_context: dict,
        long_term_memory: list[dict],
        structured_context: dict,
    ) -> list:
        if self.accountability_service is None:
            return []

        try:
            return await self.accountability_service.analyze_signals(
                message=message,
                time_context=time_context,
                personal_rules=structured_context.get("personal_rules") or [],
                commitments=structured_context.get("commitments") or [],
                plans=structured_context.get("plans") or [],
                plan_milestones=structured_context.get("plan_milestones") or [],
                entity_events=structured_context.get("entity_events") or [],
                relevant_memories=long_term_memory,
            )
        except Exception:
            return []

    def should_analyze_accountability(
        self,
        intent_decision: Optional[RexIntentDecision],
    ) -> bool:
        return (
            True
            if intent_decision is None
            else intent_decision.should_load_accountability
        )

    def log_context_fetch(
        self,
        *,
        intent_decision: Optional[RexIntentDecision],
        conversation_id: Optional[str],
        loaded: dict,
        counts: dict,
        timings_ms: dict[str, int],
        total_ms: int,
    ) -> None:
        payload = {
            "conversation_id": conversation_id,
            "intent": (
                intent_decision.intent.value
                if intent_decision is not None
                else "legacy"
            ),
            "loaded": loaded,
            "counts": counts,
            "timings_ms": timings_ms,
            "total_ms": total_ms,
        }
        LOGGER.info("rex_context_fetch %s", json.dumps(payload, sort_keys=True))

    def elapsed_ms(self, started: float) -> int:
        return int((time.perf_counter() - started) * 1000)

    def _load_long_term_memory(
        self,
        intent_decision: Optional[RexIntentDecision],
    ) -> bool:
        return (
            True
            if intent_decision is None
            else intent_decision.should_load_long_term_memory
        )

    def _load_profile_memory(
        self,
        intent_decision: Optional[RexIntentDecision],
    ) -> bool:
        return (
            True
            if intent_decision is None
            else intent_decision.should_load_profile_memory
        )

    def _load_structured_memory(
        self,
        intent_decision: Optional[RexIntentDecision],
    ) -> bool:
        return (
            True
            if intent_decision is None
            else intent_decision.should_load_structured_memory
        )

    def _load_goal_context(
        self,
        intent_decision: Optional[RexIntentDecision],
    ) -> bool:
        return (
            True
            if intent_decision is None
            else intent_decision.should_load_goal_context
        )

    def last_message_timestamp(self, conversation_history: list[dict]) -> Optional[str]:
        if not conversation_history:
            return None
        timestamp = conversation_history[-1].get("timestamp")
        return str(timestamp) if timestamp else None

    def conversation_timestamp(self, conversation_history: list[dict]) -> Optional[str]:
        if not conversation_history:
            return None
        timestamp = conversation_history[0].get("timestamp")
        return str(timestamp) if timestamp else None
