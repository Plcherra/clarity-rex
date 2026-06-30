from __future__ import annotations

from typing import Any, Optional

from app.models.memory import MemoryCreateRequest
from app.services.long_term_memory_repository import LongTermMemoryRepository
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_discipline_writes import (
    MemoryWriteError,
    execute_disciplined_create,
)
from app.services.memory_service import MemoryServiceError, SupabaseMemoryService
from app.models.memory_discipline import MemoryRecordKind
from app.services.person_memory_materializer import PersonMemoryMaterializer


class MemoryWriteService:
    def __init__(
        self,
        memory_service: SupabaseMemoryService,
        discipline: MemoryDisciplineService,
        *,
        materializer: Optional[PersonMemoryMaterializer] = None,
    ) -> None:
        self.memory_service = memory_service
        self.discipline = discipline
        self.materializer = materializer or PersonMemoryMaterializer()
        self._long_term_repository = LongTermMemoryRepository(memory_service)

    async def create_memory(self, request: MemoryCreateRequest) -> dict[str, Any]:
        metadata = dict(request.metadata or {})
        if request.memory_category:
            metadata["memory_category"] = request.memory_category

        payload = {
            "memory_type": request.memory_type,
            "content": request.content.strip(),
            "importance": request.importance,
            "metadata": metadata,
        }

        try:
            record = await execute_disciplined_create(
                self.discipline,
                kind=MemoryRecordKind.LONG_TERM_MEMORY,
                payload=payload,
                create_fn=self._save_long_term_memory,
            )
        except MemoryWriteError:
            raise
        except MemoryServiceError as error:
            raise MemoryWriteError(error.detail, error.status_code) from error

        return record

    async def _save_long_term_memory(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._long_term_repository.save_long_term_memory(
            memory_type=str(payload["memory_type"]),
            content=str(payload["content"]),
            importance=int(payload.get("importance") or 3),
            metadata=dict(payload.get("metadata") or {}),
        )

    async def _materialize_if_person_fact(self, record: dict[str, Any]) -> None:
        metadata = record.get("metadata")
        if not isinstance(metadata, dict):
            return
        category = str(metadata.get("memory_category") or "").casefold()
        if category not in {"people", "events"} and metadata.get("fact_kind") != "birthday":
            return
        try:
            await self.materializer.materialize_from_memory(
                self.memory_service,
                record,
            )
        except Exception:
            return
