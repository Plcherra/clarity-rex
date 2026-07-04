from typing import Optional

from app.services.memory_errors import MemoryServiceError

VALID_MEMORY_CORRECTION_TYPES = {
    "entity_name",
    "entity_relationship",
    "plan_detail",
    "rule_detail",
    "location",
    "preference",
    "other",
}

MEMORY_CORRECTION_SELECT = (
    "id,correction_type,old_value,new_value,target_table,target_id,"
    "source_conversation_id,source_message_id,applied,confidence,metadata,created_at"
)


class MemoryCorrectionRepository:
    def __init__(self, store: object) -> None:
        self.store = store

    async def create_memory_correction(self, correction: dict) -> dict:
        correction_type = correction.get("correction_type")
        if correction_type not in VALID_MEMORY_CORRECTION_TYPES:
            raise MemoryServiceError("Invalid memory correction type.", 400)
        new_value = str(correction.get("new_value") or "").strip()
        if not new_value:
            raise MemoryServiceError("Memory correction new value is required.", 400)

        return await self.store._create_record(
            self.store.settings.supabase_memory_corrections_table,
            {
                "correction_type": correction_type,
                "old_value": correction.get("old_value"),
                "new_value": new_value,
                "target_table": correction.get("target_table"),
                "target_id": correction.get("target_id"),
                "source_conversation_id": correction.get("source_conversation_id"),
                "source_message_id": correction.get("source_message_id"),
                "applied": bool(correction.get("applied", False)),
                "confidence": correction.get("confidence", 0.9),
                "metadata": correction.get("metadata") or {},
            },
            MEMORY_CORRECTION_SELECT,
        )

    async def list_memory_corrections(
        self,
        limit: int = 50,
        correction_type: Optional[str] = None,
        applied: Optional[bool] = None,
        target_table: Optional[str] = None,
        target_id: Optional[str] = None,
    ) -> list[dict]:
        if correction_type is not None and (
            correction_type not in VALID_MEMORY_CORRECTION_TYPES
        ):
            raise MemoryServiceError("Invalid memory correction type.", 400)
        return await self.store._list_records(
            self.store.settings.supabase_memory_corrections_table,
            select=MEMORY_CORRECTION_SELECT,
            filters={
                "correction_type": correction_type,
                "applied": applied,
                "target_table": target_table,
                "target_id": target_id,
            },
            order="created_at.desc",
            limit=limit,
        )
