from dataclasses import dataclass
from typing import Optional

from app.services.chat_context_recall import ChatContextRecallPolicy
from app.services.recall_intent_helper import (
    MEMORY_INVENTORY_QUERY,
    PROFILE_MEMORY_QUERY,
)
from app.services.rex_intent_router import RexIntent, RexIntentDecision


@dataclass(frozen=True)
class ChatContextLoadPlan:
    recall_query: Optional[str]
    recall_request: bool
    memory_query: str
    load_long_term_memory: bool
    load_profile_memory: bool
    load_chat_search: bool
    load_structured_memory: bool
    load_goal_context: bool

    @property
    def loaded(self) -> dict:
        return {
            "long_term_memory": self.load_long_term_memory,
            "profile_memory": self.load_profile_memory,
            "chat_search": self.load_chat_search,
            "structured_memory": self.load_structured_memory,
            "goal_context": self.load_goal_context,
        }

    @property
    def attempted_sources(self) -> dict:
        return {
            "long_term_memory": self.load_long_term_memory,
            "profile_memory": self.load_profile_memory,
            "chat_search": self.load_chat_search,
            "structured_memory": self.load_structured_memory,
        }


class ChatContextLoadPlanner:
    """Computes which context sources this turn should load."""

    def __init__(self, recall_policy: ChatContextRecallPolicy) -> None:
        self.recall_policy = recall_policy

    def initial_plan(
        self,
        *,
        message: str,
        intent_decision: Optional[RexIntentDecision],
    ) -> ChatContextLoadPlan:
        return self._plan(
            message=message,
            conversation_history=[],
            intent_decision=intent_decision,
        )

    def after_history_plan(
        self,
        *,
        message: str,
        conversation_history: list[dict],
        intent_decision: Optional[RexIntentDecision],
        initial_plan: ChatContextLoadPlan,
    ) -> ChatContextLoadPlan:
        recall_query = self.recall_policy.recall_query(
            message,
            conversation_history=conversation_history,
        )
        recall_request = recall_query is not None or self._force_recall(intent_decision)
        recall_query = recall_query or (
            self.recall_policy.topic_query(message) if recall_request else None
        )
        memory_query = self.recall_policy.memory_query(
            message,
            conversation_history=conversation_history,
            recall_query=recall_query,
        )
        return ChatContextLoadPlan(
            recall_query=recall_query,
            recall_request=recall_request,
            memory_query=memory_query,
            load_long_term_memory=(
                initial_plan.load_long_term_memory or recall_request
            ),
            load_profile_memory=initial_plan.load_profile_memory,
            load_chat_search=recall_request,
            load_structured_memory=(
                initial_plan.load_structured_memory or recall_request
            ),
            load_goal_context=initial_plan.load_goal_context,
        )

    def _plan(
        self,
        *,
        message: str,
        conversation_history: list[dict],
        intent_decision: Optional[RexIntentDecision],
    ) -> ChatContextLoadPlan:
        recall_query = self.recall_policy.recall_query(
            message,
            conversation_history=conversation_history,
        )
        recall_request = recall_query is not None or self._force_recall(intent_decision)
        recall_query = recall_query or (
            self.recall_policy.topic_query(message) if recall_request else None
        )
        memory_query = self.recall_policy.memory_query(
            message,
            conversation_history=conversation_history,
            recall_query=recall_query,
        )
        load_profile_memory = self._load_profile_memory(intent_decision)
        load_profile_memory = load_profile_memory and memory_query not in {
            PROFILE_MEMORY_QUERY,
            MEMORY_INVENTORY_QUERY,
        }
        return ChatContextLoadPlan(
            recall_query=recall_query,
            recall_request=recall_request,
            memory_query=memory_query,
            load_long_term_memory=(
                self._load_long_term_memory(intent_decision) or recall_request
            ),
            load_profile_memory=load_profile_memory,
            load_chat_search=recall_request,
            load_structured_memory=(
                self._load_structured_memory(intent_decision) or recall_request
            ),
            load_goal_context=self._load_goal_context(intent_decision),
        )

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

    def _force_recall(self, intent_decision: Optional[RexIntentDecision]) -> bool:
        return bool(intent_decision and intent_decision.intent == RexIntent.MEMORY_RECALL)
