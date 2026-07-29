"""Build durable write proposals for plan milestones."""

from __future__ import annotations

from typing import Any, Optional

from app.services.body_display_text import goal_title
from app.services.durable_write_proposal import DurableWriteProposal


def proposal_from_milestone(
    *,
    plan_id: str,
    title: str,
    description: str | None,
    parent_title: str | None,
    target_date: str | None = None,
    conversation_id: str,
    source_message_id: str | None,
) -> DurableWriteProposal:
    safe_title = goal_title(title)
    clean_body = (description or "").strip()
    payload: dict[str, Any] = {
        "plan_id": plan_id,
        "title": safe_title,
        "description": clean_body or None,
        "milestone_type": "checkpoint",
        "priority": 3,
        "status": "open",
        "metadata": {"source": "durable_write_confirmed"},
    }
    if target_date:
        payload["target_date"] = target_date
    return DurableWriteProposal(
        write_kind="milestone",
        title=safe_title,
        body=clean_body,
        target_label=(parent_title or "").strip() or None,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "milestone",
            "payload": payload,
            "conversation_id": conversation_id,
            "source_message_id": source_message_id,
        },
    )


def proposal_from_milestone_update(
    *,
    milestone_id: str,
    plan_id: str,
    title: str,
    description: str | None,
    existing_title: str | None,
    parent_title: str | None = None,
    target_date: str | None = None,
    status: str | None = None,
) -> DurableWriteProposal:
    safe_title = goal_title(title)
    clean_body = (description or "").strip()
    prior = (existing_title or "").strip()
    payload: dict[str, Any] = {
        "milestone_id": milestone_id,
        "plan_id": plan_id,
        "title": safe_title,
        "description": clean_body or None,
        "metadata": {"source": "durable_write_confirmed"},
    }
    if target_date:
        payload["target_date"] = target_date
    if status:
        payload["status"] = status
    label = (parent_title or "").strip() or prior or None
    return DurableWriteProposal(
        write_kind="update_milestone",
        title=safe_title,
        body=clean_body,
        target_label=label,
        editable_fields=("title", "body"),
        apply_snapshot={
            "type": "milestone_update",
            "payload": payload,
        },
    )
