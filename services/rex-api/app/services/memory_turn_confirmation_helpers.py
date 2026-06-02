from typing import Optional

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
                    "metadata": {
                        **intent.metadata,
                        "original_text": str(
                            user_message.get("content") or fallback_message
                        ),
                    },
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
