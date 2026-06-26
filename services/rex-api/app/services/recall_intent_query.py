"""Recall search query construction used by RecallIntentHelper."""

from __future__ import annotations

import re
from typing import TYPE_CHECKING, Optional

from app.services.recall_intent_constants import (
    FOCUSED_DEFINITE_REFERENCE_PATTERN,
    FOCUSED_MODAL_BEFORE_I,
    FOCUSED_RELATIVE_REFERENCE_PATTERN,
    FOCUSED_TRAILING_USER_CLAUSE_PATTERN,
    MEMORY_INVENTORY_QUERY,
    RECALL_QUERY_NOISE_TERMS,
)

if TYPE_CHECKING:
    from app.services.recall_intent_helper import RecallIntentHelper


class RecallIntentQueryMixin:
    def memory_retrieval_query(
        self: RecallIntentHelper,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> str:
        normalized = self.normalized_recall_text(message)
        if self.is_memory_inventory_query(normalized):
            return MEMORY_INVENTORY_QUERY
        is_followup = self.is_contextual_memory_followup(
            normalized,
        ) or self.is_about_recall_followup(normalized)
        if is_followup:
            subject = self.recent_memory_subject(conversation_history)
            if subject:
                return f"{subject} {message}".strip()
        return message

    def recall_search_query(
        self: RecallIntentHelper,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[str]:
        if not self.is_recall_request(
            message,
            conversation_history=conversation_history,
        ):
            return None
        normalized = self.normalized_recall_text(message)
        history_topic = self.recall_topic_from_history(
            message,
            conversation_history=conversation_history,
        )
        if history_topic:
            return history_topic
        is_followup = self.is_contextual_memory_followup(
            normalized,
        ) or self.is_about_recall_followup(normalized)
        if is_followup:
            subject = self.recent_memory_subject(conversation_history)
            if subject:
                return self.chat_topic_query(f"{subject} {message}") or subject
        focused = self.focused_topic_query(message)
        topic = self.chat_topic_query(message)
        if focused and self._prefer_focused_over_topic(topic, focused):
            return focused
        if topic:
            return topic
        if focused:
            return focused
        if self.is_search_recall_request(normalized):
            subject = self.recent_memory_subject(conversation_history)
            if subject:
                return (
                    self.focused_topic_query(subject)
                    or self.chat_topic_query(subject)
                    or subject
                )
            return None
        return message

    def recall_topic_from_history(
        self: RecallIntentHelper,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[str]:
        normalized = self.normalized_recall_text(message)
        if not conversation_history:
            return None
        needs_history_topic = (
            self.is_contextual_memory_followup(normalized)
            or self.is_search_recall_request(normalized)
            or self.is_about_recall_followup(normalized)
        )
        if not needs_history_topic:
            return None
        subject = self.recent_memory_subject(conversation_history)
        if not subject:
            return None
        return (
            self.focused_topic_query(subject)
            or self.chat_topic_query(subject)
            or self.chat_topic_query(f"{subject} {message}")
        )

    def chat_topic_query(self: RecallIntentHelper, message: str) -> str:
        return self.search_terms.assistant_topic_query(message)

    def focused_topic_query(self: RecallIntentHelper, message: str) -> str:
        normalized = self.normalized_recall_text(message)
        relative_topics: list[str] = []
        for relative in FOCUSED_RELATIVE_REFERENCE_PATTERN.finditer(normalized):
            if relative.group(1) in FOCUSED_MODAL_BEFORE_I:
                continue
            cleaned = self._clean_focused_topic_phrase(relative.group(0))
            if len(cleaned) >= 3:
                relative_topics.append(cleaned)
        if relative_topics:
            return relative_topics[-1]

        definite_topics: list[str] = []
        for match in FOCUSED_DEFINITE_REFERENCE_PATTERN.finditer(normalized):
            cleaned = self._clean_focused_topic_phrase(match.group(0))
            if len(cleaned) >= 3:
                definite_topics.append(cleaned)
        if definite_topics:
            return definite_topics[-1]
        return ""

    def _prefer_focused_over_topic(
        self: RecallIntentHelper,
        topic: str,
        focused: str,
    ) -> bool:
        if not focused:
            return False
        if not topic:
            return True
        return bool(set(topic.split()) & RECALL_QUERY_NOISE_TERMS)

    def _clean_focused_topic_phrase(self: RecallIntentHelper, phrase: str) -> str:
        cleaned = re.sub(
            r"^(?:the|those|these)\s+",
            "",
            phrase.strip(),
        )
        cleaned = FOCUSED_TRAILING_USER_CLAUSE_PATTERN.sub("", cleaned).strip()
        cleaned = re.sub(r"\s+", " ", cleaned)
        if len(cleaned) < 3:
            return ""
        return self.chat_topic_query(cleaned) or cleaned
