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
        "action": action,
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
    return {
        "created": 0,
        "updated": 0,
        "archived": 0,
        "merged": 0,
        "skipped": 0,
        "confirmation_required": 1,
        "records": [
            {
                "kind": decision.record_kind.value,
                "type": str(decision.payload.get("plan_type") or "personal"),
                "action": "confirmation_pending",
                "title": title,
                "metadata": {
                    "source": "conversational_plan",
                    "discipline_action": decision.action.value,
                },
            }
        ],
        "plan_save_proposals": [plan_save_proposal(decision=decision, title=title)],
    }


def applied_memory_changes(
    *,
    decision: MemoryDisciplineDecision,
    record: dict[str, Any],
    title: str,
) -> dict[str, Any]:
    return {
        "created": 1,
        "updated": 0,
        "archived": 0,
        "merged": 0,
        "skipped": 0,
        "confirmation_required": 0,
        "records": [
            {
                "kind": _record_kind(decision),
                "type": str(
                    record.get("plan_type")
                    or record.get("commitment_type")
                    or decision.payload.get("plan_type")
                    or "personal"
                ),
                "action": "direct_saved",
                "id": record.get("id"),
                "title": title,
                "metadata": {"source": "conversational_plan_confirmed"},
            }
        ],
    }


def _proposal_action(action: MemoryDisciplineAction) -> str:
    return {
        MemoryDisciplineAction.CREATE_PLAN: "save_plan",
        MemoryDisciplineAction.ASK_CONFIRMATION: "save_plan",
        MemoryDisciplineAction.CREATE_MILESTONE: "save_plan_milestone",
        MemoryDisciplineAction.CREATE_COMMITMENT: "save_commitment",
    }.get(action, "save_plan")


def _record_kind(decision: MemoryDisciplineDecision) -> str:
    if decision.action == MemoryDisciplineAction.CREATE_MILESTONE:
        return "plan_milestone"
    if decision.action == MemoryDisciplineAction.CREATE_COMMITMENT:
        return "commitment"
    return "plan"


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
    return f"Save {title} as a plan in Clarity?"
