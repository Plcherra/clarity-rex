from app.services.open_thread_repository import OpenThreadRepository


class MemoryOpenThreadGateway:
    @property
    def open_thread_repository(self) -> OpenThreadRepository:
        return OpenThreadRepository(self)

    async def list_open_threads(
        self,
        *,
        status: str | None = None,
        limit: int = 50,
    ) -> list[dict]:
        return await self.open_thread_repository.list_threads(
            status=status,
            limit=limit,
        )

    async def create_open_thread(self, payload: dict) -> dict:
        payload = dict(payload)
        payload.setdefault("user_id", self.user_id)
        return await self.open_thread_repository.create_thread(payload)

    async def update_open_thread(self, thread_id: str, **updates: object) -> dict | None:
        return await self.open_thread_repository.update_thread(thread_id, **updates)

    async def delete_open_thread(self, thread_id: str) -> bool:
        return await self.open_thread_repository.delete_thread(thread_id)
