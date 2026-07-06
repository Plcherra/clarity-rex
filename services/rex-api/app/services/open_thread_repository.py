from typing import Optional

OPEN_THREADS_TABLE = "open_threads"

OPEN_THREAD_SELECT = (
    "id,title,summary,status,source,source_conversation_id,source_message_id,"
    "last_mentioned_at,last_follow_up_at,metadata,created_at,updated_at"
)


class OpenThreadRepository:
    def __init__(self, store: object) -> None:
        self.store = store

    async def create_thread(self, thread: dict) -> dict:
        return await self.store._create_record(
            OPEN_THREADS_TABLE,
            thread,
            OPEN_THREAD_SELECT,
        )

    async def list_threads(
        self,
        *,
        status: Optional[str] = None,
        limit: int = 50,
    ) -> list[dict]:
        filters: dict[str, object] = {}
        if status is not None:
            filters["status"] = status
        return await self.store._list_records(
            OPEN_THREADS_TABLE,
            select=OPEN_THREAD_SELECT,
            filters=filters,
            order="updated_at.desc,created_at.desc",
            limit=limit,
        )

    async def update_thread(
        self,
        thread_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self.store._update_record(
            OPEN_THREADS_TABLE,
            thread_id,
            updates=updates,
            select=OPEN_THREAD_SELECT,
            empty_detail="At least one open thread field must be provided.",
        )

    async def get_thread(self, thread_id: str) -> Optional[dict]:
        rows = await self.store._list_records(
            OPEN_THREADS_TABLE,
            select=OPEN_THREAD_SELECT,
            filters={"id": thread_id},
            limit=1,
        )
        return rows[0] if rows else None

    async def delete_thread(self, thread_id: str) -> bool:
        try:
            return await self.store._delete_record(OPEN_THREADS_TABLE, thread_id)
        except Exception:
            return False
