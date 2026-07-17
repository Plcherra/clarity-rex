from dataclasses import dataclass
from typing import Optional

from app.services.chat_context_recall import ChatContextRecallPolicy
from app.services.recall_intent_helper import MEMORY_INVENTORY_QUERY
from app.services.rex_channel import RexBrainChannel


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
    load_inventory_overview: bool = False

    @property
    def loaded(self) -> dict:
        return {
            "long_term_memory": self.load_long_term_memory,
            "profile_memory": self.load_profile_memory,
            "chat_search": self.load_chat_search,
            "structured_memory": self.load_structured_memory,
            "goal_context": self.load_goal_context,
            "inventory_overview": self.load_inventory_overview,
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
        channel: RexBrainChannel = RexBrainChannel.CHAT,
    ) -> ChatContextLoadPlan:
        _ = (message, channel)
        return self._thin_plan()

    def after_history_plan(
        self,
        *,
        message: str,
        conversation_history: list[dict],
        initial_plan: ChatContextLoadPlan,
        channel: RexBrainChannel = RexBrainChannel.CHAT,
    ) -> ChatContextLoadPlan:
        _ = (message, conversation_history, initial_plan, channel)
        return self._thin_plan()

    def _thin_plan(self) -> ChatContextLoadPlan:
        return ChatContextLoadPlan(
            recall_query=None,
            recall_request=False,
            memory_query=MEMORY_INVENTORY_QUERY,
            load_long_term_memory=False,
            load_profile_memory=False,
            load_chat_search=False,
            load_structured_memory=False,
            load_goal_context=False,
            load_inventory_overview=False,
        )

    def _slim_voice_plan(
        self,
        plan: ChatContextLoadPlan,
        *,
        channel: RexBrainChannel,
    ) -> ChatContextLoadPlan:
        _ = channel
        return plan
