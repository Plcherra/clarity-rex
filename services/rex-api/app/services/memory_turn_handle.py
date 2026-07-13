"""Orchestration for memory turn routing before AI generation."""

from __future__ import annotations

from typing import Optional

from app.services.assistant_proposal_settings import (
    AssistantProposalSettings,
    PROPOSAL_KIND_MEMORY,
    fail_closed_proposal_settings,
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
        settings = proposal_settings or fail_closed_proposal_settings()
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
                if not allow_auto_memory:
                    # Off: no ask, no card — including contextual "yes save that".
                    return None
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

        if not allow_auto_memory:
            # Off / disabled memory kind: never auto-propose simple facts.
            return None

        relationship_gate = await self._gate_relationship_person_intent(
            intent,
            conversation_id=conversation_id,
            user_message=user_message,
            proposal_settings=settings,
        )
        if relationship_gate is False:
            return None
        if relationship_gate is not None:
            return relationship_gate

        use_person_card = _should_use_person_card(intent, settings)

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
                use_person_card=use_person_card,
            )

        return await self._propose_simple_memory(
            intent,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            use_person_card=use_person_card,
        )

    async def _gate_relationship_person_intent(
        self,
        intent,
        *,
        conversation_id: str,
        user_message: dict,
        proposal_settings: AssistantProposalSettings,
    ):
        """Return a turn result, False to skip, or None to continue propose."""
        if str((intent.metadata or {}).get("fact_kind") or "") != "relationship":
            return None
        if not proposal_settings.allows_kind(PROPOSAL_KIND_MEMORY):
            return False

        from app.services.person_confirm_proposal import (
            count_person_card_fields,
            person_card_from_intent,
            resolve_related_person_context,
        )

        related = {}
        if getattr(self, "memory_service", None) is not None:
            related = await resolve_related_person_context(self.memory_service, intent)
        person_card = person_card_from_intent(intent, related=related)
        filled = count_person_card_fields(person_card)

        if proposal_settings.uses_text_offers() and filled < 2:
            from app.services.goal_command_results import clarification_turn_result

            missing = _missing_person_field_prompt(person_card)
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=missing,
            )
        return None

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
                use_person_card=_should_use_person_card(intent, proposal_settings),
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
            use_person_card=_should_use_person_card(intent, proposal_settings),
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


def _should_use_person_card(intent, settings: AssistantProposalSettings) -> bool:
    if str((intent.metadata or {}).get("fact_kind") or "") != "relationship":
        return False
    return settings.auto_proposals_enabled()


def _missing_person_field_prompt(person_card: dict) -> str:
    has_name = bool(str(person_card.get("display_name") or "").strip())
    has_relationship = bool(str(person_card.get("relationship") or "").strip())
    if has_name and not has_relationship:
        return (
            f"Got it — {person_card.get('display_name')}. "
            "What's their relationship to you (for example mom, dad, or friend)?"
        )
    if has_relationship and not has_name:
        relationship = person_card.get("relationship")
        return (
            f"I can save your {relationship}. "
            "What's their name?"
        )
    return (
        "I can save a person card — tell me at least two details, "
        "like a name and relationship."
    )
