"""Unified saved-knowledge snapshot for Knows tab and inventory prompts."""

from __future__ import annotations

import re
from typing import Any, Optional

from app.services.plan_service import PlanService
from app.services.rule_service import RuleService


_ORG_SUFFIX_PATTERN = re.compile(
    r"\b(?:llc|inc|corp|corporation|company|co)\b",
    re.IGNORECASE,
)
_NON_ALNUM_PATTERN = re.compile(r"[^a-z0-9]+")


class SavedKnowledgeOverviewService:
    """Single read model for Knows == \"what do you know?\" inventory."""

    def __init__(
        self,
        memory_service: Any,
        *,
        plan_service: Optional[PlanService] = None,
        rule_service: Optional[RuleService] = None,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)
        self.rule_service = rule_service or RuleService(memory_service)

    async def get_overview(
        self,
        *,
        active_only: bool = True,
        limit: int = 100,
    ) -> dict[str, Any]:
        active = True if active_only else None
        memories = await self._list_memories(active=active, limit=limit)
        entities = await self._list_entities(active=active, limit=limit)
        rules = await self._list_rules(active=active, limit=limit)
        plans = await self._list_plans(active=active, limit=limit)

        people: list[dict[str, Any]] = []
        places: list[dict[str, Any]] = []
        other_entities: list[dict[str, Any]] = []
        for entity in entities:
            entity_type = str(entity.get("entity_type") or "").casefold()
            if entity_type == "person":
                people.append(entity)
            elif entity_type == "place":
                places.append(entity)
            else:
                other_entities.append(entity)

        covered_source_ids = _covered_source_memory_ids(people, places, other_entities)
        covered_workplace_labels = _covered_workplace_labels(people)
        deduped_other = _dedupe_similar_organizations(other_entities)
        filtered_other = [
            entity
            for entity in deduped_other
            if _normalize_org_label(str(entity.get("display_name") or ""))
            not in covered_workplace_labels
        ]
        filtered_facts = [
            memory
            for memory in memories
            if not _flat_memory_covered_by_entity(memory, covered_source_ids)
        ]

        counts = {
            "people": len(people),
            "places": len(places),
            "other_entities": len(filtered_other),
            "facts": len(filtered_facts),
            "rules": len(rules),
            "plans": len(plans),
            "total": (
                len(people)
                + len(places)
                + len(filtered_other)
                + len(filtered_facts)
                + len(rules)
                + len(plans)
            ),
        }

        return {
            "people": people,
            "places": places,
            "other_entities": filtered_other,
            "facts": filtered_facts,
            "rules": rules,
            "plans": plans,
            "counts": counts,
        }

    async def _list_memories(
        self, *, active: bool | None, limit: int
    ) -> list[dict[str, Any]]:
        list_fn = getattr(self.memory_service, "list_long_term_memory", None)
        if list_fn is None:
            return []
        items = await list_fn(active=active, limit=limit)
        return _sorted_by_importance(items)

    async def _list_entities(
        self, *, active: bool | None, limit: int
    ) -> list[dict[str, Any]]:
        list_fn = getattr(self.memory_service, "list_entities", None)
        if list_fn is None:
            return []
        items = await list_fn(active=active, limit=limit)
        return _sorted_by_importance(items)

    async def _list_rules(
        self, *, active: bool | None, limit: int
    ) -> list[dict[str, Any]]:
        try:
            items = await self.rule_service.list_rules(active=active, limit=limit)
        except Exception:
            return []
        return _sorted_by_importance(items, importance_key="priority")

    async def _list_plans(
        self, *, active: bool | None, limit: int
    ) -> list[dict[str, Any]]:
        try:
            items = await self.plan_service.list_plans(active=active, limit=limit)
        except Exception:
            return []
        return _sorted_by_importance(items, importance_key="priority")


def _sorted_by_importance(
    items: list[dict[str, Any]],
    *,
    importance_key: str = "importance",
) -> list[dict[str, Any]]:
    return sorted(
        items,
        key=lambda item: int(item.get(importance_key) or item.get("priority") or 0),
        reverse=True,
    )


def _normalize_org_label(value: str) -> str:
    normalized = _ORG_SUFFIX_PATTERN.sub("", value.casefold())
    normalized = _NON_ALNUM_PATTERN.sub(" ", normalized).strip()
    return normalized


def _covered_source_memory_ids(
    people: list[dict[str, Any]],
    places: list[dict[str, Any]],
    other_entities: list[dict[str, Any]],
) -> set[str]:
    covered: set[str] = set()
    for entity in (*people, *places, *other_entities):
        metadata = entity.get("metadata") or {}
        if not isinstance(metadata, dict):
            continue
        source_ids = metadata.get("source_memory_ids") or []
        if isinstance(source_ids, list):
            covered.update(str(item) for item in source_ids if item)
    return covered


def _covered_workplace_labels(people: list[dict[str, Any]]) -> set[str]:
    labels: set[str] = set()
    for person in people:
        metadata = person.get("metadata") or {}
        if not isinstance(metadata, dict):
            metadata = {}
        for key in ("workplace", "job", "employer", "company"):
            value = metadata.get(key) or person.get(key)
            if value:
                normalized = _normalize_org_label(str(value))
                if normalized:
                    labels.add(normalized)
    return labels


def _dedupe_similar_organizations(
    entities: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    best_by_label: dict[str, dict[str, Any]] = {}
    for entity in entities:
        label = _normalize_org_label(str(entity.get("display_name") or ""))
        if not label:
            continue
        existing = best_by_label.get(label)
        importance = int(entity.get("importance") or 0)
        if existing is None or importance > int(existing.get("importance") or 0):
            best_by_label[label] = entity
    kept_ids = {str(entity.get("id") or "") for entity in best_by_label.values()}
    return [
        entity
        for entity in entities
        if not _normalize_org_label(str(entity.get("display_name") or ""))
        or str(entity.get("id") or "") in kept_ids
    ]


def _flat_memory_covered_by_entity(
    memory: dict[str, Any],
    covered_source_ids: set[str],
) -> bool:
    memory_id = str(memory.get("id") or "")
    if memory_id and memory_id in covered_source_ids:
        return True
    metadata = memory.get("metadata") or {}
    if not isinstance(metadata, dict):
        return False
    canonical = str(metadata.get("canonical_entity_id") or "").strip()
    return bool(canonical)
