from __future__ import annotations

from typing import Any

from app.models.entity import (
    EntityCreateRequest,
    EntityEventCreateRequest,
    EntityEventUpdateRequest,
    EntityUpdateRequest,
)
from app.models.memory_discipline import MemoryRecordKind
from app.services.entity_errors import EntityServiceError
from app.services.entity_merge_service import (
    EntityMergeService,
    canonical_display_name,
    clean_optional,
    clean_required,
    correction_wrong_names,
    dedupe_strings,
    entity_aliases,
    normalize_entity_name,
    normalize_key,
)
from app.services.entity_repository import EntityRepository
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_discipline_writes import (
    MemoryWriteError,
    execute_disciplined_create,
)
from app.services.memory_service import MemoryServiceError, SupabaseMemoryService
from app.services.person_memory_materializer import PersonMemoryMaterializer


class EntityService:
    def __init__(
        self,
        memory_service: SupabaseMemoryService,
        *,
        discipline: MemoryDisciplineService | None = None,
    ) -> None:
        self.repository = EntityRepository(memory_service)
        self.merge_service = EntityMergeService(self.repository)
        self.person_memory_materializer = PersonMemoryMaterializer()
        self.discipline = discipline or MemoryDisciplineService(memory_service)

    async def create_entity(self, request: EntityCreateRequest) -> dict[str, Any]:
        payload = _payload(request)
        original_display_name = clean_required(
            payload.get("display_name"), "display_name"
        )
        original_normalized_name = clean_optional(payload.get("normalized_name"))
        original_aliases = dedupe_strings(payload.get("aliases", []))
        display_name = canonical_display_name(
            payload.get("entity_type"),
            original_display_name,
            original_normalized_name,
            original_aliases,
        )
        payload["display_name"] = display_name
        normalized_source = (
            display_name
            if payload.get("entity_type") == "person"
            else original_normalized_name or display_name
        )
        payload["normalized_name"] = normalize_entity_name(normalized_source)
        payload["aliases"] = entity_aliases(
            payload,
            original_display_name=original_display_name,
            original_normalized_name=original_normalized_name,
            original_aliases=original_aliases,
            display_name=display_name,
        )
        wrong_names = correction_wrong_names(payload)

        try:
            if wrong_names:
                return await self.merge_service.create_or_merge_entity(
                    payload,
                    wrong_names=wrong_names,
                )
            return await execute_disciplined_create(
                self.discipline,
                kind=MemoryRecordKind.ENTITY,
                payload=payload,
                create_fn=lambda item: self.merge_service.create_or_merge_entity(
                    item,
                    wrong_names=wrong_names,
                ),
            )
        except MemoryWriteError as error:
            raise EntityServiceError(error.detail, error.status_code) from error
        except MemoryServiceError as error:
            raise EntityServiceError(error.detail, error.status_code) from error

    async def list_entities(
        self,
        *,
        entity_type: str | None = None,
        normalized_name: str | None = None,
        active: bool | None = True,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        try:
            return await self.repository.list_entities(
                entity_type=entity_type,
                normalized_name=normalize_key(normalized_name)
                if normalized_name
                else None,
                active=active,
                limit=limit,
            )
        except MemoryServiceError as error:
            raise EntityServiceError(error.detail, error.status_code) from error

    async def update_entity(
        self, entity_id: str, request: EntityUpdateRequest
    ) -> dict[str, Any]:
        payload = _payload(request)
        if "display_name" in payload:
            payload["display_name"] = clean_required(
                payload["display_name"], "display_name"
            )
        if "normalized_name" in payload:
            payload["normalized_name"] = normalize_entity_name(
                payload["normalized_name"]
            )
        elif "display_name" in payload:
            payload["normalized_name"] = normalize_entity_name(payload["display_name"])
        if "aliases" in payload:
            payload["aliases"] = dedupe_strings(payload["aliases"])

        try:
            updated = await self.repository.update_entity(entity_id, **payload)
        except MemoryServiceError as error:
            raise EntityServiceError(error.detail, error.status_code) from error
        if updated is None:
            raise EntityServiceError("Entity not found.", 404)
        return updated

    async def deactivate_entity(self, entity_id: str) -> dict[str, Any]:
        try:
            updated = await self.repository.deactivate_entity(entity_id)
        except MemoryServiceError as error:
            raise EntityServiceError(error.detail, error.status_code) from error
        if updated is None:
            raise EntityServiceError("Entity not found.", 404)
        if updated.get("entity_type") == "person":
            await self.person_memory_materializer.archive_source_memories_for_entity(
                self.repository.memory_service,
                updated,
            )
        return updated

    async def create_entity_event(
        self, request: EntityEventCreateRequest
    ) -> dict[str, Any]:
        payload = _payload(request)
        payload["content"] = clean_required(payload.get("content"), "content")
        if payload.get("title") is not None:
            payload["title"] = clean_optional(payload["title"])

        try:
            return await self.repository.create_entity_event(payload)
        except MemoryServiceError as error:
            raise EntityServiceError(error.detail, error.status_code) from error

    async def list_entity_events(
        self,
        *,
        entity_id: str | None = None,
        event_type: str | None = None,
        active: bool | None = True,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        try:
            return await self.repository.list_entity_events(
                entity_id=entity_id,
                event_type=event_type,
                active=active,
                limit=limit,
            )
        except MemoryServiceError as error:
            raise EntityServiceError(error.detail, error.status_code) from error

    async def update_entity_event(
        self, event_id: str, request: EntityEventUpdateRequest
    ) -> dict[str, Any]:
        payload = _payload(request)
        if "content" in payload:
            payload["content"] = clean_required(payload["content"], "content")
        if "title" in payload:
            payload["title"] = clean_optional(payload["title"])

        try:
            updated = await self.repository.update_entity_event(event_id, **payload)
        except MemoryServiceError as error:
            raise EntityServiceError(error.detail, error.status_code) from error
        if updated is None:
            raise EntityServiceError("Entity event not found.", 404)
        return updated

    async def deactivate_entity_event(self, event_id: str) -> dict[str, Any]:
        try:
            updated = await self.repository.deactivate_entity_event(event_id)
        except MemoryServiceError as error:
            raise EntityServiceError(error.detail, error.status_code) from error
        if updated is None:
            raise EntityServiceError("Entity event not found.", 404)
        return updated


def _payload(request: Any) -> dict[str, Any]:
    if hasattr(request, "model_dump"):
        return request.model_dump(exclude_none=True)
    return {key: value for key, value in dict(request).items() if value is not None}


def is_active_entity_event(event: dict[str, Any]) -> bool:
    return event.get("active") is not False


def entity_event_accountability_text(event: dict[str, Any]) -> str:
    return " ".join(
        str(event.get(field) or "")
        for field in ("title", "content", "event_type")
    )


_correction_wrong_names = correction_wrong_names
