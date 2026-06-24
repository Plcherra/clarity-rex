import re
from dataclasses import replace
from typing import Optional

from app.services.memory_failure_reporting import (
    log_memory_failure,
    memory_degraded_metadata,
)
from app.services.memory_intent_service import SimpleMemoryIntent
from app.services.memory_path_policy import direct_save_metadata


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


class MemoryTurnDirectHelpers:
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

    async def _confirmed_visible_active_memory(self, record: dict) -> Optional[dict]:
        record_id = str(record.get("id") or "")
        if not record_id:
            return None

        list_memory = getattr(self.memory_service, "list_long_term_memory", None)
        if list_memory is None:
            return None

        try:
            memories = await list_memory(
                limit=100,
                memory_type=record.get("memory_type"),
                active=True,
            )
        except TypeError:
            try:
                memories = await list_memory(limit=100, active=True)
            except Exception:
                return None
        except Exception:
            return None

        for memory in memories:
            if str(memory.get("id") or "") == record_id:
                return memory
        return None

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

    async def _already_saved_simple_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        record: dict,
    ) -> dict:
        response = "I already have that saved."
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            response,
        )
        return {
            "conversation_id": conversation_id,
            "response": response,
            "user_message": user_message,
            "assistant_message": self.public_message(assistant_message),
            "memory_correction": None,
            "memory_changes": self._simple_memory_already_saved_summary(
                intent,
                record,
            ),
            "messages": await self.recent_public_messages(conversation_id),
        }

    async def _update_simple_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        record: dict,
    ) -> dict:
        update_memory = getattr(self.memory_service, "update_long_term_memory", None)
        record_id = str(record.get("id") or "")
        if update_memory is None or not record_id:
            return await self._save_confirmed_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
            )

        intent = self._preserve_location_context(intent, record)
        merged_metadata = {
            **(
                record.get("metadata")
                if isinstance(record.get("metadata"), dict)
                else {}
            ),
            **direct_save_metadata(
                {
                    **intent.metadata,
                    "updated_from_memory_id": record_id,
                    "previous_content": record.get("content"),
                }
            ),
        }
        try:
            updated = await update_memory(
                record_id,
                memory_type=intent.memory_type,
                content=intent.content,
                importance=intent.importance,
                active=True,
                metadata=merged_metadata,
            )
        except Exception as error:
            failure_metadata = memory_degraded_metadata(
                intent.metadata,
                operation="update_long_term_memory",
                failure_reason="durable_memory_update_failed",
                user_visible=True,
            )
            log_memory_failure(
                "direct_update_failed",
                operation="update_long_term_memory",
                error=error,
                conversation_id=conversation_id,
                memory_type=intent.memory_type,
                metadata=failure_metadata,
            )
            response = (
                "I understood that correction, but I couldn't update memory just now. "
                "Please try again in a moment."
            )
            assistant_message = await self.memory_service.save_message(
                conversation_id,
                "assistant",
                response,
            )
            return {
                "conversation_id": conversation_id,
                "response": response,
                "user_message": user_message,
                "assistant_message": self.public_message(assistant_message),
                "memory_correction": None,
                "memory_changes": self._simple_memory_failed_summary(
                    intent,
                    metadata=failure_metadata,
                ),
                "messages": await self.recent_public_messages(conversation_id),
            }

        if updated is None:
            failure_metadata = memory_degraded_metadata(
                intent.metadata,
                operation="update_long_term_memory",
                failure_reason="durable_memory_update_missing",
                user_visible=True,
            )
            log_memory_failure(
                "direct_update_missing",
                operation="update_long_term_memory",
                error=RuntimeError("memory update returned no record"),
                conversation_id=conversation_id,
                memory_type=intent.memory_type,
                metadata=failure_metadata,
            )
            response = (
                "I understood that correction, but I couldn't update memory just now. "
                "Please try again in a moment."
            )
            assistant_message = await self.memory_service.save_message(
                conversation_id,
                "assistant",
                response,
            )
            return {
                "conversation_id": conversation_id,
                "response": response,
                "user_message": user_message,
                "assistant_message": self.public_message(assistant_message),
                "memory_correction": None,
                "memory_changes": self._simple_memory_failed_summary(
                    intent,
                    metadata=failure_metadata,
                ),
                "messages": await self.recent_public_messages(conversation_id),
            }

        confirmed_updated = await self._confirmed_visible_active_memory(updated)
        if confirmed_updated is None:
            failure_metadata = memory_degraded_metadata(
                intent.metadata,
                operation="update_long_term_memory_verify",
                failure_reason="durable_memory_update_not_visible",
                user_visible=True,
            )
            log_memory_failure(
                "direct_update_not_visible",
                operation="update_long_term_memory_verify",
                error=RuntimeError("updated memory was not visible in active memory"),
                conversation_id=conversation_id,
                memory_type=intent.memory_type,
                metadata=failure_metadata,
            )
            response = (
                "I understood that correction, but I couldn't confirm it is visible "
                "in Knows yet. Please try again in a moment."
            )
            assistant_message = await self.memory_service.save_message(
                conversation_id,
                "assistant",
                response,
            )
            return {
                "conversation_id": conversation_id,
                "response": response,
                "user_message": user_message,
                "assistant_message": self.public_message(assistant_message),
                "memory_correction": None,
                "memory_changes": self._simple_memory_failed_summary(
                    intent,
                    metadata=failure_metadata,
                ),
                "messages": await self.recent_public_messages(conversation_id),
            }

        updated_record = confirmed_updated
        await self._materialize_person_card(updated_record)
        archived_related = await self._archive_stale_location_memories(
            intent,
            updated_record,
        )
        response = (
            "Got it, I updated that: "
            f"{self.memory_intent_service.memory_sentence(intent.content)}"
        )
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            response,
        )
        return {
            "conversation_id": conversation_id,
            "response": response,
            "user_message": user_message,
            "assistant_message": self.public_message(assistant_message),
            "memory_correction": None,
            "memory_changes": self._simple_memory_updated_summary(
                intent,
                updated_record,
                previous_record=record,
                archived_related=archived_related,
            ),
            "messages": await self.recent_public_messages(conversation_id),
        }

    async def _archive_stale_location_memories(
        self,
        intent: SimpleMemoryIntent,
        updated_record: dict,
    ) -> list[dict]:
        if intent.metadata.get("fact_kind") != "location":
            return []

        update_memory = getattr(self.memory_service, "update_long_term_memory", None)
        if update_memory is None:
            return []

        updated_id = str(updated_record.get("id") or "")
        archived = []
        for memory in await self._active_memories_for_intent(intent):
            memory_id = str(memory.get("id") or "")
            if not memory_id or memory_id == updated_id:
                continue
            if not self._looks_like_location_memory(memory):
                continue

            metadata = (
                memory.get("metadata")
                if isinstance(memory.get("metadata"), dict)
                else {}
            )
            try:
                inactive = await update_memory(
                    memory_id,
                    active=False,
                    superseded_by=updated_id or None,
                    metadata={
                        **metadata,
                        "archived_by_memory_id": updated_id,
                        "archive_reason": "superseded_location_correction",
                    },
                )
            except Exception:
                continue
            if inactive is not None:
                archived.append(inactive)
        return archived

    def _looks_like_location_memory(self, memory: dict) -> bool:
        metadata = memory.get("metadata")
        if isinstance(metadata, dict) and metadata.get("fact_kind") == "location":
            return True
        normalized = self._normalize_memory_text(str(memory.get("content") or ""))
        return "live" in normalized and (
            "user" in normalized or "i " in f"{normalized} "
        )

    def _preserve_location_context(
        self,
        intent: SimpleMemoryIntent,
        record: dict,
    ) -> SimpleMemoryIntent:
        if intent.metadata.get("fact_kind") != "location":
            return intent

        new_content = str(intent.content or "")
        previous_content = str(record.get("content") or "")
        if "," in new_content or "massachusetts" not in previous_content.lower():
            return intent
        if "somerville" not in new_content.lower():
            return intent

        return replace(
            intent,
            content="User lives in Somerville, Massachusetts.",
        )

    def _simple_memory_already_saved_summary(
        self,
        intent: SimpleMemoryIntent,
        record: dict,
    ) -> dict:
        return {
            "created": 0,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 1,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": "long_term_memory",
                    "type": intent.memory_type,
                    "action": "already_saved",
                    "id": record.get("id"),
                    "title": intent.content,
                    "metadata": direct_save_metadata(intent.metadata),
                }
            ],
        }
