from __future__ import annotations

from typing import Any

from app.services.entity_merge_strategies import (
    _correction_wrong_names,
    _dedupe_strings,
    _entity_matches_payload,
    _is_superseded_entity,
    _safe_normalize_entity_name,
    canonical_display_name,
    clean_optional,
    clean_required,
    correction_wrong_names,
    dedupe_strings,
    entity_aliases,
    merge_metadata,
    normalize_entity_name,
    normalize_key,
    strip_entity_descriptors,
)
from app.services.entity_normalization_service import EntityNormalizationService
from app.services.entity_repository import EntityRepository
from app.services.memory_service import MemoryServiceError


class EntityMergeService:
    def __init__(
        self,
        repository: EntityRepository,
        normalization_service: EntityNormalizationService | None = None,
    ) -> None:
        self.repository = repository
        self.normalization_service = normalization_service or EntityNormalizationService()

    async def create_or_merge_entity(
        self,
        payload: dict[str, Any],
        *,
        wrong_names: set[str],
    ) -> dict[str, Any]:
        existing = await self.repository.list_entities(
            entity_type=payload["entity_type"],
            active=True,
            limit=100,
        )
        normalized = self.normalization_service.normalize_candidate_entity(
            payload,
            existing,
        )
        payload = normalized.payload
        wrong_names.update(normalized.obsolete_names)
        duplicate = next(
            (
                entity
                for entity in existing
                if _entity_matches_payload(
                    entity,
                    payload,
                    ignore_alias_matches=bool(wrong_names),
                )
            ),
            None,
        )
        if duplicate is None and normalized.canonical_entity is not None:
            duplicate = normalized.canonical_entity
        if duplicate:
            wrong_names.update(_correction_wrong_names(duplicate))
            entity = await self._merge_existing_entity(duplicate, payload)
        else:
            entity = await self.repository.create_entity(payload)
        wrong_names.update(_correction_wrong_names(entity))
        if wrong_names:
            entity = await self._remove_wrong_aliases(entity, wrong_names)
            await self._archive_superseded_entities(entity, wrong_names)
        return entity

    async def _merge_existing_entity(
        self, existing: dict[str, Any], payload: dict[str, Any]
    ) -> dict[str, Any]:
        updates: dict[str, Any] = {}
        aliases = _dedupe_strings(
            [*existing.get("aliases", []), *payload.get("aliases", [])]
        )
        if aliases != existing.get("aliases", []):
            updates["aliases"] = aliases

        for field in (
            "relationship",
            "summary",
            "source_conversation_id",
            "source_message_id",
            "source_memory_id",
        ):
            if payload.get(field) and not existing.get(field):
                updates[field] = payload[field]

        if payload.get("importance", 3) > existing.get("importance", 3):
            updates["importance"] = payload["importance"]

        metadata = merge_metadata(existing.get("metadata"), payload.get("metadata"))
        if metadata != (existing.get("metadata") or {}):
            updates["metadata"] = metadata

        if not updates:
            return existing

        updated = await self.repository.update_entity(existing["id"], **updates)
        return updated or existing

    async def _archive_superseded_entities(
        self,
        corrected_entity: dict[str, Any],
        wrong_names: set[str],
    ) -> None:
        corrected_id = corrected_entity.get("id")
        if not corrected_id:
            return

        try:
            entities = await self.repository.list_entities(
                entity_type=corrected_entity.get("entity_type"),
                active=True,
                limit=100,
            )
        except MemoryServiceError:
            return

        for entity in entities:
            if entity.get("id") == corrected_id:
                continue
            if not _is_superseded_entity(entity, wrong_names):
                continue

            metadata = {
                **(entity.get("metadata") or {}),
                "superseded_by_entity_id": corrected_id,
                "superseded_by_display_name": corrected_entity.get("display_name"),
                "cleanup_reason": "explicit_person_correction",
            }
            try:
                await self.repository.update_entity(
                    entity["id"],
                    active=False,
                    status="inactive",
                    metadata=metadata,
                )
            except MemoryServiceError:
                continue

    async def _remove_wrong_aliases(
        self,
        entity: dict[str, Any],
        wrong_names: set[str],
    ) -> dict[str, Any]:
        aliases = entity.get("aliases", [])
        cleaned_aliases = [
            alias
            for alias in aliases
            if _safe_normalize_entity_name(alias) not in wrong_names
        ]
        if cleaned_aliases == aliases:
            return entity

        metadata = {
            **(entity.get("metadata") or {}),
            "removed_wrong_aliases": [
                alias
                for alias in aliases
                if _safe_normalize_entity_name(alias) in wrong_names
            ],
            "cleanup_reason": "explicit_person_correction",
        }
        try:
            updated = await self.repository.update_entity(
                entity["id"],
                aliases=cleaned_aliases,
                metadata=metadata,
            )
        except MemoryServiceError:
            return entity
        return updated or {**entity, "aliases": cleaned_aliases, "metadata": metadata}
