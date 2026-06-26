"""Cross-chat continuity: when a turn assumes prior user context."""

from __future__ import annotations

import re
from typing import Optional

from app.services.chat_search_terms import ChatSearchTermBuilder
from app.services.chat_recall_filters import is_recall_question_user_content
from app.services.recall_intent_helper import RecallIntentHelper


class ChatContinuityPolicy:
    """Detect when Rex should search old chats for assumed user context.

    This is topic-agnostic. It fires when the user asks a user-scoped question
    that linguistically assumes something already exists in their history, and
    the current conversation does not already contain the relevant topic terms.
    """

    USER_SCOPED_PATTERN = re.compile(
        r"\b(?:i|i'm|i've|i'd|me|my|mine|our|ours|us|we|we're|we've)\b"
    )
    DEFINITE_PRIOR_REFERENCE_PATTERN = re.compile(
        r"\b(?:the|those|these)\s+[a-z0-9']+(?:\s+[a-z0-9']+){0,3}\b"
    )
    RELATIVE_USER_REFERENCE_PATTERN = re.compile(
        r"\b([a-z0-9']+)\s+i\s+([a-z0-9']+)\b"
    )
    MODAL_BEFORE_I = frozenset(
        {
            "am",
            "are",
            "can",
            "could",
            "did",
            "do",
            "does",
            "had",
            "has",
            "have",
            "how",
            "is",
            "may",
            "might",
            "must",
            "shall",
            "should",
            "was",
            "were",
            "what",
            "when",
            "where",
            "which",
            "who",
            "why",
            "will",
            "would",
            "thought",
            "said",
            "told",
            "mentioned",
            "meant",
            "mean",
        }
    )
    RECENT_ACQUISITION_PATTERN = re.compile(
        r"\b(?:added|bought|downloaded|got|grabbed|picked up|preordered|"
        r"purchased|snagged)\b"
    )

    def __init__(
        self,
        *,
        search_terms: Optional[ChatSearchTermBuilder] = None,
        recall_intent: Optional[RecallIntentHelper] = None,
    ) -> None:
        self.search_terms = search_terms or ChatSearchTermBuilder()
        self.recall_intent = recall_intent or RecallIntentHelper()

    def needs_cross_chat_lookup(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> bool:
        normalized = self.recall_intent.normalized_recall_text(message)
        if not normalized.strip():
            return False
        if self.recall_intent.is_finance_only_request(normalized):
            return False
        if not self._is_user_scoped_question(normalized):
            return False
        if not self._assumes_prior_user_context(normalized):
            return False
        return not self._topic_covered_in_recent_history(
            message,
            conversation_history=conversation_history,
        )

    def search_query(self, message: str) -> str:
        topic = self.recall_intent.chat_topic_query(message)
        focused = self.recall_intent.focused_topic_query(message)
        if focused and self.recall_intent._prefer_focused_over_topic(topic, focused):
            return focused
        if topic:
            return topic
        if focused:
            return focused
        terms = self.search_terms.search_terms(message, max_terms=6)
        return " ".join(terms) if terms else message.strip()

    def _is_user_scoped_question(self, normalized_message: str) -> bool:
        if not self.USER_SCOPED_PATTERN.search(normalized_message):
            return False
        if "?" in normalized_message:
            return True
        return bool(
            re.match(
                r"(?:can|could|did|do|does|have|has|had|how|is|are|should|"
                r"what|when|where|who|why|will|would)\b",
                normalized_message.strip(),
            )
        )

    def _assumes_prior_user_context(self, normalized_message: str) -> bool:
        if self.DEFINITE_PRIOR_REFERENCE_PATTERN.search(normalized_message):
            return True
        return self._has_relative_user_reference(normalized_message)

    def _has_relative_user_reference(self, normalized_message: str) -> bool:
        for match in self.RELATIVE_USER_REFERENCE_PATTERN.finditer(normalized_message):
            if match.group(1) in self.MODAL_BEFORE_I:
                continue
            return True
        return False

    def _topic_covered_in_recent_history(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> bool:
        normalized = self.recall_intent.normalized_recall_text(message)
        recent_user_text = " ".join(
            str(item.get("content") or "")
            for item in conversation_history[-20:]
            if item.get("role") == "user"
            and not is_recall_question_user_content(str(item.get("content") or ""))
        ).lower()
        if not recent_user_text.strip():
            return False

        if (
            self._has_relative_user_reference(normalized)
            and self.RECENT_ACQUISITION_PATTERN.search(recent_user_text)
        ):
            return True

        terms = self.search_terms.search_terms(message, max_terms=8)
        if not terms:
            return False

        return any(term in recent_user_text for term in terms)
