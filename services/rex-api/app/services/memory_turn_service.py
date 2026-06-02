from typing import Optional, Protocol

from app.services.memory_confirmation_lifecycle_logger import (
    log_confirmation_lifecycle,
)
from app.services.memory_intent_service import MemoryIntentService, SimpleMemoryIntent
from app.services.memory_path_policy import (
    direct_save_metadata,
    pending_confirmation_metadata,
)
from app.services.memory_turn_confirmation_helpers import (
    MemoryTurnConfirmationHelpers,
)


class MemoryTurnStore(Protocol):
    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        pass

    async def get_recent_messages(
        self,
        conversation_id: str,
        limit: int = 20,
    ) -> list[dict]:
        pass

    async def save_long_term_memory(
        self,
        memory_type: str,
        content: str,
        source_conversation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
        importance: int = 3,
        metadata: Optional[dict] = None,
    ) -> dict:
        pass

    async def create_memory_confirmation(self, confirmation: dict) -> dict:
        pass

    async def get_latest_pending_memory_confirmation(
        self,
        conversation_id: str,
    ) -> Optional[dict]:
        pass

    async def update_memory_confirmation(
        self,
        confirmation_id: str,
        **updates: object,
    ) -> Optional[dict]:
        pass

    async def confirm_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        applied_memory_id: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        pass

    async def reject_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        pass

    async def fail_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        pass

    async def list_long_term_memory(
        self,
        limit: int = 50,
        memory_type: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        pass


class MemoryTurnService(MemoryTurnConfirmationHelpers):
    """Handles natural in-chat memory confirmations before AI generation."""

    def __init__(
        self,
        memory_service: MemoryTurnStore,
        memory_intent_service: Optional[MemoryIntentService] = None,
    ) -> None:
        self.memory_service = memory_service
        self.memory_intent_service = memory_intent_service or MemoryIntentService()

    async def handle_turn(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[dict]:
        pending_confirmation = await self._latest_pending_confirmation(
            conversation_id,
        )
        pending_intent = self._intent_from_confirmation_record(pending_confirmation)
        pending_confirmation_id = (
            str(pending_confirmation.get("id"))
            if pending_confirmation and pending_confirmation.get("id")
            else None
        )
        pending_source_message_id = (
            str(pending_confirmation.get("source_message_id"))
            if pending_confirmation and pending_confirmation.get("source_message_id")
            else None
        )
        if pending_intent is None:
            pending_intent = self.memory_intent_service.pending_confirmation_from_history(
                conversation_history
            )
            pending_source_message_id = str(user_message.get("id") or "") or None

        if pending_intent is not None:
            confirmation_decision = (
                self.memory_intent_service.classify_confirmation_reply(message)
            )
            if confirmation_decision == "confirm":
                return await self._save_confirmed_simple_memory(
                    pending_intent,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    confirmation_id=pending_confirmation_id,
                    source_message_id=pending_source_message_id,
                )
            if confirmation_decision == "reject":
                return await self._reject_simple_memory(
                    pending_intent,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    confirmation_id=pending_confirmation_id,
                )

        intent = self.memory_intent_service.detect_simple_memory(
            message,
            time_context=time_context,
        )
        if intent is None:
            return None

        existing_memory = await self._find_equivalent_active_memory(intent)
        if existing_memory is not None:
            log_confirmation_lifecycle(
                "already_saved",
                intent,
                conversation_id=conversation_id,
                memory_id=str(existing_memory.get("id") or "") or None,
            )
            return await self._already_saved_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                record=existing_memory,
            )

        if self._confirmation_matches_intent(pending_confirmation, intent):
            return await self._repeat_pending_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                confirmation_id=pending_confirmation_id,
            )

        confirmation = await self._create_pending_confirmation(
            intent,
            conversation_id=conversation_id,
            user_message=user_message,
            fallback_message=message,
        )
        if confirmation is None:
            log_confirmation_lifecycle(
                "request_failed",
                intent,
                conversation_id=conversation_id,
            )
            return None
        log_confirmation_lifecycle(
            "requested",
            intent,
            conversation_id=conversation_id,
            confirmation_id=str(confirmation.get("id") or "") or None,
        )
        public_response = intent.confirmation_question
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            public_response,
        )
        if confirmation.get("id") and assistant_message.get("id"):
            await self._update_confirmation(
                str(confirmation["id"]),
                confirmation_message_id=str(assistant_message["id"]),
            )
            confirmation = {
                **confirmation,
                "confirmation_message_id": assistant_message["id"],
            }
        confirmation_id = str(confirmation.get("id") or "") or None
        confirmation_summary = self._simple_memory_confirmation_summary(
            intent,
            confirmation_id=confirmation_id,
        )
        return {
            "conversation_id": conversation_id,
            "response": public_response,
            "user_message": user_message,
            "assistant_message": self.public_message(assistant_message),
            "memory_correction": None,
            "memory_changes": confirmation_summary,
            "messages": await self.recent_public_messages(conversation_id),
        }

    async def recent_public_messages(
        self,
        conversation_id: str,
        *,
        limit: int = 20,
    ) -> list[dict]:
        messages = await self.memory_service.get_recent_messages(
            conversation_id,
            limit=limit,
        )
        return self.public_messages(messages)

    def public_messages(self, messages: list[dict]) -> list[dict]:
        return [self.public_message(message) for message in messages]

    def public_message(self, message: dict) -> dict:
        public_message = dict(message)
        public_message["content"] = self.memory_intent_service.strip_internal_markers(
            str(public_message.get("content") or "")
        )
        return public_message

    async def _save_confirmed_simple_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        confirmation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
    ) -> dict:
        existing_memory = await self._find_equivalent_active_memory(intent)
        if existing_memory is not None:
            if confirmation_id is not None:
                await self._confirm_confirmation(
                    confirmation_id,
                    applied_memory_id=str(existing_memory.get("id") or "") or None,
                    metadata=intent.metadata,
                )
            log_confirmation_lifecycle(
                "already_saved",
                intent,
                conversation_id=conversation_id,
                confirmation_id=confirmation_id,
                memory_id=str(existing_memory.get("id") or "") or None,
            )
            return await self._already_saved_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                record=existing_memory,
            )

        try:
            memory_metadata = direct_save_metadata(intent.metadata)
            record = await self.memory_service.save_long_term_memory(
                memory_type=intent.memory_type,
                content=intent.content,
                source_conversation_id=conversation_id,
                source_message_id=source_message_id
                or str(user_message.get("id") or "")
                or None,
                importance=intent.importance,
                metadata=memory_metadata,
            )
        except Exception:
            if confirmation_id is not None:
                await self._fail_confirmation(
                    confirmation_id,
                    metadata={
                        **intent.metadata,
                        "error": "durable_memory_save_failed",
                    },
                )
            log_confirmation_lifecycle(
                "save_failed",
                intent,
                conversation_id=conversation_id,
                confirmation_id=confirmation_id,
            )
            response = (
                "I understood that, but I couldn't save it just now. "
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
                "memory_changes": self._simple_memory_failed_summary(intent),
                "messages": await self.recent_public_messages(conversation_id),
            }

        response = self.memory_intent_service.saved_response(intent)
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            response,
        )
        if confirmation_id is not None:
            await self._confirm_confirmation(
                confirmation_id,
                applied_memory_id=str(record.get("id") or "") or None,
                metadata=direct_save_metadata(intent.metadata),
            )
        log_confirmation_lifecycle(
            "direct_saved",
            intent,
            conversation_id=conversation_id,
            confirmation_id=confirmation_id,
            memory_id=str(record.get("id") or "") or None,
        )
        return {
            "conversation_id": conversation_id,
            "response": response,
            "user_message": user_message,
            "assistant_message": self.public_message(assistant_message),
            "memory_correction": None,
            "memory_changes": self._simple_memory_saved_summary(intent, record),
            "messages": await self.recent_public_messages(conversation_id),
        }

    async def _reject_simple_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        confirmation_id: Optional[str] = None,
    ) -> dict:
        response = self.memory_intent_service.rejected_response()
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            response,
        )
        if confirmation_id is not None:
            await self._reject_confirmation(
                confirmation_id,
                metadata=intent.metadata,
            )
        log_confirmation_lifecycle(
            "rejected",
            intent,
            conversation_id=conversation_id,
            confirmation_id=confirmation_id,
        )
        return {
            "conversation_id": conversation_id,
            "response": response,
            "user_message": user_message,
            "assistant_message": self.public_message(assistant_message),
            "memory_correction": None,
            "memory_changes": self._simple_memory_rejected_summary(intent),
            "messages": await self.recent_public_messages(conversation_id),
        }

    def _simple_memory_confirmation_summary(
        self,
        intent: SimpleMemoryIntent,
        *,
        confirmation_id: Optional[str] = None,
    ) -> dict:
        return {
            "created": 0,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 1,
            "records": [
                {
                    "kind": "simple_memory",
                    "type": intent.memory_type,
                    "action": "confirmation_requested",
                    "id": confirmation_id,
                    "title": intent.content,
                    "metadata": pending_confirmation_metadata(intent.metadata),
                }
            ],
        }

    def _simple_memory_saved_summary(
        self,
        intent: SimpleMemoryIntent,
        record: dict,
    ) -> dict:
        return {
            "created": 1,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": "long_term_memory",
                    "type": intent.memory_type,
                    "action": "direct_saved",
                    "id": record.get("id"),
                    "title": intent.content,
                    "metadata": direct_save_metadata(intent.metadata),
                }
            ],
        }

    def _simple_memory_rejected_summary(
        self,
        intent: SimpleMemoryIntent,
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
                    "kind": "simple_memory",
                    "type": intent.memory_type,
                    "action": "rejected",
                    "title": intent.content,
                    "metadata": pending_confirmation_metadata(intent.metadata),
                }
            ],
        }

    def _simple_memory_failed_summary(
        self,
        intent: SimpleMemoryIntent,
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
                    "kind": "simple_memory",
                    "type": intent.memory_type,
                    "action": "save_failed",
                    "title": intent.content,
                    "metadata": pending_confirmation_metadata(intent.metadata),
                }
            ],
        }
