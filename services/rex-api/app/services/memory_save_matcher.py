import re
from typing import Optional

from app.services.body_display_text import SimpleMemoryIntent

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
        # After hard-delete of covered flats, person cards are the durable source.
        person = await self._find_covering_person_entity(intent)
        if person is not None:
            return person
        return None

    async def _find_active_memory_by_topic(
        self,
        intent: SimpleMemoryIntent,
    ) -> Optional[dict]:
        intent_fingerprint = self._intent_fingerprint(intent)
        if not intent_fingerprint:
            person = await self._find_covering_person_entity(intent)
            if person is not None:
                return person
            return None
        memories = await self._active_memories_for_intent(intent)
        for memory in memories:
            if self._payload_fingerprint(memory) == intent_fingerprint:
                return memory
        for memory in memories:
            if self._memory_topic_matches_intent(memory, intent):
                return memory
        person = await self._find_covering_person_entity(intent)
        if person is not None:
            return person
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

    async def _find_covering_person_entity(
        self,
        intent: SimpleMemoryIntent,
    ) -> Optional[dict]:
        list_entities = getattr(self.memory_service, "list_entities", None)
        if list_entities is None:
            return None
        try:
            entities = await list_entities(
                entity_type="person",
                active=True,
                limit=100,
            )
        except Exception:
            return None
        for entity in entities:
            if self._person_entity_covers_intent(entity, intent):
                return entity
        return None

    def _person_entity_covers_intent(
        self,
        entity: dict,
        intent: SimpleMemoryIntent,
    ) -> bool:
        if entity.get("active") is False:
            return False
        fact_kind = str(intent.metadata.get("fact_kind") or "")
        relationship = self._normalize_memory_text(
            str(entity.get("relationship") or "")
        )
        metadata = entity.get("metadata") if isinstance(entity.get("metadata"), dict) else {}
        attributes = (
            metadata.get("attributes")
            if isinstance(metadata.get("attributes"), dict)
            else {}
        )
        attr_rel = self._normalize_memory_text(
            str(attributes.get("relationship_to_user") or "")
        )

        if fact_kind == "birthday":
            intent_entity = self._normalize_memory_text(
                str(intent.metadata.get("entity_label") or "")
            )
            intent_date = self._normalize_memory_text(
                str(intent.metadata.get("normalized_date") or "")
            )
            birthday = self._normalize_memory_text(str(attributes.get("birthday") or ""))
            if not birthday:
                return False
            if intent_date and intent_date not in birthday and birthday not in intent_date:
                return False
            if relationship == "self" and (
                not intent_entity or intent_entity in {"self", "user", "me"}
            ):
                return True
            if not intent_entity:
                return False
            haystacks = {
                relationship,
                attr_rel,
                self._normalize_memory_text(str(entity.get("display_name") or "")),
                self._normalize_memory_text(str(entity.get("normalized_name") or "")),
            }
            for alias in entity.get("aliases") or []:
                haystacks.add(self._normalize_memory_text(str(alias)))
            # mom/mother and dad/father are interchangeable relationship labels.
            if intent_entity in {"mom", "mother", "mum", "mama"}:
                haystacks.update({"mom", "mother", "mum", "mama"})
            if intent_entity in {"dad", "father", "papa"}:
                haystacks.update({"dad", "father", "papa"})
            return any(
                intent_entity == value or intent_entity in value or value in intent_entity
                for value in haystacks
                if value
            )

        if fact_kind in {"name", "location"}:
            if relationship != "self":
                return False
            if fact_kind == "name":
                full_name = self._normalize_memory_text(
                    str(attributes.get("full_name") or "")
                )
                intent_content = self._normalize_memory_text(intent.content)
                return bool(full_name) and full_name in intent_content
            location = self._normalize_memory_text(str(attributes.get("location") or ""))
            intent_content = self._normalize_memory_text(intent.content)
            return bool(location) and location in intent_content

        if fact_kind == "relationship":
            intent_rel = self._normalize_memory_text(
                str(intent.metadata.get("relationship") or "")
            )
            return bool(intent_rel) and (
                intent_rel == relationship or intent_rel == attr_rel
            )
        return False

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
            relationship = self._normalize_memory_text(
                str(intent.metadata.get("relationship") or "")
            )
            # Name changes for the same relationship should update the existing
            # mom/friend fact instead of creating a parallel record.
            if relationship and relationship in normalized_content:
                return True
            entity = self._normalize_memory_text(
                str(intent.metadata.get("entity_label") or "")
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
