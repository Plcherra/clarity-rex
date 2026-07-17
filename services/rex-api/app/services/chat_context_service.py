import asyncio
import json
import logging
import time
from typing import Optional

from app.services.accountability_budget_risk import financial_budget_performance
from app.services.accountability_service import AccountabilityService
from app.services.chat_recall_service import (
    CHAT_SEARCH_RESULTS_LIMIT,
    ChatRecallService,
)
from app.services.chat_context_fetcher import ChatContextLoadPlanner
from app.services.chat_context_recall import ChatContextRecallPolicy
from app.services.chat_prompt_context_builder import ChatPromptContextBuilder
from app.services.chat_search_ranking import ChatSearchRanking
from app.services.goal_context_service import GoalContextService
from app.services.memory_context_status import MemoryContextAssembler
from app.services.open_thread_context_loader import load_open_threads_context
from app.services.prompt_inventory_context import format_inventory_context
from app.services.prompt_service import PromptService
from app.services.saved_knowledge_overview_service import SavedKnowledgeOverviewService
from app.services.recall_intent_helper import (
    MEMORY_INVENTORY_QUERY,
    PROFILE_MEMORY_LIMIT,
    PROFILE_MEMORY_QUERY,
)
from app.services.rex_channel import RexBrainChannel
from app.services.time_context_service import TimeContextService


