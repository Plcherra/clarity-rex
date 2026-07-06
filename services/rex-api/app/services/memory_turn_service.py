from typing import Optional, Protocol

from app.services.memory_failure_reporting import (
    log_memory_failure,
    memory_degraded_metadata,
)
from app.services.memory_correction_service import MemoryCorrectionService
from app.services.memory_correction_types import CorrectionIntentType
from app.services.memory_delete_reference import is_vague_delete_target
from app.services.conversation_pending_action import (
    is_delete_confirmation_message,
    is_delete_rejection_message,
)
from app.services.memory_intent_service import MemoryIntentService, SimpleMemoryIntent
from app.models.memory_discipline import MemoryRecordKind
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_discipline_writes import MemoryWriteError, execute_disciplined_create
from app.services.memory_path_policy import (
    direct_save_metadata,
)
from app.services.memory_turn_correction_helpers import MemoryTurnCorrectionHelpers
from app.services.memory_turn_delete_helpers import MemoryTurnDeleteHelpers
from app.services.memory_turn_direct_helpers import MemoryTurnDirectHelpers
from app.services.memory_turn_handle import MemoryTurnHandleMixin
from app.services.memory_turn_summaries import MemoryTurnSummaries


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


class MemoryTurnService(
    MemoryTurnHandleMixin,
    MemoryTurnDeleteHelpers,
    MemoryTurnCorrectionHelpers,
    MemoryTurnDirectHelpers,
    MemoryTurnSummaries,
):
    """Handles direct low-risk memory saves before AI generation."""

    def __init__(
        self,
        memory_service: MemoryTurnStore,
        memory_intent_service: Optional[MemoryIntentService] = None,
        discipline: Optional[MemoryDisciplineService] = None,
        durable_write_service=None,
    ) -> None:
        self.memory_service = memory_service
        self.memory_intent_service = memory_intent_service or MemoryIntentService()
        self.discipline = discipline
        self.durable_write_service = durable_write_service
        self.memory_correction_service = MemoryCorrectionService(memory_service)

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

    async def _propose_simple_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: Optional[list[dict]] = None,
    ) -> dict:
        if self.durable_write_service is None:
            return await self._save_confirmed_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
            )
        return await self.durable_write_service.propose_simple_memory(
            intent,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_history,
        )

    async def _propose_memory_update(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        record: dict,
        conversation_history: Optional[list[dict]] = None,
    ) -> dict:
        record_id = str(record.get("id") or "")
        if self.durable_write_service is None:
            if record_id:
                return await self._update_simple_memory(
                    intent,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    record=record,
                )
            return await self._save_confirmed_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
            )
        if not record_id:
            return await self._clarify_unclear_memory(
                conversation_id=conversation_id,
                user_message=user_message,
            )
        intent = self._preserve_location_context(intent, record)
        return await self.durable_write_service.propose_memory_update(
            intent,
            record_id=record_id,
            previous_content=str(record.get("content") or "") or None,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_history,
        )

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
            record = await self._persist_confirmed_memory(
                intent,
                conversation_id=conversation_id,
                source_message_id=source_message_id
                or str(user_message.get("id") or "")
                or None,
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

        confirmed_record = await self._confirmed_visible_active_memory(record)
        if confirmed_record is None:
            failure_metadata = memory_degraded_metadata(
                intent.metadata,
                operation="save_long_term_memory_verify",
                failure_reason="durable_memory_save_not_visible",
                user_visible=True,
            )
            log_memory_failure(
                "direct_save_not_visible",
                operation="save_long_term_memory_verify",
                error=RuntimeError("saved memory was not visible in active memory"),
                conversation_id=conversation_id,
                memory_type=intent.memory_type,
                metadata=failure_metadata,
            )
            response = (
                "I understood that, but I couldn't confirm it is visible in Knows "
                "yet. Please try again in a moment."
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

        record = confirmed_record
        await self._materialize_person_card(record)
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

    async def _persist_confirmed_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        source_message_id: Optional[str],
        metadata: dict,
    ) -> dict:
        if self.discipline is None:
            return await self.memory_service.save_long_term_memory(
                memory_type=intent.memory_type,
                content=intent.content,
                source_conversation_id=conversation_id,
                source_message_id=source_message_id,
                importance=intent.importance,
                metadata=metadata,
            )

        payload = {
            "memory_type": intent.memory_type,
            "content": intent.content,
            "importance": intent.importance,
            "metadata": metadata,
        }

        async def create_fn(item: dict) -> dict:
            return await self.memory_service.save_long_term_memory(
                memory_type=str(item["memory_type"]),
                content=str(item["content"]),
                source_conversation_id=conversation_id,
                source_message_id=source_message_id,
                importance=int(item.get("importance") or 3),
                metadata=dict(item.get("metadata") or {}),
            )

        try:
            return await execute_disciplined_create(
                self.discipline,
                kind=MemoryRecordKind.LONG_TERM_MEMORY,
                payload=payload,
                create_fn=create_fn,
            )
        except MemoryWriteError as error:
            raise RuntimeError(error.detail) from error

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
