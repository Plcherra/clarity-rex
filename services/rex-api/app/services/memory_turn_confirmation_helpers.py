import re
from typing import Optional

from app.services.memory_path_policy import (
    direct_save_metadata,
    pending_confirmation_metadata,
)
from app.services.memory_intent_service import SimpleMemoryIntent


class MemoryTurnConfirmationHelpers:
    def _intent_from_confirmation_record(
        self,
        confirmation: Optional[dict],
    ) -> Optional[SimpleMemoryIntent]:
        if not confirmation:
            return None
        try:
            return SimpleMemoryIntent(
                memory_type=str(confirmation["memory_type"]),
                content=str(confirmation["content"]),
                importance=int(confirmation.get("importance") or 3),
                confirmation_question="",
                source=str(confirmation.get("source") or "simple_memory_intent"),
                metadata=(
                    confirmation.get("metadata")
                    if isinstance(confirmation.get("metadata"), dict)
                    else {}
                ),
            )
        except (KeyError, TypeError, ValueError):
            return None

    async def _latest_pending_confirmation(
        self,
        conversation_id: str,
    ) -> Optional[dict]:
        try:
            return await self.memory_service.get_latest_pending_memory_confirmation(
                conversation_id,
            )
        except Exception:
            return None

    async def _create_pending_confirmation(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        fallback_message: str,
    ) -> Optional[dict]:
        try:
            return await self.memory_service.create_memory_confirmation(
                {
                    "conversation_id": conversation_id,
                    "source_message_id": str(user_message.get("id") or "") or None,
                    "memory_type": intent.memory_type,
                    "content": intent.content,
                    "importance": intent.importance,
                    "source": intent.source,
                    "metadata": pending_confirmation_metadata(
                        {
                            **intent.metadata,
                            "original_text": str(
                                user_message.get("content") or fallback_message
                            ),
                        }
                    ),
                }
            )
        except Exception:
            return None

    async def _update_confirmation(
        self,
        confirmation_id: str,
        **updates: object,
    ) -> Optional[dict]:
        try:
            return await self.memory_service.update_memory_confirmation(
                confirmation_id,
                **updates,
            )
        except Exception:
            return None

    async def _confirm_confirmation(
        self,
        confirmation_id: str,
        *,
        applied_memory_id: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        try:
            return await self.memory_service.confirm_memory_confirmation(
                confirmation_id,
                applied_memory_id=applied_memory_id,
                metadata=metadata,
            )
        except Exception:
            return None

    async def _reject_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        try:
            return await self.memory_service.reject_memory_confirmation(
                confirmation_id,
                metadata=metadata,
            )
        except Exception:
            return None

    async def _fail_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        try:
            return await self.memory_service.fail_memory_confirmation(
                confirmation_id,
                metadata=metadata,
            )
        except Exception:
            return None

    async def _find_equivalent_active_memory(
        self,
        intent: SimpleMemoryIntent,
    ) -> Optional[dict]:
        list_memory = getattr(self.memory_service, "list_long_term_memory", None)
        if list_memory is None:
            return None
        try:
            memories = await list_memory(
                limit=100,
                memory_type=intent.memory_type,
                active=True,
            )
        except Exception:
            return None

        for memory in memories:
            if self._memory_matches_intent(memory, intent):
                return memory
        return None

    def _confirmation_matches_intent(
        self,
        confirmation: Optional[dict],
        intent: SimpleMemoryIntent,
    ) -> bool:
        if not confirmation:
            return False
        if str(confirmation.get("status") or "") != "pending":
            return False
        return self._memory_payload_matches_intent(confirmation, intent)

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

    def _memory_payload_matches_intent(
        self,
        payload: dict,
        intent: SimpleMemoryIntent,
    ) -> bool:
        payload_fingerprint = self._payload_fingerprint(payload)
        intent_fingerprint = self._intent_fingerprint(intent)
        if payload_fingerprint and intent_fingerprint:
            return payload_fingerprint == intent_fingerprint
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

    def _normalize_memory_text(self, text: str) -> str:
        normalized = re.sub(r"[^a-z0-9]+", " ", text.lower())
        return re.sub(r"\s+", " ", normalized).strip()

    async def _repeat_pending_simple_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        confirmation_id: Optional[str],
    ) -> dict:
        response = intent.confirmation_question
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
            "memory_changes": self._simple_memory_confirmation_summary(
                intent,
                confirmation_id=confirmation_id,
            ),
            "messages": await self.recent_public_messages(conversation_id),
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
