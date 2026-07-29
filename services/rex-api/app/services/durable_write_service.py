"""Propose durable writes; confirm/apply lives in DurableWritePendingFlowMixin."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import MemoryDisciplineDecision
from app.services.assistant_proposal_settings import (
    AssistantProposalSettings,
    fail_closed_proposal_settings,
    resolve_assistant_proposal_settings,
)
from app.services.body_display_text import (
    GoalCommand,
    SimpleMemoryIntent,
    clarification_turn_result,
    goal_title,
)
from app.services.conversation_pending_action import ConversationPendingActionService
from app.services.durable_write_applier import DurableWriteApplier
from app.services.durable_write_builders import (
    proposal_from_discipline_decision,
    proposal_from_memory_update,
    proposal_from_open_thread,
    proposal_from_open_thread_update,
    proposal_from_person_note,
    proposal_from_person_state,
    proposal_from_record_delete,
    proposal_from_simple_memory,
)
from app.services.durable_write_goal_propose import DurableWriteGoalProposeMixin
from app.services.durable_write_pending import pending_action_for_durable_write
from app.services.durable_write_pending_flow import DurableWritePendingFlowMixin
from app.services.durable_write_proposal import DurableWriteProposal
from app.services.durable_write_proposal_refiner import DurableWriteProposalRefiner
from app.services.durable_write_results import (
    pending_memory_changes,
)
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_discipline_writes import (
    MemoryWriteError,
    find_long_term_memory_duplicate,
)
from app.services.plan_service import PlanService


class DurableWriteService(DurableWriteGoalProposeMixin, DurableWritePendingFlowMixin):
    def __init__(
        self,
        memory_service: Any,
        *,
        plan_service: Optional[PlanService] = None,
        applier: Optional[DurableWriteApplier] = None,
        ai_service: Any = None,
        proposal_refiner: Optional[DurableWriteProposalRefiner] = None,
        discipline: Optional[MemoryDisciplineService] = None,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)
        self.discipline = discipline or MemoryDisciplineService(memory_service)
        self.applier = applier or DurableWriteApplier(
            memory_service,
            plan_service=self.plan_service,
            discipline=self.discipline,
        )
        self._proposal_refiner = proposal_refiner or (
            DurableWriteProposalRefiner(ai_service) if ai_service is not None else None
        )

    async def propose_simple_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        use_person_card: bool = True,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        related = (
            await self._related_person_context(intent) if use_person_card else {}
        )
        try:
            duplicate = await find_long_term_memory_duplicate(
                self.discipline,
                payload={
                    "memory_type": intent.memory_type,
                    "content": intent.content,
                    "importance": intent.importance,
                    "metadata": dict(intent.metadata or {}),
                },
            )
        except MemoryWriteError:
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I understood that, but I couldn't check for related saved "
                    "items just now. Please try again in a moment."
                ),
            )
        if duplicate is not None:
            proposal = proposal_from_memory_update(
                intent,
                record_id=duplicate.record_id,
                previous_content=duplicate.previous_content,
                related=related,
                use_person_card=use_person_card,
            )
        else:
            proposal = proposal_from_simple_memory(
                intent,
                related=related,
                use_person_card=use_person_card,
            )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            response=response,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )

    async def propose_memory_update(
        self,
        intent: SimpleMemoryIntent,
        *,
        record_id: str,
        previous_content: str | None,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        use_person_card: bool = True,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        related = (
            await self._related_person_context(intent) if use_person_card else {}
        )
        proposal = proposal_from_memory_update(
            intent,
            record_id=record_id,
            previous_content=previous_content,
            related=related,
            use_person_card=use_person_card,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            response=response,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )

    async def propose_open_thread(
        self,
        *,
        title: str,
        summary: str | None,
        conversation_id: str,
        user_message: dict,
        response: str | None = None,
        conversation_messages: Optional[list[dict]] = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        proposal = proposal_from_open_thread(
            title=title,
            summary=summary,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            conversation_messages=conversation_messages,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )

    async def propose_open_thread_update(
        self,
        *,
        thread_id: str,
        title: str,
        summary: str | None,
        existing_title: str | None,
        conversation_id: str,
        user_message: dict,
        response: str | None = None,
        conversation_messages: Optional[list[dict]] = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        proposal = proposal_from_open_thread_update(
            thread_id=thread_id,
            title=title,
            summary=summary,
            existing_title=existing_title,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            conversation_messages=conversation_messages,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )

    async def propose_discipline_decision(
        self,
        decision: MemoryDisciplineDecision,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
    ) -> dict:
        title = goal_title(
            str(
                decision.payload.get("title")
                or decision.payload.get("description")
                or decision.payload.get("desired_outcome")
                or "this plan"
            )
        )
        proposal = proposal_from_discipline_decision(decision, title=title)
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
        )

    async def propose_delete(
        self,
        match,
        *,
        resolver_target: str,
        scope_tables: tuple[str, ...] = (),
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        proposal = proposal_from_record_delete(
            match,
            resolver_target=resolver_target,
            scope_tables=scope_tables,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            response=response,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )

    async def propose_person_state(
        self,
        *,
        entity_id: str,
        display_name: str,
        state: str,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        proposal = proposal_from_person_state(
            entity_id=entity_id,
            display_name=display_name,
            state=state,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            response=response,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )

    async def propose_person_note(
        self,
        *,
        entity_id: str,
        display_name: str,
        note: str,
        existing_notes: str | None = None,
        replace: bool = False,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        proposal = proposal_from_person_note(
            entity_id=entity_id,
            display_name=display_name,
            note=note,
            existing_notes=existing_notes,
            replace=replace,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            response=response,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )

    async def propose_proposal(
        self,
        proposal: DurableWriteProposal,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            response=response,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )

    async def _propose(
        self,
        proposal: DurableWriteProposal,
        *,
        conversation_id: str,
        user_message: dict,
        response: str | None = None,
        conversation_messages: Optional[list[dict]] = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        if self._proposal_refiner is not None:
            proposal = await self._proposal_refiner.refine(
                proposal,
                conversation_messages=list(conversation_messages or []),
                user_message=str(user_message.get("content") or ""),
            )
        settings = proposal_settings or await self._resolve_proposal_settings()
        show_cards = (
            surface_client_cards
            if surface_client_cards is not None
            else settings.uses_confirm_cards()
        )
        supersede_note = await self._pending().set_superseding(
            conversation_id,
            pending_action_for_durable_write(
                proposal=proposal,
                surface_client_cards=show_cards,
            ),
        )
        if response is not None:
            prompt = response
        elif show_cards:
            prompt = (
                f"{supersede_note}\n\n{proposal.assistant_prompt()}".strip()
                if supersede_note
                else proposal.assistant_prompt()
            )
        else:
            text_prompt = proposal.text_confirmation_prompt()
            prompt = (
                f"{supersede_note}\n\n{text_prompt}".strip()
                if supersede_note
                else text_prompt
            )
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=prompt,
            memory_changes=pending_memory_changes(
                proposal=proposal,
                surface_client_cards=show_cards,
            ),
        )

    async def _resolve_proposal_settings(self) -> AssistantProposalSettings:
        user_id = getattr(self.memory_service, "user_id", None)
        access_token = getattr(self.memory_service, "access_token", None)
        if user_id and access_token:
            try:
                from app.services.assistant_settings_repository import (
                    AssistantSettingsRepository,
                )

                repository = AssistantSettingsRepository(
                    user_id=user_id,
                    access_token=access_token,
                )
                return await repository.fetch_proposal_settings()
            except Exception:
                return fail_closed_proposal_settings()
        return resolve_assistant_proposal_settings({})

    async def _related_person_context(self, intent: SimpleMemoryIntent) -> dict:
        if str((intent.metadata or {}).get("fact_kind") or "") != "relationship":
            return {}
        from app.services.person_confirm_proposal import resolve_related_person_context

        return await resolve_related_person_context(self.memory_service, intent)

    def _pending(self) -> ConversationPendingActionService:
        return ConversationPendingActionService(self.memory_service)
