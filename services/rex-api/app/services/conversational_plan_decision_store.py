"""Serialize discipline decisions into pending actions and back."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineDecision,
    MemoryRecordKind,
    MemoryRelatedRecord,
)
from app.services.conversation_pending_action import PendingAction


def pending_action_for_plan_save(
    *,
    title: str,
    decision: MemoryDisciplineDecision,
) -> PendingAction:
    return PendingAction(
        action_type="save_plan",
        target_type=decision.record_kind.value,
        target_id=str(decision.target_id or ""),
        target_label=title,
        resolver_target=title,
        context={"discipline_decision": decision_to_dict(decision)},
    )


def decision_from_pending_action(
    pending_action: PendingAction | dict | None,
) -> Optional[MemoryDisciplineDecision]:
    if pending_action is None:
        return None
    if isinstance(pending_action, PendingAction):
        context = pending_action.context
        action_type = pending_action.action_type
    elif isinstance(pending_action, dict):
        context = pending_action.get("context") or {}
        action_type = str(pending_action.get("action_type") or "")
    else:
        return None
    if action_type != "save_plan":
        return None
    raw = context.get("discipline_decision") if isinstance(context, dict) else None
    if not isinstance(raw, dict):
        return None
    return decision_from_dict(raw)


def decision_to_dict(decision: MemoryDisciplineDecision) -> dict[str, Any]:
    return {
        "action": decision.action.value,
        "record_kind": decision.record_kind.value,
        "payload": dict(decision.payload),
        "reason": decision.reason,
        "confidence": decision.confidence,
        "target_table": decision.target_table,
        "target_id": decision.target_id,
        "requires_confirmation": decision.requires_confirmation,
        "related_records": [
            record.model_dump() for record in decision.related_records
        ],
        "metadata": dict(decision.metadata),
    }


def decision_from_dict(raw: dict[str, Any]) -> MemoryDisciplineDecision:
    related_records = [
        MemoryRelatedRecord(**record)
        for record in raw.get("related_records") or []
        if isinstance(record, dict)
    ]
    return MemoryDisciplineDecision(
        action=MemoryDisciplineAction(str(raw.get("action"))),
        record_kind=MemoryRecordKind(str(raw.get("record_kind"))),
        payload=dict(raw.get("payload") or {}),
        reason=str(raw.get("reason") or ""),
        confidence=float(raw.get("confidence") or 0.75),
        target_table=raw.get("target_table"),
        target_id=raw.get("target_id"),
        requires_confirmation=bool(raw.get("requires_confirmation")),
        related_records=related_records,
        metadata=dict(raw.get("metadata") or {}),
    )


def confirmed_decision(decision: MemoryDisciplineDecision) -> MemoryDisciplineDecision:
    if decision.action == MemoryDisciplineAction.ASK_CONFIRMATION:
        payload = dict(decision.payload)
        metadata = {
            **dict(payload.get("metadata") or {}),
            **decision.metadata,
            "source": "conversational_plan_confirmed",
        }
        payload["metadata"] = metadata
        return decision.model_copy(
            update={
                "action": MemoryDisciplineAction.CREATE_PLAN,
                "record_kind": MemoryRecordKind.PLAN,
                "payload": payload,
                "requires_confirmation": False,
            }
        )
    payload = dict(decision.payload)
    metadata = {
        **dict(payload.get("metadata") or {}),
        **decision.metadata,
        "source": "conversational_plan_confirmed",
    }
    payload["metadata"] = metadata
    return decision.model_copy(
        update={
            "payload": payload,
            "requires_confirmation": False,
        }
    )
