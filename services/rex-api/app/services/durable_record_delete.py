"""Hard-delete confirmed records for durable delete proposals."""

from __future__ import annotations

from typing import Any, Optional

from app.services.memory_correction_record_rules import spec_for_table
from app.services.memory_correction_types import CorrectionAffectedRecord

HARD_DELETE_METHODS = {
    "long_term_memory": "delete_long_term_memory",
    "entities": "delete_entity",
    "entity_events": "delete_entity_event",
    "personal_rules": "delete_personal_rule",
    "plans": "delete_plan",
    "plan_milestones": "delete_plan_milestone",
    "open_threads": "delete_open_thread",
}


async def hard_delete_record(
    memory_service: Any,
    *,
    table: str,
    record_id: str,
) -> bool:
    method_name = HARD_DELETE_METHODS.get(table)
    if not method_name:
        return False
    method = getattr(memory_service, method_name, None)
    if method is None:
        return False
    try:
        deleted = await method(record_id)
    except Exception:
        return False
    if deleted is False:
        return False
    return await _record_is_gone(memory_service, table=table, record_id=record_id)


async def hard_delete_match(
    memory_service: Any,
    match: CorrectionAffectedRecord,
) -> Optional[CorrectionAffectedRecord]:
    if match.action == "would_remove_attribute":
        return None
    deleted = await hard_delete_record(
        memory_service,
        table=match.table,
        record_id=match.id,
    )
    if not deleted:
        return None
    return CorrectionAffectedRecord(
        table=match.table,
        id=match.id,
        action="deleted",
        title=match.title,
        previous=match.previous,
    )


async def _record_is_gone(
    memory_service: Any,
    *,
    table: str,
    record_id: str,
) -> bool:
    if table == "open_threads":
        getter = getattr(memory_service, "open_thread_repository", None)
        if getter is not None:
            repo = getter if not callable(getter) else getter()
            get_thread = getattr(repo, "get_thread", None)
            if get_thread is not None:
                try:
                    row = await get_thread(record_id)
                except Exception:
                    return False
                return row is None
    try:
        spec = spec_for_table(table)
    except KeyError:
        return True
    list_method = getattr(memory_service, spec.list_method, None)
    if list_method is None:
        return True
    try:
        rows = await list_method(limit=250)
    except TypeError:
        try:
            rows = await list_method(active=True, limit=250)
        except Exception:
            return False
    except Exception:
        return False
    if not isinstance(rows, list):
        return False
    return all(str(row.get("id") or "") != record_id for row in rows)
