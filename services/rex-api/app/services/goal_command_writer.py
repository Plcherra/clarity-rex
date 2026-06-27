"""Persist explicit goal and commitment commands."""

from __future__ import annotations

from typing import Any, Optional

from app.models.commitment import CommitmentCreateRequest
from app.models.plan import PlanCreateRequest
from app.services.goal_command_parsing import (
    expand_goal_save_items,
    is_meta_instruction_body,
    normalize_equipment_goal_title,
    split_compound_goal_bodies,
)
from app.services.goal_command_results import (
    command_turn_result,
    failed_command_turn_result,
    multi_goal_turn_result,
)
from app.services.clarity_knowledge_labels import (
    commitment_saved_message,
    goal_saved_message,
    goals_saved_message,
)
from app.services.goal_command_formatting import goal_title, plan_type
from app.services.goal_command_types import GoalCommand


class GoalCommandWriter:
    def __init__(
        self,
        memory_service: Any,
        plan_service: Any,
        commitment_service: Any,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service
        self.commitment_service = commitment_service

    async def save_goal(
        self,
        command: GoalCommand,
        *,
        conversation_id: str,
        user_message: dict,
        response: Optional[str] = None,
        extra_records: Optional[list[dict]] = None,
    ) -> dict:
        if is_meta_instruction_body(command.body):
            return await failed_command_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I need the actual goal details before I can save that. "
                    "Tell me what you want to track."
                ),
                kind="plan",
                record_type=command.record_type,
                title=command.title,
            )
        split_items = expand_goal_save_items(
            title=command.title,
            description=command.body,
        ) or split_compound_goal_bodies(command.body)
        if len(split_items) > 1:
            split_commands = [
                GoalCommand(
                    kind="goal",
                    title=normalize_equipment_goal_title(item),
                    body=item,
                    record_type=plan_type(item),
                    target_text=command.target_text,
                )
                for item in split_items
            ]
            return await self.save_multiple_goals(
                split_commands,
                conversation_id=conversation_id,
                user_message=user_message,
                response=response,
                extra_records=extra_records,
            )
        try:
            record = await self.plan_service.create_plan(
                PlanCreateRequest(
                    plan_type=command.record_type,
                    title=command.title,
                    description=command.body,
                    desired_outcome=command.body,
                    source_conversation_id=conversation_id,
                    source_message_id=str(user_message.get("id") or "") or None,
                    target_date=command.target_text,
                    priority=4,
                    metadata={
                        "source": "explicit_goal_command",
                        "prevent_related_merge": True,
                    },
                )
            )
        except Exception:
            return await failed_command_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I understood that goal, but I couldn't save it just now. "
                    "Please try again in a moment."
                ),
                kind="plan",
                record_type=command.record_type,
                title=command.title,
            )
        resolved_response = response or goal_saved_message(command.title)
        return await command_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=resolved_response,
            kind="plan",
            record_type=command.record_type,
            record=record,
            title=command.title,
            extra_records=extra_records,
        )

    async def save_multiple_goals(
        self,
        commands: list[GoalCommand],
        *,
        conversation_id: str,
        user_message: dict,
        response: Optional[str] = None,
        extra_records: Optional[list[dict]] = None,
    ) -> dict:
        saved_records: list[dict] = []
        for command in commands:
            if is_meta_instruction_body(command.body):
                return await failed_command_turn_result(
                    self.memory_service,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    response=(
                        "I need the actual goal details before I can save those. "
                        "Tell me what you want to track."
                    ),
                    kind="plan",
                    record_type=command.record_type,
                    title=command.title,
                )
            try:
                record = await self.plan_service.create_plan(
                    PlanCreateRequest(
                        plan_type=command.record_type,
                        title=command.title,
                        description=command.body,
                        desired_outcome=command.body,
                        source_conversation_id=conversation_id,
                        source_message_id=str(user_message.get("id") or "") or None,
                        target_date=command.target_text,
                        priority=4,
                        metadata={
                            "source": "explicit_goal_command",
                            "prevent_related_merge": True,
                        },
                    )
                )
            except Exception:
                return await failed_command_turn_result(
                    self.memory_service,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    response=(
                        "I understood those goals, but I couldn't save them just now. "
                        "Please try again in a moment."
                    ),
                    kind="plan",
                    record_type=commands[0].record_type,
                    title=commands[0].title,
                )
            saved_records.append(record)

        if response is None:
            titles = ", ".join(command.title for command in commands)
            response = goals_saved_message(count=len(commands), titles=titles)
        return await multi_goal_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            commands=commands,
            records=saved_records,
            extra_records=extra_records,
        )

    async def save_commitment(
        self,
        command: GoalCommand,
        *,
        conversation_id: str,
        user_message: dict,
        response: Optional[str] = None,
        extra_records: Optional[list[dict]] = None,
    ) -> dict:
        if is_meta_instruction_body(command.body):
            return await failed_command_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I need the actual commitment details before I can save that. "
                    "Tell me what you want to stay accountable to."
                ),
                kind="commitment",
                record_type=command.record_type,
                title=command.title,
            )
        try:
            record = await self.commitment_service.create_commitment(
                CommitmentCreateRequest(
                    commitment_type=command.record_type,
                    title=command.title,
                    commitment_text=command.body,
                    source_conversation_id=conversation_id,
                    source_message_id=str(user_message.get("id") or "") or None,
                    due_at=command.due_text,
                    priority=5 if command.record_type == "habit" else 4,
                    metadata={"source": "explicit_commitment_command"},
                )
            )
        except Exception:
            return await failed_command_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I understood that commitment, but I couldn't save it just now. "
                    "Please try again in a moment."
                ),
                kind="commitment",
                record_type=command.record_type,
                title=command.title,
            )
        resolved_response = response or commitment_saved_message(command.title)
        return await command_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=resolved_response,
            kind="commitment",
            record_type=command.record_type,
            record=record,
            title=command.title,
            extra_records=extra_records,
        )
