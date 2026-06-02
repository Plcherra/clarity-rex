from datetime import datetime, timezone
from typing import Optional

from app.services.memory_errors import MemoryServiceError

VALID_MEMORY_CONFIRMATION_STATUSES = {
    "pending",
    "confirmed",
    "rejected",
    "expired",
    "failed",
}
VALID_MEMORY_CONFIRMATION_MEMORY_TYPES = {"fact", "preference", "event"}

MEMORY_CONFIRMATION_SELECT = (
    "id,user_id,conversation_id,source_message_id,confirmation_message_id,status,"
    "memory_type,content,importance,source,expires_at,confirmed_at,rejected_at,"
    "failed_at,applied_memory_id,metadata,created_at,updated_at"
)


class MemoryConfirmationRepository:
    def __init__(self, store: object) -> None:
        self.store = store

    async def create_memory_confirmation(self, confirmation: dict) -> dict:
        memory_type = str(confirmation.get("memory_type") or "").strip()
        self.validate_memory_type(memory_type)

        content = str(confirmation.get("content") or "").strip()
        if not content:
            raise MemoryServiceError("Memory confirmation content is required.", 400)

        importance = int(confirmation.get("importance") or 3)
        if importance < 1 or importance > 5:
            raise MemoryServiceError("Memory importance must be between 1 and 5.", 400)

        status = str(confirmation.get("status") or "pending")
        self.validate_status(status)

        return await self.store._create_record(
            self.store.settings.supabase_memory_confirmations_table,
            {
                "conversation_id": confirmation.get("conversation_id"),
                "source_message_id": confirmation.get("source_message_id"),
                "confirmation_message_id": confirmation.get(
                    "confirmation_message_id"
                ),
                "status": status,
                "memory_type": memory_type,
                "content": content,
                "importance": importance,
                "source": confirmation.get("source") or "simple_memory_intent",
                "expires_at": confirmation.get("expires_at"),
                "confirmed_at": confirmation.get("confirmed_at"),
                "rejected_at": confirmation.get("rejected_at"),
                "failed_at": confirmation.get("failed_at"),
                "applied_memory_id": confirmation.get("applied_memory_id"),
                "metadata": confirmation.get("metadata") or {},
            },
            MEMORY_CONFIRMATION_SELECT,
        )

    async def get_latest_pending_memory_confirmation(
        self,
        conversation_id: str,
    ) -> Optional[dict]:
        rows = await self.store._request(
            "GET",
            self.store.settings.supabase_memory_confirmations_table,
            query={
                "conversation_id": f"eq.{conversation_id}",
                "status": "eq.pending",
                "expires_at": f"gt.{self._now_iso()}",
                "select": MEMORY_CONFIRMATION_SELECT,
                "order": "created_at.desc",
                "limit": "1",
            },
        )
        return rows[0] if rows else None

    async def update_memory_confirmation(
        self,
        confirmation_id: str,
        **updates: object,
    ) -> Optional[dict]:
        if "status" in updates:
            self.validate_status(updates.get("status"))
        if "memory_type" in updates:
            self.validate_memory_type(updates.get("memory_type"))
        if "importance" in updates and updates.get("importance") is not None:
            importance = int(updates["importance"])
            if importance < 1 or importance > 5:
                raise MemoryServiceError(
                    "Memory importance must be between 1 and 5.",
                    400,
                )

        return await self.store._update_record(
            self.store.settings.supabase_memory_confirmations_table,
            confirmation_id,
            updates=updates,
            select=MEMORY_CONFIRMATION_SELECT,
            empty_detail="At least one memory confirmation field must be provided.",
        )

    async def confirm_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        applied_memory_id: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self.update_memory_confirmation(
            confirmation_id,
            status="confirmed",
            confirmed_at=self._now_iso(),
            applied_memory_id=applied_memory_id,
            metadata=metadata,
        )

    async def reject_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self.update_memory_confirmation(
            confirmation_id,
            status="rejected",
            rejected_at=self._now_iso(),
            metadata=metadata,
        )

    async def expire_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self.update_memory_confirmation(
            confirmation_id,
            status="expired",
            metadata=metadata,
        )

    async def fail_memory_confirmation(
        self,
        confirmation_id: str,
        *,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self.update_memory_confirmation(
            confirmation_id,
            status="failed",
            failed_at=self._now_iso(),
            metadata=metadata,
        )

    def validate_status(self, status: Optional[object]) -> None:
        if status is not None and status not in VALID_MEMORY_CONFIRMATION_STATUSES:
            raise MemoryServiceError("Invalid memory confirmation status.", 400)

    def validate_memory_type(self, memory_type: Optional[object]) -> None:
        if (
            memory_type is not None
            and memory_type not in VALID_MEMORY_CONFIRMATION_MEMORY_TYPES
        ):
            raise MemoryServiceError("Invalid memory confirmation memory type.", 400)

    def _now_iso(self) -> str:
        return datetime.now(timezone.utc).isoformat()
