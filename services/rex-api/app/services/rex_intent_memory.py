from __future__ import annotations

import re

from app.services.recall_intent_helper import RecallIntentHelper
from app.services.rex_intent_finance import RexIntentFinanceHelper
from app.services.rex_intent_patterns import (
    MEMORY_DELETE_TERMS,
    MEMORY_SAVE_TERMS,
    MEMORY_STORE_TERMS,
    contains,
)


class RexIntentMemoryHelper:
    def __init__(
        self,
        recall_intent: RecallIntentHelper,
        finance_helper: RexIntentFinanceHelper,
    ) -> None:
        self.recall_intent = recall_intent
        self.finance_helper = finance_helper

    def looks_like_memory_recall_question(self, normalized_message: str) -> bool:
        if self.is_finance_first_query(normalized_message):
            return False

        return self.recall_intent.is_router_memory_recall_request(
            normalized_message,
        )

    def is_finance_first_query(self, normalized_message: str) -> bool:
        if not self.finance_helper.has_finance_language(normalized_message):
            return False
        return not contains(normalized_message, MEMORY_STORE_TERMS)

    def looks_like_memory_save(self, normalized_message: str) -> bool:
        if normalized_message.startswith(("do you remember", "what do you remember")):
            return False
        if normalized_message.startswith("remember what"):
            return False
        if normalized_message.startswith(
            ("remember any", "remember if", "remember whether")
        ):
            return False
        if normalized_message.startswith("remember ") and contains(
            normalized_message,
            (
                "anything",
                "chat",
                "conversation",
                "mentioned",
                "old",
                "search",
                "talked about",
                "what",
            ),
        ):
            return False
        if normalized_message.startswith("remember "):
            return True
        if " please remember " in f" {normalized_message} ":
            return True
        if normalized_message.startswith(
            (
                "can ",
                "could ",
                "do ",
                "does ",
                "how ",
                "what ",
                "when ",
                "where ",
                "who ",
            )
        ):
            return False
        return contains(
            normalized_message,
            tuple(term for term in MEMORY_SAVE_TERMS if term != "remember"),
        )

    def looks_like_memory_delete(self, normalized_message: str) -> bool:
        if not contains(normalized_message, MEMORY_DELETE_TERMS):
            return False
        if self.is_finance_first_query(normalized_message):
            return False
        return (
            contains(normalized_message, MEMORY_STORE_TERMS)
            or re.search(
                r"\b(?:card|event|fact|item|knows|knowledge|note|person|people|record|that|this|it)\b",
                normalized_message,
            )
            is not None
        )
