import asyncio
import json
import logging
import re
import time
from dataclasses import dataclass
from typing import Optional

from app.services.accountability_service import AccountabilityService
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
PAST_CHAT_SEARCH_SCAN_LIMIT = 50
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
    ) -> None:
        self.memory_service = memory_service
        self.prompt_service = prompt_service or PromptService()
        self.time_context_service = time_context_service or TimeContextService()
        self.accountability_service = accountability_service or AccountabilityService()
        self.goal_context_service = goal_context_service or GoalContextService()

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
        load_long_term_memory = self._load_long_term_memory(intent_decision)
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
        if load_long_term_memory and conversation_id is None:
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
            )
            structured_context = self.with_memory_status(
                structured_context,
                memory_failures,
                attempted_sources={
                    "long_term_memory": load_long_term_memory,
                    "profile_memory": load_profile_memory,
                    "chat_search": load_long_term_memory,
                    "structured_memory": load_structured_memory,
                },
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
                    "chat_search": load_long_term_memory,
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

        if load_long_term_memory:
            conversation_history = await self.timed_fetch(
                "recent_messages",
                self.fetch_recent_messages(conversation_id, limit=20),
                timings_ms,
            )
            conversation_history = self.context_items(
                conversation_history,
                memory_failures,
            )
            memory_query = self.memory_retrieval_query(
                message,
                conversation_history=conversation_history,
            )
            long_term_memory_task = self.timed_fetch(
                "long_term_memory",
                self.fetch_relevant_memories(query=memory_query, limit=8),
                timings_ms,
            )
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
            conversation_history = await self.timed_fetch(
                "recent_messages",
                self.fetch_recent_messages(conversation_id, limit=20),
                timings_ms,
            )
            conversation_history = self.context_items(
                conversation_history,
                memory_failures,
            )
            long_term_memory_task = self.empty_list()
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
        )
        structured_context = self.with_memory_status(
            structured_context,
            memory_failures,
            attempted_sources={
                "recent_messages": True,
                "long_term_memory": load_long_term_memory,
                "profile_memory": load_profile_memory,
                "chat_search": load_long_term_memory,
                "structured_memory": load_structured_memory,
            },
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
                "chat_search": load_long_term_memory,
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
            for search_query in self.past_chat_search_queries(query):
                messages = await search_messages(
                    search_query,
                    limit=max(limit, PAST_CHAT_SEARCH_SCAN_LIMIT),
                    exclude_conversation_id=exclude_conversation_id,
                )
                for message in messages:
                    message_id = str(message.get("id") or "")
                    if not message_id:
                        continue
                    messages_by_id.setdefault(message_id, message)
        except Exception as exc:
            LOGGER.warning("rex_memory_fetch_failed source=chat_search")
            return [
                ContextFetchError(
                    source="chat_search",
                    message=self.safe_error_message(exc),
                ).as_dict()
            ]

        excerpts = []
        for message in messages_by_id.values():
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
                    "relevance_reason": "Matched relevant chat history.",
                }
            )
            if len(excerpts) >= limit:
                break
        return excerpts

    def past_chat_search_queries(self, query: str) -> list[str]:
        normalized = " ".join(str(query or "").lower().split())
        if str(query or "") == MEMORY_INVENTORY_QUERY:
            return [query]
        queries = [query]
        has_birthday_subject = "birthday" in normalized
        has_mom_subject = bool(re.search(r"\b(?:mom|mother|mum|mama)\b", normalized))
        has_parent_subject = has_mom_subject or bool(
            re.search(r"\b(?:dad|father|papa|parent|parents)\b", normalized)
        )
        if has_mom_subject and has_birthday_subject:
            queries.extend(
                [
                    "mom mother birthday reminder money send her 10th 18th",
                    "mom birthday",
                    "send her money birthday",
                    "mother birthday",
                    "birthday 18th 10th",
                    "mom",
                ]
            )
        elif has_mom_subject:
            queries.extend(["mom mother mum mama", "mom"])
        elif has_parent_subject:
            queries.extend(
                [
                    "parent parents family mother father mom dad",
                ]
            )
        elif has_birthday_subject:
            queries.append("birthday reminder important date")
        subject_query = self.subject_only_search_query(normalized)
        if subject_query:
            queries.append(subject_query)

        unique_queries = []
        for item in queries:
            cleaned = str(item or "").strip()
            if cleaned and cleaned not in unique_queries:
                unique_queries.append(cleaned)
        return unique_queries

    def subject_only_search_query(self, normalized_query: str) -> str:
        """Extract the user's target subject for chat search.

        Message search is keyword based. A focused subject query gives old chats
        one more chance to surface relevant history without relying on broad
        question words like "know" or "remember".
        """

        match = re.search(
            r"\b(?:about|for|with)\s+(?:my\s+)?(?P<subject>[a-z0-9'\s]{3,60})",
            normalized_query,
        )
        if match is None:
            return ""
        subject = re.sub(
            r"\b(?:old|past|previous|chat|chats|conversation|conversations|"
            r"anything|information|details|memory|memories|saved|know|remember)\b",
            " ",
            match.group("subject"),
        )
        subject = re.sub(r"[^a-z0-9'\s]+", " ", subject)
        subject = re.sub(r"\s+", " ", subject).strip()
        if len(subject) < 3:
            return ""
        return subject

    async def chat_excerpt_context(
        self,
        message: dict,
        *,
        before: int = 2,
        after: int = 3,
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
            content = str(message.get("content") or "").strip()
            if not content:
                continue
            role = str(message.get("role") or "message")
            lines.append(f"- {role}: {content}")
        return "\n".join(lines)

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
            clean_items.append(item)
        return clean_items

    def with_memory_status(
        self,
        structured_context: dict,
        failures: list[dict],
        *,
        attempted_sources: dict,
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
