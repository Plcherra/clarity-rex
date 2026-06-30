"""Handle conversational plan candidates with discipline and user confirmation."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineCandidate,
    MemoryRecordKind,
    MemoryDisciplineDecision,
)
from app.services.conversation_pending_action import (
    ConversationPendingActionService,
    PendingAction,
    is_delete_confirmation_message,
    is_delete_rejection_message,
)
from app.services.conversational_plan_candidate import build_plan_candidate_payload
from app.services.conversational_plan_decision_store import (
    confirmed_decision,
    decision_from_pending_action,
    pending_action_for_plan_save,
)
from app.services.conversational_plan_detection import ConversationalPlanDetector
from app.services.conversational_plan_prompts import (
    confirmation_prompt,
    failed_prompt,
    rejected_prompt,
    saved_prompt,
)
from app.services.conversational_plan_results import (
    applied_memory_changes,
    pending_memory_changes,
)
from app.services.goal_command_formatting import goal_title
from app.services.goal_command_results import clarification_turn_result
from app.services.memory_discipline_service import MemoryDisciplineService


class ConversationalPlanService:
    def __init__(
        self,
        memory_service: Any,
        *,
        discipline: Optional[MemoryDisciplineService] = None,
        detector: Optional[ConversationalPlanDetector] = None,
    ) -> None:
        self.memory_service = memory_service
        self.discipline = discipline or MemoryDisciplineService(memory_service)
        self.detector = detector or ConversationalPlanDetector()

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
        if pending is not None and pending.action_type == "save_plan":
            if is_delete_confirmation_message(message):
                return await self._apply_confirmed_save(
                    pending,
                    conversation_id=conversation_id,
                    user_message=user_message,
                )
            if is_delete_rejection_message(message):
                return await self._reject_confirmed_save(
                    pending,
                    conversation_id=conversation_id,
                    user_message=user_message,
                )
            return None

        if pending is not None:
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

        title = goal_title(str(payload.get("title") or payload.get("description") or ""))
        await self._pending_action_service().set(
            conversation_id,
            pending_action_for_plan_save(title=title, decision=decision),
        )
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=confirmation_prompt(decision),
            memory_changes=pending_memory_changes(decision=decision, title=title),
        )

    async def _apply_confirmed_save(
        self,
        pending: PendingAction,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        decision = decision_from_pending_action(pending)
        if decision is None:
            await self._pending_action_service().clear(conversation_id)
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I couldn't find the pending plan save anymore. "
                    "Tell me again what you want saved."
                ),
            )

        title = pending.target_label or goal_title(
            str(decision.payload.get("title") or decision.payload.get("description") or "")
        )
        try:
            result = await self.discipline.apply_decision(
                confirmed_decision(decision)
            )
        except Exception:
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=failed_prompt(title=title),
            )

        if not result.get("applied"):
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=failed_prompt(title=title),
            )

        await self._pending_action_service().clear(conversation_id)
        record = result.get("record") or {}
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=saved_prompt(decision, title=title),
            memory_changes=applied_memory_changes(
                decision=decision,
                record=record,
                title=title,
            ),
        )

    async def _reject_confirmed_save(
        self,
        pending: PendingAction,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        title = pending.target_label or "that plan"
        await self._pending_action_service().clear(conversation_id)
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=rejected_prompt(title=title),
        )

    def _pending_action(self, pending_action) -> Optional[PendingAction]:
        if isinstance(pending_action, PendingAction):
            return pending_action
        return PendingAction.from_dict(pending_action)

    def _pending_action_service(self) -> ConversationPendingActionService:
        return ConversationPendingActionService(self.memory_service)


def _requires_user_confirmation(decision: MemoryDisciplineDecision) -> bool:
    return decision.action in {
        MemoryDisciplineAction.ASK_CONFIRMATION,
        MemoryDisciplineAction.CREATE_PLAN,
        MemoryDisciplineAction.CREATE_MILESTONE,
        MemoryDisciplineAction.CREATE_COMMITMENT,
    }
