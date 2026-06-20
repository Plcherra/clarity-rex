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

    def _delete_confirmation_summary(self, target: str, match) -> dict:
        return {
            "created": 0,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 1,
            "records": [
                {
                    "kind": match.table,
                    "type": "memory_delete",
                    "action": "delete_confirmation_required",
                    "id": match.id,
                    "title": match.title or target,
                    "metadata": {
                        "delete_target": target,
                        "backend_confirmed": False,
                    },
                }
            ],
        }

    def _delete_archived_summary(self, affected_records: list) -> dict:
        return {
            "created": 0,
            "updated": 0,
            "archived": len(affected_records),
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": record.table,
                    "type": "memory_delete",
                    "action": "direct_archived",
                    "id": record.id,
                    "title": record.title,
                    "metadata": {
                        "backend_confirmed": True,
                        "archive_strategy": "soft_delete_inactive",
                    },
                }
                for record in affected_records
            ],
        }

    def _delete_not_found_summary(self, target: str) -> dict:
        return self._delete_skipped_summary(
            target,
            action="delete_not_found",
            reason="No active saved memory matched the delete request.",
        )

    def _delete_ambiguous_summary(self, target: str, matches: list) -> dict:
        summary = self._delete_skipped_summary(
            target,
            action="delete_ambiguous",
            reason="Multiple active saved memories matched the delete request.",
        )
        summary["records"][0]["metadata"]["match_count"] = len(matches)
        summary["records"][0]["metadata"]["matches"] = [
            {"kind": match.table, "id": match.id, "title": match.title}
            for match in matches[:5]
        ]
        return summary

    def _delete_failed_summary(self, target: str, report: dict) -> dict:
        summary = self._delete_skipped_summary(
            target,
            action="delete_failed",
            reason="Backend archive was not confirmed.",
        )
        summary["records"][0]["metadata"]["correction_report"] = report
        return summary

    def _delete_rejected_summary(self) -> dict:
        return self._delete_skipped_summary(
            "",
            action="delete_rejected",
            reason="User rejected the pending delete confirmation.",
        )

    def _delete_skipped_summary(self, target: str, *, action: str, reason: str) -> dict:
        return {
            "created": 0,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 1,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": "memory_delete",
                    "type": "memory_delete",
                    "action": action,
                    "title": target,
                    "metadata": {
                        "backend_confirmed": False,
                        "reason": reason,
                    },
                }
            ],
        }
