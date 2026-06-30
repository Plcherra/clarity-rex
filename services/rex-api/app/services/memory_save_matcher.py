import re
from typing import Optional

from app.services.memory_intent_service import SimpleMemoryIntent

_MEMORY_TOPIC_STOP_WORDS = {
    "and",
    "for",
    "have",
    "movie",
    "bought",
    "canceled",
    "cancelled",
    "plan",
    "plans",
    "tickets",
    "today",
    "tomorrow",
    "tonight",
    "user",
    "watch",
    "will",
}


class MemorySaveMatcher:
    async def _find_equivalent_active_memory(
        self,
        intent: SimpleMemoryIntent,
    ) -> Optional[dict]:
        memories = await self._active_memories_for_intent(intent)
        for memory in memories:
            if self._memory_matches_intent(memory, intent):
                return memory
        archived_memories = await self._covered_archived_memories_for_intent(intent)
        for memory in archived_memories:
            if self._memory_payload_matches_intent(memory, intent):
                return memory
        return None

    async def _find_active_memory_by_topic(
        self,
        intent: SimpleMemoryIntent,
    ) -> Optional[dict]:
        intent_fingerprint = self._intent_fingerprint(intent)
        if not intent_fingerprint:
            return None
        memories = await self._active_memories_for_intent(intent)
        for memory in memories:
            if self._payload_fingerprint(memory) == intent_fingerprint:
                return memory
        for memory in memories:
            if self._memory_topic_matches_intent(memory, intent):
                return memory
        return None

    async def _active_memories_for_intent(
        self,
        intent: SimpleMemoryIntent,
    ) -> list[dict]:
        list_memory = getattr(self.memory_service, "list_long_term_memory", None)
        if list_memory is None:
            return []
        try:
            return await list_memory(
                limit=100,
                memory_type=intent.memory_type,
                active=True,
            )
        except Exception:
            return []

    async def _covered_archived_memories_for_intent(
        self,
        intent: SimpleMemoryIntent,
    ) -> list[dict]:
        list_memory = getattr(self.memory_service, "list_long_term_memory", None)
        if list_memory is None:
            return []
        try:
            memories = await list_memory(
                limit=100,
                memory_type=intent.memory_type,
                active=False,
            )
        except Exception:
            return []
        return [
            memory
            for memory in memories
            if self._is_covered_by_structured_memory(memory)
        ]

    def _memory_matches_intent(
        self,
        memory: dict,
        intent: SimpleMemoryIntent,
    ) -> bool:
        if memory.get("active") is False:
            return False
        if str(memory.get("memory_type") or "") != intent.memory_type:
            return False
        return self._memory_payload_matches_intent(memory, intent)

    def _is_covered_by_structured_memory(self, memory: dict) -> bool:
        metadata = memory.get("metadata")
        if not isinstance(metadata, dict):
            return False
        return (
            metadata.get("canonical_entity_type") == "person"
            and str(metadata.get("duplicate_archive_reason") or "").startswith(
                "covered_by_"
            )
        )

    def _memory_payload_matches_intent(
        self,
        payload: dict,
        intent: SimpleMemoryIntent,
    ) -> bool:
        payload_fingerprint = self._payload_fingerprint(payload)
        intent_fingerprint = self._intent_fingerprint(intent)
        if payload_fingerprint and intent_fingerprint:
            if payload_fingerprint != intent_fingerprint:
                return False
            return self._normalize_memory_text(str(payload.get("content") or "")) == (
                self._normalize_memory_text(intent.content)
            )
        return self._normalize_memory_text(str(payload.get("content") or "")) == (
            self._normalize_memory_text(intent.content)
        )

    def _payload_fingerprint(self, payload: dict) -> Optional[str]:
        metadata = payload.get("metadata")
        if not isinstance(metadata, dict):
            return None
        fingerprint = metadata.get("topic_fingerprint")
        return str(fingerprint) if fingerprint else None

    def _intent_fingerprint(self, intent: SimpleMemoryIntent) -> Optional[str]:
        fingerprint = intent.metadata.get("topic_fingerprint")
        return str(fingerprint) if fingerprint else None

    def _memory_topic_matches_intent(
        self,
        memory: dict,
        intent: SimpleMemoryIntent,
    ) -> bool:
        fact_kind = str(intent.metadata.get("fact_kind") or "")
        normalized_content = self._normalize_memory_text(
            str(memory.get("content") or "")
        )
        if fact_kind == "name":
            return "name" in normalized_content
        if fact_kind == "location":
            return "live" in normalized_content and (
                "user" in normalized_content or "i " in f"{normalized_content} "
            )
        if fact_kind == "birthday":
            entity = self._normalize_memory_text(
                str(intent.metadata.get("entity_label") or "")
            )
            return "birthday" in normalized_content and (
                not entity or entity in normalized_content
            )
        if fact_kind == "preference":
            return self._memory_preference_topic_matches(normalized_content, intent)
        if fact_kind == "personal_plan":
            return self._memory_plan_topic_matches(normalized_content, intent)
        if fact_kind == "relationship":
            entity = self._normalize_memory_text(
                str(intent.metadata.get("entity_label") or "")
            )
            relationship = self._normalize_memory_text(
                str(intent.metadata.get("relationship") or "")
            )
            return bool(entity and relationship) and entity in normalized_content and (
                relationship in normalized_content
            )
        return False

    def _normalize_memory_text(self, text: str) -> str:
        normalized = re.sub(r"[^a-z0-9]+", " ", text.lower())
        return re.sub(r"\s+", " ", normalized).strip()

    def _memory_preference_topic_matches(
        self,
        normalized_content: str,
        intent: SimpleMemoryIntent,
    ) -> bool:
        preferred = self._normalize_memory_text(
            str(intent.metadata.get("preferred") or "")
        )
        compared_to = self._normalize_memory_text(
            str(intent.metadata.get("compared_to") or "")
        )
        if not preferred or not compared_to:
            return False
        return (
            "prefer" in normalized_content
            and preferred in normalized_content
            and compared_to in normalized_content
        )

    def _memory_plan_topic_matches(
        self,
        normalized_content: str,
        intent: SimpleMemoryIntent,
    ) -> bool:
        normalized_intent = self._normalize_memory_text(intent.content)
        if "watch" not in normalized_content or "watch" not in normalized_intent:
            return False

        intent_title = self._normalize_memory_text(
            str(intent.metadata.get("plan_title") or "")
        )
        if intent_title and intent_title in normalized_content:
            return True

        content_words = self._memory_topic_words(normalized_content)
        intent_words = self._memory_topic_words(intent.content)
        if not intent_words:
            return False

        shared = content_words & intent_words
        if len(shared) >= 2:
            return True

        has_time_overlap = bool(
            {"today", "tonight", "tomorrow"} & set(normalized_content.split())
        ) and bool({"today", "tonight", "tomorrow"} & set(normalized_intent.split()))
        return len(shared) >= 1 and has_time_overlap

    def _memory_topic_words(self, text: str) -> set[str]:
        normalized = self._normalize_memory_text(text)
        return {
            word
            for word in normalized.split()
            if len(word) >= 4 and word not in _MEMORY_TOPIC_STOP_WORDS
        }

    def _looks_like_location_memory(self, memory: dict) -> bool:
        metadata = memory.get("metadata")
        if isinstance(metadata, dict) and metadata.get("fact_kind") == "location":
            return True
        normalized = self._normalize_memory_text(str(memory.get("content") or ""))
        return "live" in normalized and (
            "user" in normalized or "i " in f"{normalized} "
        )
