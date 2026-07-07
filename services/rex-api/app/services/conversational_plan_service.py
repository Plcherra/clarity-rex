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
from app.services.durable_write_pending import proposal_from_pending_action
from app.services.goal_command_formatting import goal_title
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.plan_service import PlanService
from app.services.save_intent_guards import user_declined_plan_save_recently


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
    ) -> Optional[dict]:
        pending = self._pending_action(pending_action)
        if pending is not None and not _allows_plan_proposal_while_pending(pending):
            return None

        if self.durable_write_service is None:
            return None

        if user_declined_plan_save_recently(conversation_history):
            return None

        if not self.detector.looks_like_conversational_plan(message):
            return None
        if self.detector.should_skip_for_explicit_command(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        ):
            return None

        payload = build_plan_candidate_payload(
            message,
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

        return await self.durable_write_service.propose_discipline_decision(
            decision,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_history,
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
