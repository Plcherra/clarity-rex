from typing import Any, Optional

from app.services.entity_normalization_service import EntityNormalizationService
from app.services.memory_reference_models import KnowsReferenceMatch
from app.services.memory_reference_scoring import (
    dedupe_knows_matches,
    display_attribute_label,
    reference_matches_visible_item,
)
from app.services.memory_text_normalization import (
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

    async def resolve_knows_delete_reference(
        self,
        reference: str,
        *,
        limit: int = 250,
    ) -> list[KnowsReferenceMatch]:
        """Resolve user wording against records and fields visible in Knows."""

        reference_key = normalized_text(reference)
        if not reference_key:
            return []

        visible_items = await self._visible_knows_items(limit=limit)
        matches = [
            item
            for item in visible_items
            if reference_matches_visible_item(reference_key, item)
        ]
        return dedupe_knows_matches(matches)

    async def _visible_knows_items(self, *, limit: int) -> list[KnowsReferenceMatch]:
        items: list[KnowsReferenceMatch] = []
        items.extend(await self._long_term_memory_items(limit=limit))
        items.extend(await self._entity_event_items(limit=limit))
        items.extend(await self._entity_items(limit=limit))
        items.extend(await self._plan_items(limit=limit))
        items.extend(await self._commitment_items(limit=limit))
        return items

    async def _plan_items(self, *, limit: int) -> list[KnowsReferenceMatch]:
        method = getattr(self.memory_service, "list_plans", None)
        if method is None:
            return []
        try:
            records = await method(active=True, limit=limit)
        except TypeError:
            try:
                records = await method(limit=limit)
            except Exception:
                return []
        except Exception:
            return []

        items: list[KnowsReferenceMatch] = []
        for record in records:
            record_id = clean_text(record.get("id"))
            title = clean_text(record.get("title") or record.get("description"))
            if not record_id or not title:
                continue
            items.append(
                KnowsReferenceMatch(
                    table="plans",
                    id=record_id,
                    title=title,
                    record=record,
                )
            )
        return items

    async def _commitment_items(self, *, limit: int) -> list[KnowsReferenceMatch]:
        method = getattr(self.memory_service, "list_commitments", None)
        if method is None:
            return []
        try:
            records = await method(active=True, limit=limit)
        except TypeError:
            try:
                records = await method(limit=limit)
            except Exception:
                return []
        except Exception:
            return []

        items: list[KnowsReferenceMatch] = []
        for record in records:
            record_id = clean_text(record.get("id"))
            title = clean_text(record.get("title") or record.get("commitment_text"))
            if not record_id or not title:
                continue
            items.append(
                KnowsReferenceMatch(
                    table="commitments",
                    id=record_id,
                    title=title,
                    record=record,
                )
            )
        return items

    async def _long_term_memory_items(
        self,
        *,
        limit: int,
    ) -> list[KnowsReferenceMatch]:
        method = getattr(self.memory_service, "list_long_term_memory", None)
        if method is None:
            return []
        try:
            records = await method(active=True, limit=limit)
        except TypeError:
            try:
                records = await method(limit=limit)
            except Exception:
                return []
        except Exception:
            return []

        items: list[KnowsReferenceMatch] = []
        for record in records:
            record_id = clean_text(record.get("id"))
            title = clean_text(record.get("content"))
            if not record_id or not title:
                continue
            items.append(
                KnowsReferenceMatch(
                    table="long_term_memory",
                    id=record_id,
                    title=title,
                    record=record,
                )
            )
        return items

    async def _entity_event_items(
        self,
        *,
        limit: int,
    ) -> list[KnowsReferenceMatch]:
        method = getattr(self.memory_service, "list_entity_events", None)
        if method is None:
            return []
        try:
            records = await method(active=True, limit=limit)
        except TypeError:
            try:
                records = await method(limit=limit)
            except Exception:
                return []
        except Exception:
            return []

        items: list[KnowsReferenceMatch] = []
        for record in records:
            record_id = clean_text(record.get("id"))
            title = clean_text(record.get("title") or record.get("content"))
            if not record_id or not title:
                continue
            items.append(
                KnowsReferenceMatch(
                    table="entity_events",
                    id=record_id,
                    title=title,
                    record=record,
                )
            )
        return items

    async def _entity_items(self, *, limit: int) -> list[KnowsReferenceMatch]:
        method = getattr(self.memory_service, "list_entities", None)
        if method is None:
            return []
        try:
            records = await method(active=True, limit=limit)
        except TypeError:
            try:
                records = await method(limit=limit)
            except Exception:
                return []
        except Exception:
            return []

        items: list[KnowsReferenceMatch] = []
        for record in records:
            record_id = clean_text(record.get("id"))
            title = clean_text(record.get("display_name"))
            if not record_id or not title:
                continue
            items.append(
                KnowsReferenceMatch(
                    table="entities",
                    id=record_id,
                    title=title,
                    record=record,
                )
            )
            items.extend(self._entity_attribute_items(record, record_id))
        return items

    def _entity_attribute_items(
        self,
        record: dict[str, Any],
        record_id: str,
    ) -> list[KnowsReferenceMatch]:
        metadata = record.get("metadata")
        if not isinstance(metadata, dict):
            return []
        attributes = metadata.get("attributes")
        if not isinstance(attributes, dict):
            return []

        source_map = metadata.get("attribute_source_memory_ids")
        if not isinstance(source_map, dict):
            source_map = {}

        items: list[KnowsReferenceMatch] = []
        for key, value in attributes.items():
            attribute_key = clean_text(key)
            attribute_value = clean_text(value)
            if not attribute_key or not attribute_value:
                continue
            source_memory_ids = tuple(
                item
                for item in (clean_text(source) for source in source_map.get(key) or [])
                if item
            )
            items.append(
                KnowsReferenceMatch(
                    table="entities",
                    id=record_id,
                    title=f"{display_attribute_label(attribute_key)}: {attribute_value}",
                    record=record,
                    action="would_remove_attribute",
                    attribute_key=attribute_key,
                    attribute_value=attribute_value,
                    source_memory_ids=source_memory_ids,
                )
            )
        return items
