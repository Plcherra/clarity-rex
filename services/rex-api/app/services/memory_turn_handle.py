"""Orchestration for memory turn routing before AI generation."""

from __future__ import annotations

from typing import Optional

from app.services.assistant_proposal_settings import (
    AssistantProposalSettings,
    PROPOSAL_KIND_MEMORY,
)


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
        proposal_settings: Optional[AssistantProposalSettings] = None,
    ) -> Optional[dict]:
        settings = proposal_settings or AssistantProposalSettings()
        allow_auto_memory = settings.allows_kind(PROPOSAL_KIND_MEMORY)
        correction_turn = await self._try_apply_direct_correction(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
        )
        if correction_turn is not None:
            return correction_turn

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
                    return await self._propose_contextual_memory(
                        intent,
                        conversation_id=conversation_id,
                        user_message=user_message,
                        conversation_history=conversation_history,
                        proposal_settings=settings,
                        explicit_request=True,
                    )
                if not allow_auto_memory:
                    return None
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

    async def _propose_contextual_memory(
        self,
        intent,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        proposal_settings: AssistantProposalSettings,
        explicit_request: bool = False,
    ):
        existing_memory = await self._find_equivalent_active_memory(intent)
        if existing_memory is not None:
            if self._should_defer_duplicate_contextual_confirmation(
                str(user_message.get("content") or "")
            ):
                return None
            return await self._already_saved_simple_memory(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                record=existing_memory,
            )
        existing_topic_memory = await self._find_active_memory_by_topic(intent)
        if existing_topic_memory is not None:
            if self._should_defer_duplicate_contextual_confirmation(
                str(user_message.get("content") or "")
            ):
                return None
            if (
                not explicit_request
                and proposal_settings.uses_text_offers()
            ):
                return await self._offer_contextual_memory_text(
                    intent,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    updating=True,
                )
            return await self._propose_memory_update(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                record=existing_topic_memory,
                conversation_history=conversation_history,
            )
        if not explicit_request and proposal_settings.uses_text_offers():
            return await self._offer_contextual_memory_text(
                intent,
                conversation_id=conversation_id,
                user_message=user_message,
                updating=False,
            )
        return await self._propose_simple_memory(
            intent,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
        )

    async def _offer_contextual_memory_text(
        self,
        intent,
        *,
        conversation_id: str,
        user_message: dict,
        updating: bool,
    ):
        from app.services.goal_command_results import clarification_turn_result

        label = str(intent.content or "that").strip()
        if updating:
            prompt = (
                f'I can update Knows with "{label}" if you want — just say the word.'
            )
        else:
            prompt = (
                f'I can save "{label}" to Knows if you want — just say the word.'
            )
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=prompt,
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