LOGGER = logging.getLogger("rex.context")


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
        self.recall_policy = ChatContextRecallPolicy()
        self.load_planner = ChatContextLoadPlanner(self.recall_policy)
        self.memory_context = MemoryContextAssembler()
        self.prompt_context_builder = ChatPromptContextBuilder(
            memory_context=self.memory_context,
            prompt_service=self.prompt_service,
        )
        self.chat_recall_service = ChatRecallService(
            memory_service,
            chat_search_ranking=self.chat_search_ranking,
        )
        self.saved_knowledge_overview = SavedKnowledgeOverviewService(memory_service)

    async def fetch_prompt_context(
        self,
        *,
        message: str,
        conversation_id: Optional[str],
        channel: RexBrainChannel = RexBrainChannel.CHAT,
    ) -> tuple[list[dict], list[dict], dict]:
        fetch_started = time.perf_counter()
        timings_ms: dict[str, int] = {}
        initial_plan = self.load_planner.initial_plan(
            message=message,
            channel=channel,
        )
        load_plan = initial_plan

        long_term_memory_task = None
        if load_plan.load_long_term_memory and conversation_id is None:
            long_term_memory_task = self.timed_fetch(
                "long_term_memory",
                self.memory_context.fetch_relevant_memories(
                    self.memory_service,
                    query=load_plan.memory_query,
                    limit=8,
                ),
                timings_ms,
            )
        profile_memory_task = None
        if load_plan.load_profile_memory:
            profile_memory_task = self.timed_fetch(
                "profile_memory",
                self.memory_context.fetch_relevant_memories(
                    self.memory_service,
                    query=PROFILE_MEMORY_QUERY,
                    limit=PROFILE_MEMORY_LIMIT,
                    source="profile_memory",
                ),
                timings_ms,
            )
        chat_search_results_task = None
        if load_plan.load_chat_search and conversation_id is None:
            chat_search_results_task = self.timed_fetch(
                "chat_search",
                self.chat_recall_service.fetch_relevant_chat_excerpts(
                    query=load_plan.recall_query or message,
                    raw_query=message,
                    limit=CHAT_SEARCH_RESULTS_LIMIT,
                    exclude_conversation_id=conversation_id,
                ),
                timings_ms,
            )
        if conversation_id is None:
            structured_context_task = self.timed_fetch(
                "structured_context",
                self._fetch_structured_context(
                    message,
                    load_plan=load_plan,
                ),
                timings_ms,
            )
            (
                raw_long_term_memory,
                raw_profile_memory,
                raw_chat_search_results,
                structured_context,
            ) = await asyncio.gather(
                long_term_memory_task or self.empty_list(),
                profile_memory_task or self.empty_list(),
                chat_search_results_task or self.empty_list(),
                structured_context_task,
            )
            return self._assemble_prompt_context(
                conversation_history=[],
                raw_long_term_memory=raw_long_term_memory,
                raw_profile_memory=raw_profile_memory,
                raw_chat_search_results=raw_chat_search_results,
                structured_context=structured_context,
                conversation_id=None,
                loaded={
                    "recent_messages": False,
                    **load_plan.loaded,
                },
                attempted_sources={
                    **load_plan.attempted_sources,
                },
                timings_ms=timings_ms,
                fetch_started=fetch_started,
            )

        conversation_history = await self.timed_fetch(
            "recent_messages",
            self.memory_context.fetch_recent_messages(
                self.memory_service,
                conversation_id,
                limit=20,
            ),
            timings_ms,
        )
        memory_failures: list[dict] = []
        conversation_history = self.memory_context.context_items(
            conversation_history,
            memory_failures,
        )
        load_plan = self.load_planner.after_history_plan(
            message=message,
            conversation_history=conversation_history,
            initial_plan=initial_plan,
            channel=channel,
        )

        long_term_memory_task = (
            self.timed_fetch(
                "long_term_memory",
                self.memory_context.fetch_relevant_memories(
                    self.memory_service,
                    query=load_plan.memory_query,
                    limit=8,
                ),
                timings_ms,
            )
            if load_plan.load_long_term_memory
            else self.empty_list()
        )
        chat_search_results_task = (
            self.timed_fetch(
                "chat_search",
                self.chat_recall_service.fetch_relevant_chat_excerpts(
                    query=load_plan.recall_query or message,
                    raw_query=message,
                    limit=CHAT_SEARCH_RESULTS_LIMIT,
                    exclude_conversation_id=self._exclude_recall_conversation_id(
                        message=message,
                        conversation_id=conversation_id,
                        conversation_history=conversation_history,
                    ),
                ),
                timings_ms,
            )
            if load_plan.load_chat_search
            else self.empty_list()
        )
        structured_context_task = self.timed_fetch(
            "structured_context",
            self._fetch_structured_context(
                message,
                load_plan=load_plan,
            ),
            timings_ms,
        )

        (
            raw_long_term_memory,
            raw_profile_memory,
            raw_chat_search_results,
            structured_context,
        ) = await asyncio.gather(
            long_term_memory_task,
            profile_memory_task or self.empty_list(),
            chat_search_results_task,
            structured_context_task,
        )
        return self._assemble_prompt_context(
            conversation_history=conversation_history,
            raw_long_term_memory=raw_long_term_memory,
            raw_profile_memory=raw_profile_memory,
            raw_chat_search_results=raw_chat_search_results,
            structured_context=structured_context,
            conversation_id=conversation_id,
            loaded={
                "recent_messages": True,
                **load_plan.loaded,
            },
            attempted_sources={
                "recent_messages": True,
                **load_plan.attempted_sources,
            },
            timings_ms=timings_ms,
            fetch_started=fetch_started,
            initial_failures=memory_failures,
        )

    async def _fetch_structured_context(
        self,
        message: str,
        *,
        load_plan,
    ) -> dict:
        if load_plan.load_inventory_overview:
            overview = await self.saved_knowledge_overview.get_overview()
            inventory_text = format_inventory_context(overview)
            return {
                "inventory_overview": overview,
                "inventory_context": inventory_text,
                "memory_status": {
                    "saved_knowledge_overview": "loaded",
                    "saved_knowledge_count": (overview.get("counts") or {}).get(
                        "total", 0
                    ),
                },
            }
        base = await self.memory_context.fetch_structured_context(
            self.memory_service,
            self.goal_context_service,
            message,
            include_structured_memory=load_plan.load_structured_memory,
            include_goal_context=load_plan.load_goal_context,
        )
        return await self._merge_open_threads_context(message, base)

    async def _merge_open_threads_context(self, message: str, structured_context: dict) -> dict:
        thread_context = await load_open_threads_context(
            self.memory_service,
            message,
        )
        if not thread_context:
            return structured_context
        return {**structured_context, **thread_context}

    def _exclude_recall_conversation_id(
        self,
        *,
        message: str,
        conversation_id: Optional[str],
        conversation_history: list[dict],
    ) -> Optional[str]:
        if not conversation_id:
            return None
        if self.recall_policy.should_exclude_current_conversation(
            message,
            conversation_history=conversation_history,
        ):
            return conversation_id
        return None

    def _assemble_prompt_context(
        self,
        *,
        conversation_history: list[dict],
        raw_long_term_memory: list[dict],
        raw_profile_memory: list[dict],
        raw_chat_search_results: list[dict],
        structured_context: dict,
        conversation_id: Optional[str],
        loaded: dict,
        attempted_sources: dict,
        timings_ms: dict[str, int],
        fetch_started: float,
        initial_failures: Optional[list[dict]] = None,
    ) -> tuple[list[dict], list[dict], dict]:
        return self.prompt_context_builder.assemble_prompt_context(
            conversation_history=conversation_history,
            raw_long_term_memory=raw_long_term_memory,
            raw_profile_memory=raw_profile_memory,
            raw_chat_search_results=raw_chat_search_results,
            structured_context=structured_context,
            conversation_id=conversation_id,
            loaded=loaded,
            attempted_sources=attempted_sources,
            timings_ms=timings_ms,
            fetch_started=fetch_started,
            log_context_fetch=self.log_context_fetch,
            initial_failures=initial_failures,
        )

    async def empty_list(self) -> list[dict]:
        return []

    async def timed_fetch(self, name: str, awaitable, timings_ms: dict[str, int]):
        started = time.perf_counter()
        result = await awaitable
        timings_ms[name] = self.elapsed_ms(started)
        return result

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
        locale: Optional[str] = None,
    ) -> list[dict]:
        return self.prompt_context_builder.build_prompt_messages(
            message=message,
            conversation_id=conversation_id,
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            file_text=file_text,
            time_context=time_context,
            financial_context=financial_context,
            max_context_characters=max_context_characters,
            locale=locale,
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
        financial_context: Optional[dict] = None,
    ) -> list:
        if self.accountability_service is None:
            return []

        try:
            return await self.accountability_service.analyze_signals(
                message=message,
                time_context=time_context,
                personal_rules=structured_context.get("personal_rules") or [],
                plans=structured_context.get("plans") or [],
                plan_milestones=structured_context.get("plan_milestones") or [],
                entity_events=structured_context.get("entity_events") or [],
                relevant_memories=long_term_memory,
                budget_performance=financial_budget_performance(financial_context),
            )
        except Exception:
            return []

    def should_analyze_accountability(self) -> bool:
        return False

    def log_context_fetch(
        self,
        *,
        conversation_id: Optional[str],
        loaded: dict,
        counts: dict,
        timings_ms: dict[str, int],
        total_ms: int,
    ) -> None:
        payload = {
            "conversation_id": conversation_id,
            "intent": "thin_base",
            "loaded": loaded,
            "counts": counts,
            "timings_ms": timings_ms,
            "total_ms": total_ms,
        }
        LOGGER.info("rex_context_fetch %s", json.dumps(payload, sort_keys=True))

    def elapsed_ms(self, started: float) -> int:
        return int((time.perf_counter() - started) * 1000)

    def last_message_timestamp(self, conversation_history: list[dict]) -> Optional[str]:
        return self.prompt_context_builder.last_message_timestamp(
            conversation_history,
        )

    def conversation_timestamp(self, conversation_history: list[dict]) -> Optional[str]:
        return self.prompt_context_builder.conversation_timestamp(
            conversation_history,
        )
