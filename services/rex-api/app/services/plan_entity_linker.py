from __future__ import annotations

from typing import Any

from app.services.entity_normalization_service import EntityNormalizationService
from app.services.plan_repository import PlanRepository


class PlanEntityLinker:
    def __init__(
        self,
        repository: PlanRepository,
        normalization_service: EntityNormalizationService | None = None,
    ) -> None:
        self.repository = repository
        self.normalization_service = normalization_service or EntityNormalizationService()

    async def normalize_entity_references(
        self,
        payload: dict[str, Any],
        *,
        text_fields: tuple[str, ...],
        link_field: str | None = None,
    ) -> dict[str, Any]:
        try:
            entities = await self.repository.list_entities(active=True, limit=100)
        except Exception:
            return payload
        if not entities:
            return payload
        result = self.normalization_service.normalize_payload_references(
            payload,
            entities,
            text_fields=text_fields,
            link_field=link_field,
        )
        return result.payload
