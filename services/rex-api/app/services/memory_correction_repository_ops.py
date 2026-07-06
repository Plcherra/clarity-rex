"""Repository read/write/archive helpers for memory correction."""

from __future__ import annotations

from typing import Any, Optional

from app.services.memory_correction_types import TableSpec
from app.services.durable_record_delete import HARD_DELETE_METHODS


class MemoryCorrectionRepositoryOps:
    def __init__(self, memory_service: Any, *, scan_limit: int = 250) -> None:
        self.memory_service = memory_service
        self.scan_limit = scan_limit

    async def safe_list(self, spec: TableSpec) -> list[dict[str, Any]]:
        method = getattr(self.memory_service, spec.list_method, None)
        if method is None:
            return []
        try:
            return await method(active=True, limit=self.scan_limit)
        except TypeError:
            try:
                return await method(limit=self.scan_limit)
            except Exception:
                return []
        except Exception:
            return []

    async def safe_update(
        self,
        spec: TableSpec,
        record_id: str,
        updates: dict[str, Any],
    ) -> Optional[dict[str, Any]]:
        method = getattr(self.memory_service, spec.update_method, None)
        if method is None:
            return None
        try:
            return await method(record_id, **updates)
        except Exception:
            return None

    async def safe_archive(self, spec: TableSpec, record_id: str) -> bool:
        method = getattr(self.memory_service, spec.deactivate_method, None)
        if method is None:
            return False
        try:
            archived = await method(record_id)
        except Exception:
            return False
        return await self.archive_was_confirmed(spec, record_id, archived)

    async def archive_was_confirmed(
        self,
        spec: TableSpec,
        record_id: str,
        archived: object,
    ) -> bool:
        if not archived:
            return False
        if isinstance(archived, dict) and archived.get("active") is not False:
            return False
        active_records = await self.verified_active_list(spec)
        if active_records is None:
            return False
        return all(str(record.get("id") or "") != record_id for record in active_records)

    async def safe_delete(self, spec: TableSpec, record_id: str) -> bool:
        method_name = HARD_DELETE_METHODS.get(spec.table)
        if not method_name:
            return False
        method = getattr(self.memory_service, method_name, None)
        if method is None:
            return False
        try:
            deleted = await method(record_id)
        except Exception:
            return False
        if deleted is False:
            return False
        return await self.delete_was_confirmed(spec, record_id)

    async def delete_was_confirmed(self, spec: TableSpec, record_id: str) -> bool:
        if spec.table == "open_threads":
            repo = getattr(self.memory_service, "open_thread_repository", None)
            get_thread = getattr(repo, "get_thread", None) if repo is not None else None
            if get_thread is not None:
                try:
                    row = await get_thread(record_id)
                except Exception:
                    return False
                return row is None
        active_records = await self.verified_active_list(spec)
        if active_records is None:
            return False
        return all(str(record.get("id") or "") != record_id for record in active_records)

    async def verified_active_list(
        self,
        spec: TableSpec,
    ) -> Optional[list[dict[str, Any]]]:
        method = getattr(self.memory_service, spec.list_method, None)
        if method is None:
            return None
        try:
            return await method(active=True, limit=self.scan_limit)
        except TypeError:
            try:
                return await method(limit=self.scan_limit)
            except Exception:
                return None
        except Exception:
            return None

    async def active_source_memories(
        self,
        source_memory_ids: list,
    ) -> list[dict[str, Any]]:
        source_ids = {
            str(source_id).strip()
            for source_id in source_memory_ids
            if str(source_id).strip()
        }
        if not source_ids:
            return []
        from app.services.memory_correction_record_rules import spec_for_table

        active_memories = await self.safe_list(spec_for_table("long_term_memory"))
        return [
            memory
            for memory in active_memories
            if str(memory.get("id") or "") in source_ids
        ]
