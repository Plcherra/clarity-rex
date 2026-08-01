"""Build durable write proposals from intents and commands."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import MemoryDisciplineAction, MemoryDisciplineDecision
from app.services.body_display_text import (
    GoalCommand,
    SimpleMemoryIntent,
    clamp_thread_title,
    confirmation_prompt,
    decision_to_dict,
    format_plan_target_date_label,
    goal_title,
    write_kind_for_action,
)
from app.services.durable_write_plan_apply import preview_plan_merge_title
from app.services.durable_write_proposal import DurableWriteProposal
from app.services.memory_path_policy import direct_save_metadata
from app.services.plan_service import PlanService


def proposal_from_memory_update(
    intent: SimpleMemoryIntent,
    *,
    record_id: str,
    previous_content: str | None = None,
    related: Optional[dict[str, Any]] = None,
    use_person_card: bool = True,
) -> DurableWriteProposal:
    if (
        use_person_card
        and str((intent.metadata or {}).get("fact_kind") or "") == "relationship"
    ):
        from app.services.person_confirm_proposal import proposal_from_relationship_memory

        return proposal_from_relationship_memory(
            intent,
            related=related,
            record_id=record_id,
            previous_content=previous_content,
        )
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


def proposal_from_simple_memory(
    intent: SimpleMemoryIntent,
    *,
    related: Optional[dict[str, Any]] = None,
    use_person_card: bool = True,
) -> DurableWriteProposal:
    if (
        use_person_card
        and str((intent.metadata or {}).get("fact_kind") or "") == "relationship"
    ):
        from app.services.person_confirm_proposal import proposal_from_relationship_memory

        return proposal_from_relationship_memory(intent, related=related)
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
        "target_amount": float(command.target_amount or 0),
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


def proposal_from_goal_update(
    *,
    plan_id: str,
    title: str,
    body: str | None,
    existing_title: str | None,
    target_date: str | None = None,
    target_amount: float | None = None,
    status: str | None = None,
) -> DurableWriteProposal:
    safe_title = goal_title(title)
    clean_body = (body or "").strip()
    prior = (existing_title or "").strip()
    payload: dict[str, Any] = {
        "plan_id": plan_id,
        "title": safe_title,
        "description": clean_body or None,
        "desired_outcome": clean_body or None,
        "metadata": {"source": "durable_write_confirmed"},
    }
    if target_date:
        payload["target_date"] = target_date
    if target_amount is not None:
        payload["target_amount"] = float(target_amount)
    if status:
        payload["status"] = status
    return DurableWriteProposal(
        write_kind="update_plan",
        title=safe_title,
        body=clean_body,
        target_label=prior or None,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "plan_update",
            "payload": payload,
        },
    )


def proposal_from_open_thread(
    *,
    title: str,
    summary: str | None,
    conversation_id: str,
    source_message_id: str | None,
) -> DurableWriteProposal:
    safe_title = clamp_thread_title(title)
    clean_summary = (summary or "").strip()
    return DurableWriteProposal(
        write_kind="open_thread",
        title=safe_title,
        body=clean_summary,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "open_thread",
            "payload": {
                "title": safe_title,
                "summary": clean_summary or None,
                "status": "active",
                "source": "user_confirmed",
                "metadata": {"source": "durable_write_confirmed"},
            },
            "conversation_id": conversation_id,
            "source_message_id": source_message_id,
        },
    )


def proposal_from_open_thread_update(
    *,
    thread_id: str,
    title: str,
    summary: str | None,
    existing_title: str | None,
    conversation_id: str,
    source_message_id: str | None,
) -> DurableWriteProposal:
    safe_title = clamp_thread_title(title)
    clean_summary = (summary or "").strip()
    prior = (existing_title or "").strip()
    return DurableWriteProposal(
        write_kind="open_thread",
        title=safe_title,
        body=clean_summary,
        target_label=prior or None,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "open_thread_update",
            "payload": {
                "thread_id": thread_id,
                "title": safe_title,
                "summary": clean_summary or None,
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


def proposal_from_bulk_plan_target_date(
    plans: list[dict[str, Any]],
    *,
    target_date: str,
    time_context: dict | None = None,
) -> DurableWriteProposal:
    titles = [str(plan.get("title") or "Untitled") for plan in plans if plan.get("id")]
    date_label = format_plan_target_date_label(target_date)
    body_lines = [f"- {title}" for title in titles]
    body = f"Set target date to {date_label} for:\n" + "\n".join(body_lines)
    joined_titles = ", ".join(titles[:3])
    if len(titles) > 3:
        joined_titles = f"{joined_titles}, and {len(titles) - 3} more"
    return DurableWriteProposal(
        write_kind="update_plan",
        title=f"Set dates for {len(titles)} goals",
        body=body,
        editable_fields=(),
        apply_snapshot={
            "type": "bulk_plan_target_date",
            "payload": {
                "target_date": target_date,
                "plans": [
                    {"id": plan.get("id"), "title": plan.get("title")}
                    for plan in plans
                    if plan.get("id")
                ],
            },
        },
        custom_assistant_prompt=(
            f"I can set the target date to {date_label} for "
            f"{len(titles)} goals: {joined_titles}. "
            "Tap confirm to save — nothing is saved until you confirm."
        ),
    )


def proposal_from_person_state(
    *,
    entity_id: str,
    display_name: str,
    state: str,
) -> DurableWriteProposal:
    label = str(display_name or "this person").strip() or "this person"
    state_text = str(state or "").strip()
    title = f"Update state for {label}"
    return DurableWriteProposal(
        write_kind="memory",
        title=title,
        body=state_text,
        editable_fields=("body",),
        apply_snapshot={
            "type": "person_state_update",
            "payload": {
                "entity_id": entity_id,
                "display_name": label,
                "summary": state_text,
            },
        },
        custom_assistant_prompt=(
            f"I can update {label}'s current state in Knows to: {state_text}. "
            "Tap confirm to save — nothing is saved until you confirm."
        ),
    )


def proposal_from_person_note(
    *,
    entity_id: str,
    display_name: str,
    note: str,
    existing_notes: str | None = None,
    replace: bool = False,
) -> DurableWriteProposal:
    label = str(display_name or "this person").strip() or "this person"
    note_text = str(note or "").strip()
    prior = str(existing_notes or "").strip()
    if replace or not prior:
        merged_notes = note_text
    else:
        merged_notes = f"{prior}\n{note_text}".strip()
    title = f"Add note for {label}"
    return DurableWriteProposal(
        write_kind="memory",
        title=title,
        body=note_text,
        editable_fields=("body",),
        apply_snapshot={
            "type": "person_note_update",
            "payload": {
                "entity_id": entity_id,
                "display_name": label,
                "note": note_text,
                "notes": merged_notes,
                "replace": replace,
            },
        },
        custom_assistant_prompt=(
            f"I can add this note on {label}'s person card: {note_text}. "
            "Tap confirm to save — nothing is saved until you confirm."
        ),
    )


def proposal_from_record_delete(
    match,
    *,
    resolver_target: str,
    scope_tables: tuple[str, ...] = (),
) -> DurableWriteProposal:
    title = str(match.title or resolver_target).strip() or resolver_target
    kind = _table_delete_label(str(match.table or ""))
    return DurableWriteProposal(
        write_kind="delete",
        title=title,
        body=title,
        editable_fields=(),
        risk_level="high",
        apply_snapshot={
            "type": "record_delete",
            "payload": {
                "table": match.table,
                "id": match.id,
                "title": title,
                "resolver_target": resolver_target,
                "scope_tables": list(scope_tables),
            },
        },
        custom_assistant_prompt=(
            f"I can permanently delete this {kind}: {title}. "
            "This action cannot be undone. Should I delete it?"
        ),
    )


def _table_delete_label(table: str) -> str:
    labels = {
        "long_term_memory": "memory note",
        "entities": "person or place card",
        "entity_events": "related note",
        "personal_rules": "rule",
        "plans": "goal",
        "plan_milestones": "milestone",
        "open_threads": "open thread",
    }
    return labels.get(table, "saved item")


def _memory_title(content: str) -> str:
    text = str(content or "").strip()
    if len(text) <= 72:
        return text
    return f"{text[:69].rstrip()}..."
