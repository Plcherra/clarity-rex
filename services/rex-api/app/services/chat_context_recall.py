from typing import Optional

from app.services.chat_continuity_policy import ChatContinuityPolicy
from app.services.recall_intent_helper import RecallIntentHelper


class ChatContextRecallPolicy:
    """Single recall-query policy used by chat context loading."""

    def __init__(
        self,
        recall_intent: Optional[RecallIntentHelper] = None,
        continuity: Optional[ChatContinuityPolicy] = None,
    ) -> None:
        self.recall_intent = recall_intent or RecallIntentHelper()
        self.continuity = continuity or ChatContinuityPolicy(
            recall_intent=self.recall_intent,
        )

    def recall_query(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[str]:
        explicit_query = self.recall_intent.recall_search_query(
            message,
            conversation_history=conversation_history,
        )
        if explicit_query is not None:
            return explicit_query
        if self.continuity.needs_cross_chat_lookup(
            message,
            conversation_history=conversation_history,
        ):
            return self.continuity.search_query(message)
        return None

    def needs_chat_search(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> bool:
        return self.recall_query(
            message,
            conversation_history=conversation_history,
        ) is not None

    def topic_query(self, message: str) -> str:
        return self.recall_intent.chat_topic_query(message)

    def memory_query(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        recall_query: Optional[str] = None,
    ) -> str:
        return self.recall_intent.memory_retrieval_query(
            message,
            conversation_history=conversation_history,
        )
