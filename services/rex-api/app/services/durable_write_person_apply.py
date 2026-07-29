"""Apply person card state/note durable write snapshots."""

from __future__ import annotations

from typing import Any

from app.services.durable_write_apply_failures import apply_failure_result


async def apply_person_state_update(
    memory_service: Any,
    snapshot: dict[str, Any],
) -> dict[str, Any]:
    payload = dict(snapshot.get("payload") or {})
    entity_id = str(payload.get("entity_id") or "").strip()
    summary = str(payload.get("summary") or "").strip()
    if not entity_id or not summary:
        return apply_failure_result(
            snapshot_type="person_state_update",
            detail="invalid_payload",
        )
    update_entity = getattr(memory_service, "update_entity", None)
    if update_entity is None:
        return apply_failure_result(
            snapshot_type="person_state_update",
            detail="missing_entity_updater",
        )
    try:
        record = await update_entity(entity_id, summary=summary)
    except Exception as error:
        return apply_failure_result(
            snapshot_type="person_state_update",
            error=error,
        )
    if not isinstance(record, dict):
        return apply_failure_result(
            snapshot_type="person_state_update",
            detail="entity_not_found",
        )
    return {
        "applied": True,
        "record": record,
        "merged": False,
        "updated_count": 1,
    }


async def apply_person_note_update(
    memory_service: Any,
    snapshot: dict[str, Any],
) -> dict[str, Any]:
    payload = dict(snapshot.get("payload") or {})
    entity_id = str(payload.get("entity_id") or "").strip()
    notes = str(payload.get("notes") or payload.get("note") or "").strip()
    if not entity_id or not notes:
        return apply_failure_result(
            snapshot_type="person_note_update",
            detail="invalid_payload",
        )

    list_entities = getattr(memory_service, "list_entities", None)
    update_entity = getattr(memory_service, "update_entity", None)
    if update_entity is None:
        return apply_failure_result(
            snapshot_type="person_note_update",
            detail="missing_entity_updater",
        )

    existing: dict[str, Any] | None = None
    if callable(list_entities):
        try:
            rows = await list_entities(active=True, limit=100)
        except Exception:
            rows = []
        for row in rows or []:
            if str(row.get("id") or "") == entity_id:
                existing = row
                break

    metadata = dict((existing or {}).get("metadata") or {})
    attributes = dict(metadata.get("attributes") or {})
    attributes["notes"] = notes
    metadata["attributes"] = attributes

    try:
        record = await update_entity(entity_id, metadata=metadata)
    except Exception as error:
        return apply_failure_result(
            snapshot_type="person_note_update",
            error=error,
        )
    if not isinstance(record, dict):
        return apply_failure_result(
            snapshot_type="person_note_update",
            detail="entity_not_found",
        )
    return {
        "applied": True,
        "record": record,
        "merged": False,
        "updated_count": 1,
    }
