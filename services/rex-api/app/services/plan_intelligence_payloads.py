from __future__ import annotations

from typing import Any, Optional

from app.services.plan_intelligence_models import PLAN_INTELLIGENCE_VERSION
from app.services.plan_intelligence_rules import (
    commitment_type,
    is_dating_logistics,
    milestone_type,
)
from app.services.plan_intelligence_text import (
    append_unique_detail,
    clean,
    drop_none,
    join_parts,
)


def build_milestone_from_plan_candidate(
    candidate: dict[str, Any],
    parent_plan: dict[str, Any],
    *,
    existing_milestone: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    metadata = {
        **((existing_milestone.get("metadata") or {}) if existing_milestone else {}),
        **(candidate.get("metadata") or {}),
        "plan_intelligence_version": PLAN_INTELLIGENCE_VERSION,
        "routed_from": "plan_candidate",
        "parent_plan_id": parent_plan.get("id"),
        "parent_plan_title": parent_plan.get("title"),
    }
    return drop_none(
        {
            "plan_id": parent_plan.get("id"),
            "title": clean(candidate.get("title")) or "Plan milestone",
            "description": join_parts(
                candidate.get("description"),
                candidate.get("desired_outcome"),
            ),
            "milestone_type": milestone_type(candidate),
            "target_date": candidate.get("target_date"),
            "source_conversation_id": candidate.get("source_conversation_id"),
            "source_message_id": candidate.get("source_message_id"),
            "source_memory_id": candidate.get("source_memory_id"),
            "priority": candidate.get("priority", parent_plan.get("priority", 3)),
            "status": "open",
            "active": True,
            "metadata": metadata,
        }
    )


def build_commitment_from_small_step(
    candidate: dict[str, Any],
    parent_plan: dict[str, Any],
    milestone: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    metadata = {
        **(candidate.get("metadata") or {}),
        "plan_intelligence_version": PLAN_INTELLIGENCE_VERSION,
        "routed_from": "plan_candidate",
        "parent_plan_id": parent_plan.get("id"),
        "parent_plan_title": parent_plan.get("title"),
    }
    if milestone:
        metadata["parent_milestone_title"] = milestone.get("title")
    return drop_none(
        {
            "commitment_type": commitment_type(candidate, parent_plan),
            "title": clean(candidate.get("title")) or "Plan next step",
            "commitment_text": join_parts(
                candidate.get("description"),
                candidate.get("desired_outcome"),
            )
            or clean(candidate.get("title"))
            or "Complete the next step.",
            "plan_id": parent_plan.get("id"),
            "milestone_id": milestone.get("id") if milestone else None,
            "entity_id": candidate.get("primary_entity_id"),
            "source_conversation_id": candidate.get("source_conversation_id"),
            "source_message_id": candidate.get("source_message_id"),
            "source_memory_id": candidate.get("source_memory_id"),
            "priority": candidate.get("priority", parent_plan.get("priority", 3)),
            "status": "open",
            "active": True,
            "due_at": candidate.get("target_date"),
            "metadata": metadata,
        }
    )


def build_plan_description_update(
    candidate: dict[str, Any],
    parent_plan: dict[str, Any],
) -> dict[str, Any]:
    candidate_detail = join_parts(
        candidate.get("title"),
        candidate.get("description"),
        candidate.get("desired_outcome"),
    )
    description = append_unique_detail(
        clean(parent_plan.get("description")),
        candidate_detail,
    )
    return drop_none(
        {
            "title": parent_plan.get("title"),
            "description": description,
            "desired_outcome": parent_plan.get("desired_outcome"),
            "priority": parent_plan.get("priority", candidate.get("priority", 3)),
            "metadata": {
                **(parent_plan.get("metadata") or {}),
                "plan_intelligence_version": PLAN_INTELLIGENCE_VERSION,
                "routed_from": "plan_candidate",
                "merged_plan_detail": True,
                "merged_source_title": candidate.get("title"),
            },
        }
    )


def build_entity_event_from_plan_candidate(
    candidate: dict[str, Any],
    parent_plan: dict[str, Any],
) -> dict[str, Any]:
    title = clean(candidate.get("title")) or "Plan context"
    content = join_parts(
        candidate.get("description"),
        candidate.get("desired_outcome"),
    ) or title
    return drop_none(
        {
            "entity_id": candidate.get("entity_id")
            or candidate.get("primary_entity_id")
            or parent_plan.get("primary_entity_id"),
            "entity_name": candidate.get("entity_name"),
            "event_type": "relationship_update"
            if is_dating_logistics(candidate, parent_plan)
            else "note",
            "title": title,
            "content": content,
            "source_conversation_id": candidate.get("source_conversation_id"),
            "source_message_id": candidate.get("source_message_id"),
            "source_memory_id": candidate.get("source_memory_id"),
            "importance": candidate.get("priority", parent_plan.get("priority", 3)),
            "active": True,
            "metadata": {
                **(candidate.get("metadata") or {}),
                "plan_intelligence_version": PLAN_INTELLIGENCE_VERSION,
                "routed_from": "plan_candidate",
                "parent_plan_id": parent_plan.get("id"),
                "parent_plan_title": parent_plan.get("title"),
            },
        }
    )
