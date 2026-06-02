import asyncio
from typing import Optional

from app.services.accountability_service import AccountabilityService
from app.services.goal_context_service import GoalContextService
from app.services.prompt_service import PromptService
from app.services.rex_brain_chat_service import RexBrainChatService
from app.services.time_context_service import TimeContextService

PROFILE_MEMORY_QUERY = (
    "user profile location timezone where I live state city home current time "
    "important identity facts birthdays family important dates preferences"
)
PROFILE_MEMORY_LIMIT = 4


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
        self.rex_brain_chat_service = (
            rex_brain_chat_service or RexBrainChatService()
        )

    async def fetch_prompt_context(
        self,
        *,
        message: str,
        conversation_id: Optional[str],
    ) -> tuple[list[dict], list[dict], dict]:
        long_term_memory_task = self.fetch_relevant_memories(
            query=message,
            limit=8,
        )
        profile_memory_task = self.fetch_relevant_memories(
            query=PROFILE_MEMORY_QUERY,
            limit=PROFILE_MEMORY_LIMIT,
        )
        structured_context_task = self.fetch_structured_context(message)
        if conversation_id is None:
            (
                long_term_memory,
                profile_memory,
                structured_context,
            ) = await asyncio.gather(
                long_term_memory_task,
                profile_memory_task,
                structured_context_task,
            )
            return (
                [],
                self.merge_memories(long_term_memory, profile_memory),
                structured_context,
            )

        (
            conversation_history,
            long_term_memory,
            profile_memory,
            structured_context,
        ) = await asyncio.gather(
            self.fetch_recent_messages(conversation_id, limit=20),
            long_term_memory_task,
            profile_memory_task,
            structured_context_task,
        )
        return (
            conversation_history,
            self.merge_memories(long_term_memory, profile_memory),
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

    async def fetch_structured_context(self, message: str) -> dict:
        structured_context: dict = {}
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
