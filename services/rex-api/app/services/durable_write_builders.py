"""Build durable write proposals from intents and commands."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import MemoryDisciplineAction, MemoryDisciplineDecision
from app.services.conversational_plan_decision_store import decision_to_dict
from app.services.conversational_plan_prompts import confirmation_prompt
from app.services.conversational_plan_results import write_kind_for_action
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


def proposal_from_open_thread(
    *,
    title: str,
    summary: str | None,
    conversation_id: str,
    source_message_id: str | None,
) -> DurableWriteProposal:
    body = summary or title
    return DurableWriteProposal(
        write_kind="open_thread",
        title=title,
        body=body,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "open_thread",
            "payload": {
                "title": title,
                "summary": summary or body,
                "status": "active",
                "source": "user_confirmed",
                "metadata": {"source": "durable_write_confirmed"},
            },
            "conversation_id": conversation_id,
            "source_message_id": source_message_id,
        },
    )


def proposal_from_discipline_decision(
    decision: MemoryDisciplineDecision,
    *,
    title: str,
) -> DurableWriteProposal:
    payload = decision.payload
    body = str(
        payload.get("description")
        or payload.get("desired_outcome")
        or title
    )
    target_label = None
    parent_id = decision.metadata.get("parent_plan_id") or payload.get("plan_id")
    if parent_id:
        for record in decision.related_records:
            if record.id == parent_id and record.title:
                target_label = str(record.title)
                break
    merge_target = decision.metadata.get("merge_disclosed_to")
    if isinstance(merge_target, str):
        merge_target = merge_target.strip() or None
    else:
        merge_target = None
    write_kind = write_kind_for_action(decision.action)
    return DurableWriteProposal(
        write_kind=write_kind,
        title=title,
        body=body,
        target_label=target_label,
        merge_target_title=merge_target,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "discipline_decision",
            "decision": decision_to_dict(decision),
        },
        custom_assistant_prompt=confirmation_prompt(decision),
    )


def _memory_title(content: str) -> str:
    text = str(content or "").strip()
    if len(text) <= 72:
        return text
    return f"{text[:69].rstrip()}..."
