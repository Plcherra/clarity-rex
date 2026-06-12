import asyncio
import json
import logging
import time
from typing import Optional

from app.services.accountability_service import AccountabilityService
from app.services.goal_context_service import GoalContextService
from app.services.prompt_service import PromptService
from app.services.rex_brain_chat_service import RexBrainChatService
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
PAST_CHAT_MEMORY_LIMIT = 4
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


class ChatContextService:
    def __init__(
        self,
        memory_service,
        *,
        prompt_service: Optional[PromptService] = None,
        time_context_service: Optional[TimeContextService] = None,
        accountability_service: Optional[AccountabilityService] = None,
        goal_context_service: Optional[GoalContextService] = None,
        rex_brain_chat_service: Optional[RexBrainChatService] = None,
    ) -> None:
        self.memory_service = memory_service
        self.prompt_service = prompt_service or PromptService()
        self.time_context_service = time_context_service or TimeContextService()
        self.accountability_service = accountability_service or AccountabilityService()
        self.goal_context_service = goal_context_service or GoalContextService()
        self.rex_brain_chat_service = rex_brain_chat_service or RexBrainChatService()

    async def fetch_prompt_context(
        self,
        *,
        message: str,
        conversation_id: Optional[str],
        intent_decision: Optional[RexIntentDecision] = None,
    ) -> tuple[list[dict], list[dict], dict]:
        fetch_started = time.perf_counter()
        timings_ms: dict[str, int] = {}
        load_long_term_memory = self._load_long_term_memory(intent_decision)
        load_profile_memory = self._load_profile_memory(intent_decision)
        load_structured_memory = self._load_structured_memory(intent_decision)
        load_goal_context = self._load_goal_context(intent_decision)
        memory_query = self.memory_retrieval_query(message)
        load_profile_memory = load_profile_memory and memory_query not in {
            PROFILE_MEMORY_QUERY,
            MEMORY_INVENTORY_QUERY,
        }

        long_term_memory_task = (
            self.timed_fetch(
                "long_term_memory",
                self.fetch_relevant_memories(query=memory_query, limit=8),
                timings_ms,
            )
            if load_long_term_memory
            else self.empty_list()
        )
        profile_memory_task = (
            self.timed_fetch(
                "profile_memory",
                self.fetch_relevant_memories(
                    query=PROFILE_MEMORY_QUERY,
                    limit=PROFILE_MEMORY_LIMIT,
                ),
                timings_ms,
            )
            if load_profile_memory
            else self.empty_list()
        )
        past_chat_memory_task = (
            self.timed_fetch(
                "past_chat_memory",
                self.fetch_relevant_chat_excerpts(
                    query=memory_query,
                    limit=PAST_CHAT_MEMORY_LIMIT,
                    exclude_conversation_id=conversation_id,
                ),
                timings_ms,
            )
            if load_long_term_memory
            else self.empty_list()
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
                long_term_memory,
                profile_memory,
                past_chat_memory,
                structured_context,
            ) = await asyncio.gather(
                long_term_memory_task,
                profile_memory_task,
                past_chat_memory_task,
                structured_context_task,
            )
            merged_memory = self.merge_memories(
                long_term_memory,
                profile_memory,
                past_chat_memory,
            )
            self.log_context_fetch(
                intent_decision=intent_decision,
                conversation_id=None,
                loaded={
                    "recent_messages": False,
                    "long_term_memory": load_long_term_memory,
                    "profile_memory": load_profile_memory,
                    "past_chat_memory": load_long_term_memory,
                    "structured_memory": load_structured_memory,
                    "goal_context": load_goal_context,
                },
                counts={
                    "recent_messages": 0,
                    "long_term_memory": len(merged_memory),
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

        (
            conversation_history,
            long_term_memory,
            profile_memory,
            past_chat_memory,
            structured_context,
        ) = await asyncio.gather(
            self.timed_fetch(
                "recent_messages",
                self.fetch_recent_messages(conversation_id, limit=20),
                timings_ms,
            ),
            long_term_memory_task,
            profile_memory_task,
            past_chat_memory_task,
            structured_context_task,
        )
        merged_memory = self.merge_memories(
            long_term_memory,
            profile_memory,
            past_chat_memory,
        )
        self.log_context_fetch(
            intent_decision=intent_decision,
            conversation_id=conversation_id,
            loaded={
                "recent_messages": True,
                "long_term_memory": load_long_term_memory,
                "profile_memory": load_profile_memory,
                "past_chat_memory": load_long_term_memory,
                "structured_memory": load_structured_memory,
                "goal_context": load_goal_context,
            },
            counts={
                "recent_messages": len(conversation_history),
                "long_term_memory": len(merged_memory),
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
        except Exception:
            return []

    async def fetch_relevant_memories(
        self,
        *,
        query: str,
        limit: int,
    ) -> list[dict]:
        try:
            return await self.memory_service.get_relevant_memories(
                query=query,
                limit=limit,
            )
        except Exception:
            return []

    async def fetch_relevant_chat_excerpts(
        self,
        *,
        query: str,
        limit: int,
        exclude_conversation_id: Optional[str],
    ) -> list[dict]:
        search_messages = getattr(self.memory_service, "search_messages", None)
        if search_messages is None:
            return []
        try:
            messages = await search_messages(
                query,
                limit=limit,
                exclude_conversation_id=exclude_conversation_id,
            )
        except Exception:
            return []

        excerpts = []
        for message in messages:
            content = str(message.get("content") or "").strip()
            if not content:
                continue
            if await self.chat_excerpt_was_rejected(message):
                continue
            role = str(message.get("role") or "message")
            excerpts.append(
                {
                    "id": f"chat-{message.get('id')}",
                    "memory_type": "chat_excerpt",
                    "content": f"Past chat {role}: {content}",
                    "importance": 3,
                    "created_at": message.get("timestamp"),
                    "relevance_reason": "Matched relevant past conversation.",
                }
            )
        return excerpts

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

    def memory_retrieval_query(self, message: str) -> str:
        normalized = " ".join(str(message or "").lower().split())
        if self.is_memory_inventory_query(normalized):
            return MEMORY_INVENTORY_QUERY
        return message

    def is_memory_inventory_query(self, normalized_message: str) -> bool:
        broad_inventory_questions = {
            "what do you know",
            "what do you remember",
            "what does clarity know",
            "what information do you have",
            "what have you saved",
            "what do you have saved",
            "what rex knows",
        }
        normalized = normalized_message.rstrip("?.! ")
        if normalized not in broad_inventory_questions:
            return False
        return " about " not in f" {normalized} "

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
                except Exception:
                    structured_context = {}

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

    def build_prompt_messages_for_rex_brain(
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
        rex_brain_plan: dict,
    ) -> list[dict]:
        prompt_context = self.rex_brain_chat_service.prompt_context(
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            financial_context=financial_context,
            rex_brain_plan=rex_brain_plan,
        )
        return self.build_prompt_messages(
            message=message,
            conversation_id=conversation_id,
            conversation_history=prompt_context["conversation_history"],
            long_term_memory=prompt_context["long_term_memory"],
            structured_context=prompt_context["structured_context"],
            accountability_signals=prompt_context["accountability_signals"],
            file_text=file_text,
            time_context=time_context,
            financial_context=prompt_context["financial_context"],
            max_context_characters=self.rex_brain_chat_service.prompt_context_limit(
                rex_brain_plan,
            ),
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
