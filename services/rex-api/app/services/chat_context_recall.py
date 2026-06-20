from typing import Optional

from app.services.recall_intent_helper import RecallIntentHelper


class ChatContextRecallPolicy:
    """Single recall-query policy used by chat context loading."""

    def __init__(self, recall_intent: Optional[RecallIntentHelper] = None) -> None:
        self.recall_intent = recall_intent or RecallIntentHelper()

    def recall_query(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[str]:
        return self.recall_intent.recall_search_query(
            message,
            conversation_history=conversation_history,
        )

    def memory_query(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        recall_query: Optional[str] = None,
    ) -> str:
        return recall_query or self.recall_intent.memory_retrieval_query(
            message,
            conversation_history=conversation_history,
        )
