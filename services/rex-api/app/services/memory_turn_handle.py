"""Orchestration for memory turn routing before AI generation."""

from __future__ import annotations

from typing import Optional

from app.services.conversation_pending_action import (
    is_delete_confirmation_message,
    is_delete_rejection_message,
)
from app.services.memory_correction_types import CorrectionIntentType
from app.services.memory_delete_reference import is_vague_delete_target


class MemoryTurnHandleMixin:
    async def handle_turn(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        time_context: dict,
        pending_action=None,
    ) -> Optional[dict]:
        delete_confirmation = self._pending_delete_request_for_confirmation(
            message,
            conversation_history,
            pending_action,
        )
        if delete_confirmation is not None:
            scope_tables = ()
            if pending_action is not None:
                scope_tables = getattr(pending_action, "scope_tables", ()) or ()
            if is_delete_confirmation_message(message):
                return await self._apply_confirmed_delete(
                    delete_confirmation,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    scope_tables=scope_tables,
                )
            if is_delete_rejection_message(message):
                return await self._reject_confirmed_delete(
                    conversation_id=conversation_id,
                    user_message=user_message,
                )

        correction_turn = await self._try_apply_direct_correction(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
        )
        if correction_turn is not None:
            return correction_turn

        delete_intent = self.memory_correction_service.detect_correction_intent(
            message,
        )
        if (
            delete_intent.intent_type == CorrectionIntentType.REMOVE_OBSOLETE
            and delete_intent.old_value
        ):
            if (
                delete_intent.is_vague_delete_reference
                or is_vague_delete_target(delete_intent.old_value)
            ):
                return await self._ask_delete_specifics(
                    conversation_id=conversation_id,
                    user_message=user_message,
                )
            return await self._ask_delete_confirmation(
                delete_intent.old_value,
                conversation_id=conversation_id,
                user_message=user_message,
                conversation_history=conversation_history,
                scope_tables=delete_intent.delete_scope_tables,
                is_vague=delete_intent.is_vague_delete_reference,
            )

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
                    existing_memory = await self._find_equivalent_active_memory(
                        intent
                    )
                    if existing_memory is not None:
                        if self._should_defer_duplicate_contextual_confirmation(
                            message
                        ):
                            return None
                        return await self._already_saved_simple_memory(
                            intent,
                            conversation_id=conversation_id,
                            user_message=user_message,
                            record=existing_memory,
                        )
                    existing_topic_memory = await self._find_active_memory_by_topic(
                        intent
                    )
                    if existing_topic_memory is not None:
                        if self._should_defer_duplicate_contextual_confirmation(
                            message
                        ):
                            return None
                        return await self._propose_memory_update(
                            intent,
                            conversation_id=conversation_id,
                            user_message=user_message,
                            record=existing_topic_memory,
                            conversation_history=conversation_history,
                        )
                    return await self._propose_simple_memory(
                        intent,
                        conversation_id=conversation_id,
                        user_message=user_message,
                        conversation_history=conversation_history,
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
            return await self._propose_memory_update(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                record=existing_topic_memory,
                conversation_history=conversation_history,
            )

        return await self._propose_simple_memory(
            intent,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
        )

    def _should_defer_duplicate_contextual_confirmation(self, message: str) -> bool:
        normalized = self.memory_intent_service._normalize_reply(message)
        return normalized in {
            "yes",
            "yes please",
            "yep",
            "yeah",
            "sure",
            "please",
            "please do",
            "do it",
        }
