"""Turn results for conversational plan confirmation flows."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import MemoryDisciplineAction, MemoryDisciplineDecision


def plan_save_proposal(
    *,
    decision: MemoryDisciplineDecision,
    title: str,
    index: int = 1,
) -> dict[str, Any]:
    action = _proposal_action(decision.action)
    return {
        "id": f"plan-save-{index}",
        "write_kind": _write_kind(decision.action),
        "action": action,
        "title": title,
        "body": str(decision.payload.get("description") or decision.payload.get("desired_outcome") or title),
        "target_label": _target_label(decision),
        "merge_target_title": decision.metadata.get("merge_disclosed_to"),
        "editable_fields": ["title", "body"],
        "payload": {},
        "confirmation_text": _plain_confirmation_text(decision, title=title),
        "risk_level": "medium",
        "status": "pending",
    }


def pending_memory_changes(
    *,
    decision: MemoryDisciplineDecision,
    title: str,
) -> dict[str, Any]:
    proposal = plan_save_proposal(decision=decision, title=title)
    return {
        "created": 0,
        "updated": 0,
        "archived": 0,
        "merged": 0,
        "skipped": 0,
        "confirmation_required": 1,
        "write_proposals": [proposal],
        "plan_save_proposals": [proposal],
    }


def applied_memory_changes(
    *,
    decision: MemoryDisciplineDecision,
    record: dict[str, Any],
    title: str,
    merged: bool = False,
) -> dict[str, Any]:
    is_update = decision.action in {
        MemoryDisciplineAction.UPDATE_PLAN,
        MemoryDisciplineAction.UPDATE_MILESTONE,
        MemoryDisciplineAction.UPDATE_COMMITMENT,
    }
    created = 0 if is_update or merged else 1
    updated = 1 if is_update else 0
    merged_count = 1 if merged else 0
    proposal = plan_save_proposal(decision=decision, title=title)
    applied = dict(proposal)
    applied["status"] = "applied"
    return {
        "created": created,
        "updated": updated,
        "archived": 0,
        "merged": merged_count,
        "skipped": 0,
        "confirmation_required": 0,
        "write_proposals": [applied],
        "plan_save_proposals": [applied],
        "applied_record": {
            "id": record.get("id"),
            "title": title,
            "write_kind": applied.get("write_kind"),
        },
    }


def _proposal_action(action: MemoryDisciplineAction) -> str:
    return {
        MemoryDisciplineAction.CREATE_PLAN: "save_plan",
        MemoryDisciplineAction.ASK_CONFIRMATION: "save_plan",
        MemoryDisciplineAction.CREATE_MILESTONE: "save_plan_milestone",
        MemoryDisciplineAction.CREATE_COMMITMENT: "save_commitment",
        MemoryDisciplineAction.UPDATE_PLAN: "update_plan",
        MemoryDisciplineAction.UPDATE_MILESTONE: "update_plan_milestone",
        MemoryDisciplineAction.UPDATE_COMMITMENT: "update_commitment",
        MemoryDisciplineAction.CREATE_ENTITY_EVENT: "save_entity_event",
    }.get(action, "save_plan")


def _write_kind(action: MemoryDisciplineAction) -> str:
    return {
        MemoryDisciplineAction.CREATE_PLAN: "plan",
        MemoryDisciplineAction.ASK_CONFIRMATION: "plan",
        MemoryDisciplineAction.CREATE_MILESTONE: "milestone",
        MemoryDisciplineAction.CREATE_COMMITMENT: "commitment",
        MemoryDisciplineAction.UPDATE_PLAN: "update_plan",
        MemoryDisciplineAction.UPDATE_MILESTONE: "update_milestone",
        MemoryDisciplineAction.UPDATE_COMMITMENT: "update_commitment",
        MemoryDisciplineAction.CREATE_ENTITY_EVENT: "entity_event",
    }.get(action, "plan")


def _target_label(decision: MemoryDisciplineDecision) -> str | None:
    parent_id = decision.metadata.get("parent_plan_id") or decision.payload.get(
        "plan_id"
    )
    if not parent_id:
        return None
    for record in decision.related_records:
        if record.id == parent_id and record.title:
            return str(record.title)
    return None


def _plain_confirmation_text(
    decision: MemoryDisciplineDecision,
    *,
    title: str,
) -> str:
    parent_id = decision.metadata.get("parent_plan_id") or decision.payload.get(
        "plan_id"
    )
    parent_title = None
    if parent_id:
        for record in decision.related_records:
            if record.id == parent_id and record.title:
                parent_title = str(record.title)
                break
    if decision.action == MemoryDisciplineAction.CREATE_MILESTONE:
        if parent_title:
            return (
                f"Save {title} as a milestone under {parent_title}?"
            )
        return f"Save {title} as a milestone under your existing plan?"
    if decision.action == MemoryDisciplineAction.CREATE_COMMITMENT:
        if parent_title:
            return f"Save {title} as a commitment under {parent_title}?"
        return f"Save {title} as a commitment under your existing plan?"
    if decision.action == MemoryDisciplineAction.UPDATE_PLAN:
        if parent_title:
            return f"Update {parent_title} with this context: {title}?"
        return f"Update your plan with this context: {title}?"
    if decision.action == MemoryDisciplineAction.UPDATE_MILESTONE:
        return f"Update the milestone {title}?"
    if decision.action == MemoryDisciplineAction.UPDATE_COMMITMENT:
        return f"Update the commitment {title}?"
    if decision.action == MemoryDisciplineAction.CREATE_ENTITY_EVENT:
        return f"Save {title} as a related note?"
    return f"Save {title} as a plan in Clarity?"
