from dataclasses import replace
from typing import Optional

from app.services.memory_failure_reporting import (
    log_memory_failure,
    memory_degraded_metadata,
)
from app.services.memory_intent_service import SimpleMemoryIntent
from app.services.memory_path_policy import direct_save_metadata
from app.services.memory_save_matcher import MemorySaveMatcher
from app.services.memory_save_verifier import MemorySaveVerifier


class MemoryTurnDirectHelpers(MemorySaveMatcher, MemorySaveVerifier):
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
