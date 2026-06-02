from typing import Any, Optional

from app.services.entity_normalization_service import EntityNormalizationService
from app.services.memory_structured_candidate_normalizer import (
    clean_text,
    normalized_text,
)


class MemoryReferenceResolver:
    def __init__(
        self,
        memory_service,
        entity_normalization_service: Optional[EntityNormalizationService] = None,
    ) -> None:
        self.memory_service = memory_service
        self.entity_normalization_service = (
            entity_normalization_service or EntityNormalizationService()
        )

    def remember_entity_keys(
        self,
        entity: dict[str, Any],
        entity_ids_by_key: dict[str, str],
    ) -> None:
        entity_id = clean_text(entity.get("id"))
        if not entity_id:
            return
        values = [
            entity.get("display_name"),
            entity.get("normalized_name"),
            *entity.get("aliases", []),
        ]
        for value in values:
            key = normalized_text(value)
            if key:
                entity_ids_by_key[key] = entity_id

    def remember_plan_keys(
        self,
        plan: dict[str, Any],
        plan_ids_by_key: dict[str, str],
    ) -> None:
        plan_id = clean_text(plan.get("id"))
        if not plan_id:
            return
        for value in (plan.get("title"), plan.get("description")):
            key = normalized_text(value)
            if key:
                plan_ids_by_key[key] = plan_id

    async def load_existing_entity_keys(
        self,
        entity_ids_by_key: dict[str, str],
    ) -> None:
        method = getattr(self.memory_service, "list_entities", None)
        if method is None:
            return
        try:
            entities = await method(active=True, limit=100)
        except Exception:
            return
        for entity in entities:
            self.remember_entity_keys(entity, entity_ids_by_key)

    async def load_existing_plan_keys(
        self,
        plan_ids_by_key: dict[str, str],
    ) -> None:
        method = getattr(self.memory_service, "list_plans", None)
        if method is None:
            return
        try:
            plans = await method(active=True, limit=100)
        except Exception:
            return
        for plan in plans:
            self.remember_plan_keys(plan, plan_ids_by_key)

    async def resolve_entity_reference(
        self,
        candidate: dict[str, Any],
        entity_ids_by_key: dict[str, str],
    ) -> None:
        if clean_text(candidate.get("entity_id")):
            return
        entity_name = clean_text(candidate.get("entity_name"))
        if not entity_name:
            return

        entity_id = entity_ids_by_key.get(normalized_text(entity_name))
        if entity_id:
            candidate["entity_id"] = entity_id
            return

        existing = await self.find_existing_entity(entity_name)
        if existing:
            self.remember_entity_keys(existing, entity_ids_by_key)
            candidate["entity_id"] = existing.get("id")

    async def resolve_plan_reference(
        self,
        candidate: dict[str, Any],
        plan_ids_by_key: dict[str, str],
    ) -> None:
        if clean_text(candidate.get("plan_id")):
            return
        plan_title = clean_text(candidate.get("plan_title"))
        if not plan_title:
            return

        plan_id = plan_ids_by_key.get(normalized_text(plan_title))
        if plan_id:
            candidate["plan_id"] = plan_id
            return

        existing = await self.find_existing_plan(plan_title)
        if existing:
            self.remember_plan_keys(existing, plan_ids_by_key)
            candidate["plan_id"] = existing.get("id")

    async def find_existing_entity(
        self,
        entity_name: str,
    ) -> Optional[dict[str, Any]]:
        method = getattr(self.memory_service, "list_entities", None)
        if method is None:
            return None
        try:
            entities = await method(active=True, limit=100)
        except Exception:
            return None

        target = normalized_text(entity_name)
        obsolete_match = self.entity_normalization_service.detect_obsolete_alias(
            entity_name,
            entities,
        )
        if obsolete_match is not None:
            return obsolete_match
        for entity in entities:
            keys = [
                entity.get("normalized_name"),
                entity.get("display_name"),
                *entity.get("aliases", []),
            ]
            if target in {normalized_text(key) for key in keys if key}:
                return entity
        return None

    async def find_existing_plan(self, plan_title: str) -> Optional[dict[str, Any]]:
        method = getattr(self.memory_service, "list_plans", None)
        if method is None:
            return None
        try:
            plans = await method(active=True, limit=100)
        except Exception:
            return None

        target = normalized_text(plan_title)
        for plan in plans:
            if target == normalized_text(plan.get("title")):
                return plan
        return None
