import time
from typing import Callable, Optional

from app.services.memory_context_status import MemoryContextAssembler
from app.services.prompt_service import PromptService
from app.services.rex_intent_router import RexIntentDecision


class ChatPromptContextBuilder:
    """Assembles fetched context into the shape PromptService expects."""

    def __init__(
        self,
        *,
        memory_context: MemoryContextAssembler,
        prompt_service: PromptService,
    ) -> None:
        self.memory_context = memory_context
        self.prompt_service = prompt_service

    def assemble_prompt_context(
        self,
        *,
        conversation_history: list[dict],
        raw_long_term_memory: list[dict],
        raw_profile_memory: list[dict],
        raw_chat_search_results: list[dict],
        structured_context: dict,
        intent_decision: Optional[RexIntentDecision],
        conversation_id: Optional[str],
        loaded: dict,
        attempted_sources: dict,
        timings_ms: dict[str, int],
        fetch_started: float,
        log_context_fetch: Callable[..., None],
        initial_failures: Optional[list[dict]] = None,
    ) -> tuple[list[dict], list[dict], dict]:
        memory_failures = list(initial_failures or [])
        context_statuses: list[dict] = []
        long_term_memory = self.memory_context.context_items(
            raw_long_term_memory,
            memory_failures,
        )
        profile_memory = self.memory_context.context_items(
            raw_profile_memory,
            memory_failures,
        )
        chat_search_results = self.memory_context.context_items(
            raw_chat_search_results,
            memory_failures,
            context_statuses,
        )
        structured_context = self.memory_context.with_memory_status(
            structured_context,
            memory_failures,
            attempted_sources=attempted_sources,
            source_statuses=context_statuses,
        )
        structured_context = self.memory_context.with_chat_search_results(
            structured_context,
            chat_search_results,
        )
        merged_memory = self.memory_context.merge_memories(
            long_term_memory,
            profile_memory,
        )
        merged_memory = self.memory_context.prefer_entities_over_flat_memories(
            merged_memory,
            structured_context,
        )
        memory_status = structured_context.get("memory_status")
        if isinstance(memory_status, dict):
            memory_status["saved_knowledge_count"] = len(merged_memory)
        log_context_fetch(
            intent_decision=intent_decision,
            conversation_id=conversation_id,
            loaded=loaded,
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

    def elapsed_ms(self, started: float) -> int:
        return int((time.perf_counter() - started) * 1000)
