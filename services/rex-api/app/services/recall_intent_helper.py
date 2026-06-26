"""Detect recall intent and build chat-search queries."""

from __future__ import annotations

from typing import Optional

from app.services.chat_search_terms import ChatSearchTermBuilder
from app.services.recall_intent_constants import (
    MEMORY_INVENTORY_QUERY,
    PROFILE_MEMORY_LIMIT,
    PROFILE_MEMORY_QUERY,
)
from app.services.recall_intent_detection import RecallIntentDetectionMixin
from app.services.recall_intent_query import RecallIntentQueryMixin
from app.services.transcript_normalizer import (
    DEFAULT_TRANSCRIPT_NORMALIZER,
    TranscriptNormalizer,
)

__all__ = [
    "MEMORY_INVENTORY_QUERY",
    "PROFILE_MEMORY_LIMIT",
    "PROFILE_MEMORY_QUERY",
    "RecallIntentHelper",
]


class RecallIntentHelper(RecallIntentDetectionMixin, RecallIntentQueryMixin):
    def __init__(
        self,
        *,
        search_terms: Optional[ChatSearchTermBuilder] = None,
        transcript_normalizer: Optional[TranscriptNormalizer] = None,
    ) -> None:
        self.search_terms = search_terms or ChatSearchTermBuilder()
        self.transcript_normalizer = (
            transcript_normalizer or DEFAULT_TRANSCRIPT_NORMALIZER
        )

    def normalized_recall_text(self, message: str) -> str:
        return self.transcript_normalizer.normalize_for_matching(message)
