from __future__ import annotations

from typing import Optional

from app.services.long_term_memory_repository import LongTermMemoryRepository
from app.services.memory_correction_repository import MemoryCorrectionRepository
from app.services.memory_retrieval_service import MemoryRetrievalService


class MemoryLongTermGateway:
    def _get_long_term_memory_repository(self) -> LongTermMemoryRepository:
        repository = getattr(self, "long_term_memory_repository", None)
        if repository is None:
            repository = LongTermMemoryRepository(self)
            self.long_term_memory_repository = repository
        return repository

    def _get_memory_retrieval_service(self) -> MemoryRetrievalService:
        service = getattr(self, "memory_retrieval_service", None)
        if service is None:
            service = MemoryRetrievalService(self)
            self.memory_retrieval_service = service
        return service

    def _get_memory_correction_repository(self) -> MemoryCorrectionRepository:
        repository = getattr(self, "memory_correction_repository", None)
        if repository is None:
            repository = MemoryCorrectionRepository(self)
            self.memory_correction_repository = repository
        return repository

    async def save_long_term_memory(
        self,
        memory_type: str,
        content: str,
        source_conversation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
        importance: int = 3,
        confidence: float = 0.75,
        correction_group: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> dict:
        return await self._get_long_term_memory_repository().save_long_term_memory(
            memory_type=memory_type,
            content=content,
            source_conversation_id=source_conversation_id,
            source_message_id=source_message_id,
            importance=importance,
            confidence=confidence,
            correction_group=correction_group,
            metadata=metadata,
        )

    async def save_long_term_memory_from_message(
        self,
        conversation_id: str,
        message: dict,
    ) -> Optional[dict]:
        repository = self._get_long_term_memory_repository()
        return await repository.save_long_term_memory_from_message(
            conversation_id,
            message,
        )

    async def get_long_term_memory(
        self,
        query: Optional[str] = None,
        limit: int = 8,
    ) -> list[dict]:
        return await self._get_memory_retrieval_service().get_long_term_memory(
            query=query,
            limit=limit,
        )

    async def get_relevant_memories(self, query: str, limit: int = 8) -> list[dict]:
        return await self._get_memory_retrieval_service().get_relevant_memories(
            query=query,
            limit=limit,
        )

    async def get_structured_memory_context(self, query: str) -> dict:
        return await self._get_memory_retrieval_service().get_structured_memory_context(
            query,
        )

    async def list_long_term_memory(
        self,
        limit: int = 50,
        memory_type: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_long_term_memory_repository().list_long_term_memory(
            limit=limit,
            memory_type=memory_type,
            active=active,
        )

    async def list_long_term_memory_paged(
        self,
        limit: int = 50,
        memory_type: Optional[str] = None,
        active: Optional[bool] = None,
        cursor: Optional[str] = None,
    ) -> tuple[list[dict], Optional[str], bool]:
        return await self._get_long_term_memory_repository().list_long_term_memory_paged(
            limit=limit,
            memory_type=memory_type,
            active=active,
            cursor=cursor,
        )

    async def update_long_term_memory(
        self,
        memory_id: str,
        memory_type: Optional[str] = None,
        content: Optional[str] = None,
        importance: Optional[int] = None,
        active: Optional[bool] = None,
        superseded_by: Optional[str] = None,
        confidence: Optional[float] = None,
        correction_group: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self._get_long_term_memory_repository().update_long_term_memory(
            memory_id=memory_id,
            memory_type=memory_type,
            content=content,
            importance=importance,
            active=active,
            superseded_by=superseded_by,
            confidence=confidence,
            correction_group=correction_group,
            metadata=metadata,
        )

    async def deactivate_long_term_memory(self, memory_id: str) -> Optional[dict]:
        return (
            await self._get_long_term_memory_repository().deactivate_long_term_memory(
                memory_id,
            )
        )

    async def create_memory_correction(self, correction: dict) -> dict:
        return await self._get_memory_correction_repository().create_memory_correction(
            correction,
        )

    async def list_memory_corrections(
        self,
        limit: int = 50,
        correction_type: Optional[str] = None,
        applied: Optional[bool] = None,
        target_table: Optional[str] = None,
        target_id: Optional[str] = None,
    ) -> list[dict]:
        return await self._get_memory_correction_repository().list_memory_corrections(
            limit=limit,
            correction_type=correction_type,
            applied=applied,
            target_table=target_table,
            target_id=target_id,
        )
