from typing import Optional

from app.services.memory_confirmation_repository import MemoryConfirmationRepository


class MemoryConfirmationFacade:
    def _get_memory_confirmation_repository(self) -> MemoryConfirmationRepository:
        repository = getattr(self, "memory_confirmation_repository", None)
        if repository is None:
            repository = MemoryConfirmationRepository(self)
            self.memory_confirmation_repository = repository
        return repository

    async def create_memory_confirmation(self, confirmation: dict) -> dict:
        return await self._get_memory_confirmation_repository().create_memory_confirmation(
            confirmation,
        )

    async def get_latest_pending_memory_confirmation(
        self,
        conversation_id: str,
    ) -> Optional[dict]:
        return await self._get_memory_confirmation_repository().get_latest_pending_memory_confirmation(
            conversation_id,
        )

    async def update_memory_confirmation(
        self,
        confirmation_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self._get_memory_confirmation_repository().update_memory_confirmation(
            confirmation_id,
            **updates,
        )

    async def confirm_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        applied_memory_id: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self._get_memory_confirmation_repository().confirm_memory_confirmation(
            confirmation_id,
            applied_memory_id=applied_memory_id,
            metadata=metadata,
        )

    async def reject_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self._get_memory_confirmation_repository().reject_memory_confirmation(
            confirmation_id,
            metadata=metadata,
        )

    async def expire_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self._get_memory_confirmation_repository().expire_memory_confirmation(
            confirmation_id,
            metadata=metadata,
        )

    async def fail_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self._get_memory_confirmation_repository().fail_memory_confirmation(
            confirmation_id,
            metadata=metadata,
        )
