from __future__ import annotations

from typing import Any

from app.services.memory_service import SupabaseMemoryService


class EntityRepository:
    def __init__(self, memory_service: SupabaseMemoryService) -> None:
        self.memory_service = memory_service

    async def create_entity(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self.memory_service.create_entity(payload)

    async def list_entities(
        self,
        *,
        entity_type: str | None = None,
        normalized_name: str | None = None,
        active: bool | None = True,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        return await self.memory_service.list_entities(
            entity_type=entity_type,
            normalized_name=normalized_name,
            active=active,
            limit=limit,
        )

    async def update_entity(
        self,
        entity_id: str,
        **updates: object,
    ) -> dict[str, Any] | None:
        return await self.memory_service.update_entity(entity_id, **updates)

    async def deactivate_entity(self, entity_id: str) -> dict[str, Any] | None:
        return await self.memory_service.deactivate_entity(entity_id)

    async def create_entity_event(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self.memory_service.create_entity_event(payload)

    async def list_entity_events(
        self,
        *,
        entity_id: str | None = None,
        event_type: str | None = None,
        active: bool | None = True,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        return await self.memory_service.list_entity_events(
            entity_id=entity_id,
            event_type=event_type,
            active=active,
            limit=limit,
        )

    async def update_entity_event(
        self,
        event_id: str,
        **updates: object,
    ) -> dict[str, Any] | None:
        return await self.memory_service.update_entity_event(event_id, **updates)

    async def deactivate_entity_event(self, event_id: str) -> dict[str, Any] | None:
        return await self.memory_service.deactivate_entity_event(event_id)
