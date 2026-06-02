from typing import Optional, Protocol

from app.services.memory_intent_service import MemoryIntentService, SimpleMemoryIntent


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
    ) -> dict:
        pass


class MemoryTurnService:
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
        pending_intent = self.memory_intent_service.pending_confirmation_from_history(
            conversation_history
        )
        if pending_intent is not None:
            confirmation_decision = (
                self.memory_intent_service.classify_confirmation_reply(message)
            )
            if confirmation_decision == "confirm":
                return await self._save_confirmed_simple_memory(
                    pending_intent,
                    conversation_id=conversation_id,
                    user_message=user_message,
                )
            if confirmation_decision == "reject":
                return await self._reject_simple_memory(
                    pending_intent,
                    conversation_id=conversation_id,
                    user_message=user_message,
                )

        intent = self.memory_intent_service.detect_simple_memory(
            message,
            time_context=time_context,
        )
        if intent is None:
            return None

        public_response = intent.confirmation_question
        stored_response = self.memory_intent_service.with_confirmation_marker(
            public_response,
            intent,
        )
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            stored_response,
        )
        return {
            "conversation_id": conversation_id,
            "response": public_response,
            "user_message": user_message,
            "assistant_message": self.public_message(assistant_message),
            "memory_correction": None,
            "memory_changes": self._simple_memory_confirmation_summary(intent),
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
    ) -> dict:
        try:
            record = await self.memory_service.save_long_term_memory(
                memory_type=intent.memory_type,
                content=intent.content,
                source_conversation_id=conversation_id,
                source_message_id=str(user_message.get("id") or "") or None,
                importance=intent.importance,
            )
        except Exception:
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
    ) -> dict:
        response = self.memory_intent_service.rejected_response()
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
            "memory_changes": self._simple_memory_rejected_summary(intent),
            "messages": await self.recent_public_messages(conversation_id),
        }

    def _simple_memory_confirmation_summary(
        self,
        intent: SimpleMemoryIntent,
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
                    "title": intent.content,
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
                }
            ],
        }
