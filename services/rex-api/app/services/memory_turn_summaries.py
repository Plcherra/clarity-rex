from typing import Optional

from app.services.memory_failure_reporting import memory_degraded_metadata
from app.services.memory_intent_service import SimpleMemoryIntent
from app.services.memory_path_policy import direct_save_metadata


class MemoryTurnSummaries:
    def _simple_memory_saved_summary(
        self,
        intent: SimpleMemoryIntent,
        record: dict,
    ) -> dict:
        return {
            "created": 1,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": "long_term_memory",
                    "type": intent.memory_type,
                    "action": "direct_saved",
                    "id": record.get("id"),
                    "title": intent.content,
                    "metadata": direct_save_metadata(intent.metadata),
                }
            ],
        }

    def _simple_memory_updated_summary(
        self,
        intent: SimpleMemoryIntent,
        record: dict,
        *,
        previous_record: dict,
        archived_related: Optional[list[dict]] = None,
    ) -> dict:
        archived_related = archived_related or []
        records = [
            {
                "kind": "long_term_memory",
                "type": intent.memory_type,
                "action": "direct_updated",
                "id": record.get("id"),
                "title": intent.content,
                "previous_title": previous_record.get("content"),
                "metadata": direct_save_metadata(intent.metadata),
            }
        ]
        records.extend(
            {
                "kind": "long_term_memory",
                "type": archived.get("memory_type") or intent.memory_type,
                "action": "archived_superseded",
                "id": archived.get("id"),
                "title": archived.get("content"),
                "metadata": archived.get("metadata") or {},
            }
            for archived in archived_related
        )
        return {
            "created": 0,
            "updated": 1,
            "archived": len(archived_related),
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 0,
            "records": records,
        }

    def _simple_memory_rejected_summary(
        self,
        intent: SimpleMemoryIntent,
    ) -> dict:
        return {
            "created": 0,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 1,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": "simple_memory",
                    "type": intent.memory_type,
                    "action": "rejected",
                    "title": intent.content,
                    "metadata": direct_save_metadata(intent.metadata),
                }
            ],
        }

    def _simple_memory_failed_summary(
        self,
        intent: SimpleMemoryIntent,
        *,
        metadata: Optional[dict] = None,
    ) -> dict:
        failed_metadata = metadata or memory_degraded_metadata(
            direct_save_metadata(intent.metadata),
            operation="save_long_term_memory",
            failure_reason="durable_memory_save_failed",
            user_visible=True,
        )
        return {
            "created": 0,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 1,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": "simple_memory",
                    "type": intent.memory_type,
                    "action": "save_failed",
                    "title": intent.content,
                    "metadata": failed_metadata,
                }
            ],
        }
