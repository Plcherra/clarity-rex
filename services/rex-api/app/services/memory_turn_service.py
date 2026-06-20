from typing import Optional, Protocol

from app.services.memory_failure_reporting import (
    log_memory_failure,
    memory_degraded_metadata,
)
from app.services.memory_intent_service import MemoryIntentService, SimpleMemoryIntent
from app.services.memory_path_policy import (
    direct_save_metadata,
)
from app.services.memory_turn_direct_helpers import MemoryTurnDirectHelpers
from app.services.memory_turn_summaries import MemoryTurnSummaries
from app.services.person_memory_materializer import PersonMemoryMaterializer


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

    async def update_long_term_memory(
        self,
        memory_id: str,
        memory_type: Optional[str] = None,
        content: Optional[str] = None,
        importance: Optional[int] = None,
        active: Optional[bool] = None,
        superseded_by: Optional[str] = None,
        confidence: Optional[float] = None,
        correction_group: Optional[str] = None,
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


class MemoryTurnService(MemoryTurnDirectHelpers, MemoryTurnSummaries):
    """Handles direct low-risk memory saves before AI generation."""

    def __init__(
        self,
        memory_service: MemoryTurnStore,
        memory_intent_service: Optional[MemoryIntentService] = None,
    ) -> None:
        self.memory_service = memory_service
        self.memory_intent_service = memory_intent_service or MemoryIntentService()
        self.person_memory_materializer = PersonMemoryMaterializer()

    async def handle_turn(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[dict]:
        intent = self.memory_intent_service.detect_simple_memory(
            message,
            time_context=time_context,
        )
        if intent is None:
            if self.memory_intent_service.needs_direct_location_clarification(message):
                return await self._clarify_contextual_location(
                    conversation_id=conversation_id,
                    user_message=user_message,
                )
            if self.memory_intent_service.needs_unclear_memory_clarification(message):
                return await self._clarify_unclear_memory(
                    conversation_id=conversation_id,
                    user_message=user_message,
                )

            intent = self.memory_intent_service.detect_contextual_memory(
                message,
                conversation_history=conversation_history,
                time_context=time_context,
            )
            if intent is not None:
                if self.memory_intent_service.is_contextual_memory_reject_request(
                    message
                ):
                    return await self._reject_simple_memory(
                        intent,
                        conversation_id=conversation_id,
                        user_message=user_message,
                    )
                if self.memory_intent_service.is_contextual_memory_save_request(
                    message
                ):
                    return await self._save_confirmed_simple_memory(
                        intent,
                        conversation_id=conversation_id,
                        user_message=user_message,
                    )
            elif self.memory_intent_service.needs_contextual_location_clarification(
                message,
                conversation_history=conversation_history,
            ):
                return await self._clarify_contextual_location(
                    conversation_id=conversation_id,
                    user_message=user_message,
                )
        if intent is None:
            return None

        existing_memory = await self._find_equivalent_active_memory(intent)
        if existing_memory is not None:
            return await self._already_saved_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                record=existing_memory,
            )

        existing_topic_memory = await self._find_active_memory_by_topic(intent)
        if existing_topic_memory is not None:
            return await self._update_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                record=existing_topic_memory,
            )

        return await self._save_confirmed_simple_memory(
            intent,
            conversation_id=conversation_id,
            user_message=user_message,
        )

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
        return dict(message)

    async def _save_confirmed_simple_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        source_message_id: Optional[str] = None,
    ) -> dict:
        existing_memory = await self._find_equivalent_active_memory(intent)
        if existing_memory is not None:
            return await self._already_saved_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                record=existing_memory,
            )

        existing_topic_memory = await self._find_active_memory_by_topic(intent)
        if existing_topic_memory is not None:
            return await self._update_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                record=existing_topic_memory,
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
        except Exception as error:
            failure_metadata = memory_degraded_metadata(
                intent.metadata,
                operation="save_long_term_memory",
                failure_reason="durable_memory_save_failed",
                user_visible=True,
            )
            log_memory_failure(
                "direct_save_failed",
                operation="save_long_term_memory",
                error=error,
                conversation_id=conversation_id,
                memory_type=intent.memory_type,
                metadata=failure_metadata,
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
                "memory_changes": self._simple_memory_failed_summary(
                    intent,
                    metadata=failure_metadata,
                ),
                "messages": await self.recent_public_messages(conversation_id),
            }

        if not isinstance(record, dict) or not record.get("id"):
            failure_metadata = memory_degraded_metadata(
                intent.metadata,
                operation="save_long_term_memory",
                failure_reason="durable_memory_save_missing",
                user_visible=True,
            )
            log_memory_failure(
                "direct_save_missing",
                operation="save_long_term_memory",
                error=RuntimeError("memory save returned no record"),
                conversation_id=conversation_id,
                memory_type=intent.memory_type,
                metadata=failure_metadata,
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
                "memory_changes": self._simple_memory_failed_summary(
                    intent,
                    metadata=failure_metadata,
                ),
                "messages": await self.recent_public_messages(conversation_id),
            }

        response = self.memory_intent_service.saved_response(intent)
        await self._materialize_person_card(record)
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

    async def _clarify_unclear_memory(
        self,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        response = self.memory_intent_service.unclear_memory_clarification_response()
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
            "memory_changes": {
                "created": 0,
                "updated": 0,
                "archived": 0,
                "merged": 0,
                "skipped": 1,
                "confirmation_required": 0,
                "records": [
                    {
                        "kind": "simple_memory",
                        "type": "fact",
                        "action": "clarification_required",
                        "title": "Memory save needs a clear transcript.",
                        "metadata": {
                            "memory_path": "direct_save_guard",
                            "review_required": False,
                        },
                    }
                ],
            },
            "messages": await self.recent_public_messages(conversation_id),
        }

    async def _materialize_person_card(self, memory: dict) -> None:
        try:
            await self.person_memory_materializer.materialize_from_memory(
                self.memory_service,
                memory,
            )
        except Exception:
            return

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

    async def _clarify_contextual_location(
        self,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        response = self.memory_intent_service.location_clarification_response()
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
            "memory_changes": {
                "created": 0,
                "updated": 0,
                "archived": 0,
                "merged": 0,
                "skipped": 1,
                "confirmation_required": 0,
                "records": [
                    {
                        "kind": "simple_memory",
                        "type": "fact",
                        "action": "clarification_required",
                        "title": "Location correction needs a clear city name.",
                        "metadata": {
                            "fact_kind": "location",
                            "memory_path": "direct_save_guard",
                            "review_required": False,
                        },
                    }
                ],
            },
            "messages": await self.recent_public_messages(conversation_id),
        }
