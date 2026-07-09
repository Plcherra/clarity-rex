"""Shared post-write hook: materialize person cards and remove covered flats."""

from __future__ import annotations

from typing import Any, Optional

from app.services.person_memory_materializer import PersonMemoryMaterializer


class MemoryPersistOrchestrator:
    """Run after a confirmed long-term memory create/update.

    Chat/voice durable apply, manual Knows create, and legacy direct saves
    should all call this so People facts become person cards and covered flat
    duplicates are hard-deleted (not soft-hidden).
    """

    def __init__(
        self,
        *,
        materializer: Optional[PersonMemoryMaterializer] = None,
    ) -> None:
        self._materializer = materializer or PersonMemoryMaterializer()

    async def after_long_term_memory_write(
        self,
        memory_service: Any,
        record: dict[str, Any],
    ) -> dict[str, Any]:
        if not isinstance(record, dict) or not record.get("id"):
            return record
        try:
            await self._materializer.materialize_from_memory(memory_service, record)
        except Exception:
            # Materialization is best-effort; the flat write already succeeded.
            return record
        return record
