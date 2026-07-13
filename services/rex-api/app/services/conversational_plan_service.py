"""Handle conversational plan candidates with discipline and user confirmation."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineCandidate,
    MemoryRecordKind,
    MemoryDisciplineDecision,
)
from app.services.conversation_pending_action import PendingAction
from app.services.conversational_plan_candidate import build_plan_candidate_payload
from app.services.conversational_plan_detection import ConversationalPlanDetector
from app.services.conversational_plan_offer import (
    is_plan_offer_affirmation,
    is_plan_offer_decline,
    plan_offer_state_from_history,
)
from app.services.durable_write_pending import proposal_from_pending_action
from app.services.goal_command_results import clarification_turn_result
from app.services.goal_command_formatting import goal_title
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.plan_service import PlanService
from app.services.save_intent_guards import user_declined_plan_save_recently
from app.services.assistant_proposal_settings import (
    AssistantProposalSettings,
    PROPOSAL_KIND_GOALS,
    fail_closed_proposal_settings,
)


class ConversationalPlanService:
    def __init__(
        self,
        memory_service: Any,
        *,
        discipline: Optional[MemoryDisciplineService] = None,
        detector: Optional[ConversationalPlanDetector] = None,
        plan_service: Optional[PlanService] = None,
        durable_write_service=None,
    ) -> None:
        self.memory_service = memory_service
        self.discipline = discipline or MemoryDisciplineService(memory_service)
        self.detector = detector or ConversationalPlanDetector()
        self.plan_service = plan_service or PlanService(memory_service)
        self.durable_write_service = durable_write_service

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
        if not settings.allows_kind(PROPOSAL_KIND_GOALS):
            return None

        pending = self._pending_action(pending_action)
        if pending is not None and not _allows_plan_proposal_while_pending(pending):
            return None

        if self.durable_write_service is None:
            return None

        if user_declined_plan_save_recently(conversation_history):
            return None

        offer = plan_offer_state_from_history(conversation_history)
        if is_plan_offer_decline(message, offer):
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response="Okay — I won't save that as a goal.",
            )
        if is_plan_offer_affirmation(message, offer):
            topic = str(offer.get("topic_message") or offer.get("offered_title") or "").strip()
            if topic:
                return await self._propose_from_topic(
                    topic,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    conversation_history=conversation_history,
                    time_context=time_context,
                    settings=settings,
                    pending=pending,
                    force_propose=True,
                )

        if not self.detector.looks_like_conversational_plan(message):
            return None
        if self.detector.should_skip_for_explicit_command(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        ):
            return None

        return await self._propose_from_topic(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
            settings=settings,
            pending=pending,
            force_propose=False,
        )

    async def _propose_from_topic(
        self,
        topic: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        time_context: dict,
        settings: AssistantProposalSettings,
        pending: Optional[PendingAction],
        force_propose: bool,
    ) -> Optional[dict]:
        payload = build_plan_candidate_payload(
            topic,
            time_context=time_context,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        candidate = MemoryDisciplineCandidate(
            kind=MemoryRecordKind.PLAN,
            payload=payload,
            source_conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        decision = await self.discipline.decide(candidate)
        if decision.action == MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE:
            return None
        if not _requires_user_confirmation(decision):
            return None

        if decision.action in {
            MemoryDisciplineAction.CREATE_MILESTONE,
            MemoryDisciplineAction.UPDATE_PLAN,
            MemoryDisciplineAction.UPDATE_MILESTONE,
            MemoryDisciplineAction.CREATE_ENTITY_EVENT,
        }:
            return await self.durable_write_service.propose_discipline_decision(
                decision,
                conversation_id=conversation_id,
                user_message=user_message,
                conversation_messages=conversation_history,
            )

        title = str(payload.get("title") or goal_title(topic)).strip()

        if (
            force_propose
            or settings.uses_confirm_cards()
            or (pending is not None and _allows_plan_proposal_while_pending(pending))
        ):
            return await self.durable_write_service.propose_discipline_decision(
                decision,
                conversation_id=conversation_id,
                user_message=user_message,
                conversation_messages=conversation_history,
            )

        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=(
                f'I can save "{title}" as a goal in Goals if you want — '
                "just say the word."
            ),
        )

    def _pending_action(self, pending_action) -> Optional[PendingAction]:
        if isinstance(pending_action, PendingAction):
            return pending_action
        return PendingAction.from_dict(pending_action)


def _requires_user_confirmation(decision: MemoryDisciplineDecision) -> bool:
    return decision.action in {
        MemoryDisciplineAction.ASK_CONFIRMATION,
        MemoryDisciplineAction.CREATE_PLAN,
        MemoryDisciplineAction.CREATE_MILESTONE,
        MemoryDisciplineAction.UPDATE_PLAN,
        MemoryDisciplineAction.UPDATE_MILESTONE,
        MemoryDisciplineAction.CREATE_ENTITY_EVENT,
    }


def _allows_plan_proposal_while_pending(pending: PendingAction) -> bool:
    if pending.action_type == "delete":
        return True
    if pending.action_type != "durable_write":
        return False
    proposal = proposal_from_pending_action(pending)
    return proposal is not None and proposal.write_kind == "delete"
