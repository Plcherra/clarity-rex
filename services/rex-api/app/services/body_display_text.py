"""Pure display helpers and minimal body types for durable write / plan apply."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date
from typing import Any, Optional, Protocol

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineDecision,
    MemoryRecordKind,
)


@dataclass(frozen=True)
class SimpleMemoryIntent:
    memory_type: str
    content: str
    # None when the brain did not rate the fact: a create defaults it, an
    # update leaves whatever importance the record already carries.
    importance: Optional[int]
    source: str = "simple_memory_intent"
    metadata: dict = field(default_factory=dict)


@dataclass(frozen=True)
class GoalCommand:
    kind: str
    title: str
    body: str
    record_type: str
    due_text: Optional[str] = None
    target_text: Optional[str] = None


class GoalCommandStore(Protocol):
    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        pass

    async def get_recent_messages(
        self,
        conversation_id: str,
        limit: int = 20,
    ) -> list[dict]:
        pass


def clean_goal_text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip(" .?!;:")


def goal_title(text: str) -> str:
    cleaned = clean_goal_text(text) or "Untitled"
    return cleaned[:1].upper() + cleaned[1:]


def plan_type(text: str) -> str:
    lowered = text.casefold()
    if any(term in lowered for term in ("save", "$", "money", "budget")):
        return "finance"
    if any(term in lowered for term in ("work", "job", "career")):
        return "career"
    if any(term in lowered for term in ("health", "gym", "work out")):
        return "health"
    return "personal"


def normalize_equipment_goal_title(text: str) -> str:
    cleaned = clean_goal_text(text)
    return cleaned or "Untitled"


def is_goals_inventory_query(message: str) -> bool:
    _ = message
    return False


def clamp_thread_title(title: str, *, max_length: int = 60) -> str:
    cleaned = re.sub(r"\s+", " ", str(title or "").strip()) or "Open Thread"
    if len(cleaned) <= max_length:
        return cleaned
    truncated = cleaned[: max_length - 3].rstrip()
    last_space = truncated.rfind(" ")
    if last_space > max_length // 2:
        truncated = truncated[:last_space]
    return f"{truncated}..."


def format_plan_target_date_label(iso_value: str) -> str:
    try:
        parsed = date.fromisoformat(iso_value)
    except ValueError:
        return iso_value
    return f"{parsed.strftime('%B')} {parsed.day}, {parsed.year}"


async def clarification_turn_result(
    memory_service: Any,
    *,
    conversation_id: str,
    user_message: dict,
    response: str,
    memory_changes: Optional[dict] = None,
) -> dict:
    assistant_message = await memory_service.save_message(
        conversation_id,
        "assistant",
        response,
    )
    resolved_memory_changes = memory_changes or {
        "created": 0,
        "updated": 0,
        "archived": 0,
        "merged": 0,
        "skipped": 0,
        "confirmation_required": 0,
        "records": [],
    }
    return {
        "conversation_id": conversation_id,
        "response": response,
        "user_message": user_message,
        "assistant_message": assistant_message,
        "memory_correction": None,
        "memory_changes": resolved_memory_changes,
        "messages": await memory_service.get_recent_messages(
            conversation_id,
            limit=20,
        ),
    }


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


def confirmation_prompt(decision: MemoryDisciplineDecision) -> str:
    title = _decision_title(decision)
    parent_title = _parent_plan_title(decision)
    if decision.action == MemoryDisciplineAction.CREATE_MILESTONE:
        return (
            f"I can save {title} as a milestone under your plan "
            f"{parent_title}. Tap confirm to save — nothing is saved until you confirm."
        )
    if decision.action == MemoryDisciplineAction.CREATE_PLAN:
        return (
            f"I can save {title} as a new plan in Clarity. "
            "Tap confirm to save — nothing is saved until you confirm."
        )
    if decision.action == MemoryDisciplineAction.UPDATE_PLAN:
        return (
            f"I can update your plan {parent_title} with this context: {title}. "
            "Tap confirm to save — nothing is saved until you confirm."
        )
    if decision.action == MemoryDisciplineAction.UPDATE_MILESTONE:
        return (
            f"I can update the milestone {title} under {parent_title}. "
            "Tap confirm to save — nothing is saved until you confirm."
        )
    if decision.action == MemoryDisciplineAction.CREATE_ENTITY_EVENT:
        entity_title = _entity_title(decision)
        return (
            f"I can save {title} as a note on {entity_title}. "
            "Tap confirm to save — nothing is saved until you confirm."
        )
    return (
        f"I can save {title} as a plan in Clarity. "
        "Tap confirm to save — nothing is saved until you confirm."
    )


def write_kind_for_action(action: MemoryDisciplineAction) -> str:
    return {
        MemoryDisciplineAction.CREATE_PLAN: "plan",
        MemoryDisciplineAction.ASK_CONFIRMATION: "plan",
        MemoryDisciplineAction.CREATE_MILESTONE: "milestone",
        MemoryDisciplineAction.UPDATE_PLAN: "update_plan",
        MemoryDisciplineAction.UPDATE_MILESTONE: "update_milestone",
        MemoryDisciplineAction.CREATE_ENTITY_EVENT: "entity_event",
    }.get(action, "plan")


def _decision_title(decision: MemoryDisciplineDecision) -> str:
    payload = decision.payload
    for key in ("title", "description", "desired_outcome"):
        value = str(payload.get(key) or "").strip()
        if value:
            return value
    return "this plan"


def _parent_plan_title(decision: MemoryDisciplineDecision) -> str:
    parent_id = decision.metadata.get("parent_plan_id") or decision.payload.get(
        "plan_id"
    )
    if not parent_id:
        return "your existing plan"
    for record in decision.related_records:
        if record.id == parent_id and record.title:
            return str(record.title)
    return "your existing plan"


def _entity_title(decision: MemoryDisciplineDecision) -> str:
    entity_id = decision.payload.get("entity_id")
    if entity_id:
        for record in decision.related_records:
            if record.id == entity_id and record.title:
                return str(record.title)
    return "that person"
