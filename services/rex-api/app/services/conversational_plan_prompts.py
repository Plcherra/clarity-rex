"""User-facing confirmation prompts for conversational plan saves."""

from __future__ import annotations

from app.models.memory_discipline import MemoryDisciplineAction, MemoryDisciplineDecision


def confirmation_prompt(decision: MemoryDisciplineDecision) -> str:
    title = _title(decision)
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


def saved_prompt(decision: MemoryDisciplineDecision, *, title: str) -> str:
    parent_title = _parent_plan_title(decision)
    if decision.action == MemoryDisciplineAction.CREATE_MILESTONE:
        return f"Saved {title} as a milestone under {parent_title}."
    if decision.action == MemoryDisciplineAction.UPDATE_PLAN:
        return f"Updated {parent_title} with that context."
    if decision.action == MemoryDisciplineAction.UPDATE_MILESTONE:
        return f"Updated the milestone {title} under {parent_title}."
    if decision.action == MemoryDisciplineAction.CREATE_ENTITY_EVENT:
        return f"Saved {title} as a note on {_entity_title(decision)}."
    return f"Saved {title} as a plan in Clarity."


def rejected_prompt(*, title: str) -> str:
    return f"Okay, I won't save {title} as a plan."


def failed_prompt(*, title: str) -> str:
    return (
        f"I understood the plan about {title}, but I couldn't save it just now. "
        "Please try again in a moment."
    )


def _title(decision: MemoryDisciplineDecision) -> str:
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
