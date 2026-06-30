from __future__ import annotations

from typing import Any, Optional

from app.services.accountability_query_service import AccountabilityQueryService
from app.services.commitment_service import CommitmentService
from app.services.goal_command_detection import (
    GoalCommandDetector,
    pending_action_payload,
)
from app.services.goal_command_queries import try_list_goals_and_commitments
from app.services.goal_command_reclassify import GoalCommandReclassifier
from app.services.goal_command_types import GoalCommand, GoalCommandStore
from app.services.goal_command_writer import GoalCommandWriter
from app.services.memory_delete_reference import should_defer_to_delete_confirmation
from app.services.plan_service import PlanService


class GoalCommandService:
    """Handles explicit goal and commitment commands without an LLM call."""

    def __init__(
        self,
        memory_service: Any,
        *,
        plan_service: Optional[PlanService] = None,
        commitment_service: Optional[CommitmentService] = None,
        accountability_query_service: Optional[AccountabilityQueryService] = None,
        detector: Optional[GoalCommandDetector] = None,
        writer: Optional[GoalCommandWriter] = None,
        reclassifier: Optional[GoalCommandReclassifier] = None,
        durable_write_service=None,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)
        self.commitment_service = commitment_service or CommitmentService(
            memory_service
        )
        self.accountability_query_service = (
            accountability_query_service
            or AccountabilityQueryService(memory_service)
        )
        self._detector = detector or GoalCommandDetector()
        self._writer = writer or GoalCommandWriter(
            memory_service,
            self.plan_service,
            self.commitment_service,
        )
        self._reclassifier = reclassifier or GoalCommandReclassifier(
            memory_service,
            self._writer,
        )
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
        reclassified = await self._reclassifier.try_move_memory_to_goal(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if reclassified is not None:
            return reclassified

        listed = await try_list_goals_and_commitments(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
            accountability_query_service=self.accountability_query_service,
            memory_service=self.memory_service,
        )
        if listed is not None:
            return listed

        if should_defer_to_delete_confirmation(
            message,
            conversation_history,
            pending_action_payload(pending_action),
        ):
            return None

        commands = self.detect_commands(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
            pending_action=pending_action,
        )
        if not commands:
            return None

        if len(commands) == 1:
            command = commands[0]
            if self.durable_write_service is not None:
                if command.kind == "goal":
                    return await self.durable_write_service.propose_goal(
                        command,
                        conversation_id=conversation_id,
                        user_message=user_message,
                    )
                return await self.durable_write_service.propose_commitment(
                    command,
                    conversation_id=conversation_id,
                    user_message=user_message,
                )
            if command.kind == "goal":
                return await self._writer.save_goal(
                    command,
                    conversation_id=conversation_id,
                    user_message=user_message,
                )
            return await self._writer.save_commitment(
                command,
                conversation_id=conversation_id,
                user_message=user_message,
            )
        if self.durable_write_service is not None:
            return await self.durable_write_service.propose_goal(
                commands[0],
                conversation_id=conversation_id,
                user_message=user_message,
            )
        return await self._writer.save_multiple_goals(
            commands,
            conversation_id=conversation_id,
            user_message=user_message,
        )

    def detect_commands(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
        pending_action=None,
    ) -> list[GoalCommand]:
        return self._detector.detect_commands(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
            pending_action=pending_action,
        )

    def detect_command(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[GoalCommand]:
        return self._detector.detect_command(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )


__all__ = ["GoalCommand", "GoalCommandService", "GoalCommandStore"]
