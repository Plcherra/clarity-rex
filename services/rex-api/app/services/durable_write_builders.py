"""Build durable write proposals from intents and commands."""

from __future__ import annotations

from typing import Any, Optional

from app.services.durable_write_applier import preview_plan_merge_title
from app.services.durable_write_proposal import DurableWriteProposal
from app.services.goal_command_formatting import goal_title, plan_type
from app.services.goal_command_types import GoalCommand
from app.services.memory_intent_service import SimpleMemoryIntent
from app.services.memory_path_policy import direct_save_metadata
from app.services.plan_service import PlanService


def proposal_from_memory_update(
    intent: SimpleMemoryIntent,
    *,
    record_id: str,
    previous_content: str | None = None,
) -> DurableWriteProposal:
    metadata = direct_save_metadata(
        {
            **intent.metadata,
            "updated_from_memory_id": record_id,
            "previous_content": previous_content,
        }
    )
    title = _memory_title(intent.content)
    return DurableWriteProposal(
        write_kind="memory",
        title=title,
        body=intent.content,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "memory_update",
            "payload": {
                "memory_id": record_id,
                "memory_type": intent.memory_type,
                "content": intent.content,
                "importance": intent.importance,
                "metadata": metadata,
            },
        },
    )


def proposal_from_simple_memory(intent: SimpleMemoryIntent) -> DurableWriteProposal:
    metadata = direct_save_metadata(intent.metadata)
    title = _memory_title(intent.content)
    return DurableWriteProposal(
        write_kind="memory",
        title=title,
        body=intent.content,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "memory",
            "payload": {
                "memory_type": intent.memory_type,
                "content": intent.content,
                "importance": intent.importance,
                "metadata": metadata,
            },
        },
    )


async def proposal_from_goal_command(
    command: GoalCommand,
    *,
    plan_service: PlanService,
    conversation_id: str,
    source_message_id: str | None,
) -> DurableWriteProposal:
    title = goal_title(command.title)
    body = command.body
    record_type = command.record_type
    merge_title = await preview_plan_merge_title(
        plan_service,
        plan_type=record_type,
        title=title,
    )
    metadata = {"source": "durable_write_confirmed"}
    payload = {
        "plan_type": record_type,
        "title": title,
        "description": body,
        "desired_outcome": body,
        "priority": 4,
        "target_date": command.target_text,
        "metadata": metadata,
    }
    return DurableWriteProposal(
        write_kind="plan",
        title=title,
        body=body,
        merge_target_title=merge_title,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "plan",
            "payload": payload,
            "conversation_id": conversation_id,
            "source_message_id": source_message_id,
        },
    )


async def proposal_from_commitment_command(
    command: GoalCommand,
    *,
    conversation_id: str,
    source_message_id: str | None,
) -> DurableWriteProposal:
    title = goal_title(command.title)
    body = command.body
    return DurableWriteProposal(
        write_kind="commitment",
        title=title,
        body=body,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "commitment",
            "payload": {
                "commitment_type": command.record_type,
                "title": title,
                "commitment_text": body,
                "due_at": command.due_text,
                "priority": 5 if command.record_type == "habit" else 4,
                "metadata": {"source": "durable_write_confirmed"},
            },
            "conversation_id": conversation_id,
            "source_message_id": source_message_id,
        },
    )


def _memory_title(content: str) -> str:
    text = str(content or "").strip()
    if len(text) <= 72:
        return text
    return f"{text[:69].rstrip()}..."
