"""Apply plan create/update snapshots for durable writes."""

from __future__ import annotations

from typing import Any

from app.models.plan import PlanCreateRequest, PlanUpdateRequest
from app.services.durable_write_apply_failures import apply_failure_result
from app.services.memory_discipline_confirmed_writes import CONFIRMED_PLAN_SERVICE_CHANNEL
from app.services.plan_errors import PlanServiceError
from app.services.plan_merge_service import normalize_text
from app.services.plan_service import PlanService


async def apply_plan_create(
    plan_service: PlanService,
    snapshot: dict[str, Any],
    *,
    conversation_id: str,
    source_message_id: str | None,
    merge_disclosed: str | None,
) -> dict[str, Any]:
    payload = dict(snapshot.get("payload") or {})
    metadata = dict(payload.get("metadata") or {})
    metadata.setdefault("source", "durable_write_confirmed")
    metadata.setdefault("discipline_write_channel", CONFIRMED_PLAN_SERVICE_CHANNEL)
    payload["metadata"] = metadata
    if merge_disclosed:
        metadata["merge_disclosed_to"] = merge_disclosed
    try:
        record = await plan_service.create_plan(
            PlanCreateRequest(
                plan_type=payload.get("plan_type") or "personal",
                title=str(payload.get("title") or ""),
                description=payload.get("description"),
                desired_outcome=payload.get("desired_outcome"),
                source_conversation_id=conversation_id,
                source_message_id=source_message_id,
                target_date=payload.get("target_date"),
                priority=int(payload.get("priority") or 4),
                metadata=metadata,
            )
        )
    except PlanServiceError as exc:
        return apply_failure_result(
            snapshot_type="plan",
            error=exc,
            conversation_id=conversation_id,
        )
    merged = bool(
        merge_disclosed
        or (record.get("metadata") or {}).get("merged_into_existing_plan_id")
    )
    return {"applied": True, "record": record, "merged": merged}


async def apply_plan_update(
    plan_service: PlanService,
    snapshot: dict[str, Any],
) -> dict[str, Any]:
    payload = dict(snapshot.get("payload") or {})
    plan_id = str(payload.get("plan_id") or "").strip()
    if not plan_id:
        return apply_failure_result(
            snapshot_type="plan_update",
            detail="missing_plan_id",
        )
    metadata = dict(payload.get("metadata") or {})
    metadata.setdefault("source", "durable_write_confirmed")
    existing_meta: dict[str, Any] = {}
    try:
        existing_rows = await plan_service.list_plans(active=True, limit=100)
    except Exception:
        existing_rows = []
    for row in existing_rows or []:
        if str(row.get("id") or "") == plan_id:
            raw_meta = row.get("metadata")
            if isinstance(raw_meta, dict):
                existing_meta = dict(raw_meta)
            break
    merged_metadata = {**existing_meta, **metadata}
    update_kwargs: dict[str, Any] = {"metadata": merged_metadata}
    for key in (
        "title",
        "description",
        "desired_outcome",
        "target_date",
        "status",
        "plan_type",
        "priority",
    ):
        if key in payload and payload[key] is not None:
            update_kwargs[key] = payload[key]
    try:
        record = await plan_service.update_plan(
            plan_id,
            PlanUpdateRequest(**update_kwargs),
        )
    except PlanServiceError as exc:
        return apply_failure_result(
            snapshot_type="plan_update",
            error=exc,
        )
    if not isinstance(record, dict) or not record.get("id"):
        return apply_failure_result(
            snapshot_type="plan_update",
            detail="missing_record",
        )
    return {
        "applied": True,
        "record": record,
        "merged": False,
        "updated_count": 1,
    }


async def apply_bulk_plan_target_date(
    plan_service: PlanService,
    snapshot: dict[str, Any],
) -> dict[str, Any]:
    payload = dict(snapshot.get("payload") or {})
    target_date = str(payload.get("target_date") or "").strip()
    raw_plans = payload.get("plans") or []
    if not target_date or not isinstance(raw_plans, list):
        return apply_failure_result(
            snapshot_type="bulk_plan_target_date",
            detail="invalid_payload",
        )

    updated_records: list[dict[str, Any]] = []
    for item in raw_plans:
        if not isinstance(item, dict):
            continue
        plan_id = str(item.get("id") or "").strip()
        if not plan_id:
            continue
        try:
            record = await plan_service.update_plan(
                plan_id,
                PlanUpdateRequest(target_date=target_date),
            )
        except PlanServiceError as exc:
            return apply_failure_result(
                snapshot_type="bulk_plan_target_date",
                error=exc,
                extra={"records": updated_records},
            )
        updated_records.append(record)

    if not updated_records:
        return apply_failure_result(
            snapshot_type="bulk_plan_target_date",
            detail="no_plans_updated",
        )
    return {
        "applied": True,
        "record": updated_records[-1],
        "records": updated_records,
        "merged": False,
        "updated_count": len(updated_records),
    }


async def preview_plan_merge_title(
    plan_service: PlanService,
    *,
    plan_type: str,
    title: str,
) -> str | None:
    try:
        existing = await plan_service.list_plans(
            plan_type=plan_type,
            active=True,
            limit=100,
        )
    except Exception:
        return None
    target = normalize_text(title)
    if not target:
        return None
    for plan in existing or []:
        if normalize_text(str(plan.get("title") or "")) == target:
            return str(plan.get("title") or "").strip() or None
    return None
