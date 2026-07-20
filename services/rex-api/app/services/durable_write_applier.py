"""Apply frozen durable write snapshots after user confirmation."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineDecision,
    MemoryRecordKind,
)
from app.models.plan import PlanCreateRequest, PlanUpdateRequest
from app.services.confirmed_plan_write_applier import ConfirmedPlanWriteApplier
from app.services.durable_write_apply_failures import apply_failure_result
from app.services.durable_write_proposal import DurableWriteProposal
from app.services.memory_correction_types import CorrectionAffectedRecord
from app.services.memory_correction_delete_applier import MemoryCorrectionDeleteApplier
from app.services.memory_correction_repository_ops import MemoryCorrectionRepositoryOps
from app.services.memory_discipline_confirmed_writes import CONFIRMED_PLAN_SERVICE_CHANNEL
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_discipline_writes import (
    MemoryWriteError,
    apply_disciplined_long_term_memory,
)
from app.services.memory_persist_orchestrator import MemoryPersistOrchestrator
from app.services.open_thread_service import OpenThreadService
from app.models.open_thread import OpenThreadCreateRequest, OpenThreadUpdateRequest
from app.services.plan_errors import PlanServiceError
from app.services.plan_merge_service import normalize_text
from app.services.plan_service import PlanService


class DurableWriteApplier:
    def __init__(
        self,
        memory_service: Any,
        *,
        plan_service: Optional[PlanService] = None,
        open_thread_service: Optional[OpenThreadService] = None,
        plan_applier: Optional[ConfirmedPlanWriteApplier] = None,
        discipline: Optional[MemoryDisciplineService] = None,
        persist_orchestrator: Optional[MemoryPersistOrchestrator] = None,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)
        self.open_thread_service = open_thread_service or OpenThreadService(memory_service)
        self.discipline = discipline or MemoryDisciplineService(memory_service)
        self.persist_orchestrator = (
            persist_orchestrator or MemoryPersistOrchestrator()
        )
        self.plan_applier = plan_applier or ConfirmedPlanWriteApplier(
            memory_service,
            plan_service=self.plan_service,
        )

    async def apply_proposal(
        self,
        proposal: DurableWriteProposal,
        *,
        conversation_id: str,
        source_message_id: str | None = None,
    ) -> dict[str, Any]:
        snapshot = dict(proposal.apply_snapshot)
        snapshot_type = str(snapshot.get("type") or proposal.write_kind)

        if snapshot_type == "memory":
            return await self._apply_memory(
                snapshot,
                conversation_id=conversation_id,
                source_message_id=source_message_id,
            )
        if snapshot_type == "memory_update":
            return await self._apply_memory_update(snapshot)
        if snapshot_type == "discipline_decision":
            decision = _decision_from_snapshot(snapshot)
            if decision is None:
                return apply_failure_result(
                    snapshot_type=snapshot_type,
                    detail="invalid_decision",
                    conversation_id=conversation_id,
                )
            return await self.plan_applier.apply_confirmed_decision(
                decision,
                conversation_id=conversation_id,
                source_message_id=source_message_id,
            )
        if snapshot_type in {"plan", "create_plan"}:
            return await self._apply_plan(
                snapshot,
                conversation_id=conversation_id,
                source_message_id=source_message_id,
                merge_disclosed=proposal.merge_target_title,
            )
        if snapshot_type == "open_thread":
            return await self._apply_open_thread(
                snapshot,
                conversation_id=conversation_id,
                source_message_id=source_message_id,
            )
        if snapshot_type == "open_thread_update":
            return await self._apply_open_thread_update(
                snapshot,
                conversation_id=conversation_id,
            )
        if snapshot_type == "bulk_plan_target_date":
            return await self._apply_bulk_plan_target_date(snapshot)
        if snapshot_type == "record_delete":
            return await self._apply_record_delete(snapshot)
        return apply_failure_result(
            snapshot_type=snapshot_type or "unknown",
            detail="unsupported_snapshot_type",
            conversation_id=conversation_id,
        )

    async def _apply_memory(
        self,
        snapshot: dict[str, Any],
        *,
        conversation_id: str,
        source_message_id: str | None,
    ) -> dict[str, Any]:
        payload = dict(snapshot.get("payload") or {})

        async def create_fn(write_payload: dict[str, Any]) -> dict[str, Any]:
            return await self.memory_service.save_long_term_memory(
                memory_type=str(write_payload.get("memory_type") or "fact"),
                content=str(write_payload.get("content") or ""),
                source_conversation_id=write_payload.get("source_conversation_id")
                or conversation_id,
                source_message_id=write_payload.get("source_message_id")
                or source_message_id,
                importance=int(write_payload.get("importance") or 3),
                metadata=dict(write_payload.get("metadata") or {}),
            )

        try:
            result = await apply_disciplined_long_term_memory(
                self.discipline,
                payload=payload,
                conversation_id=conversation_id,
                source_message_id=source_message_id,
                create_fn=create_fn,
            )
        except MemoryWriteError as exc:
            return apply_failure_result(
                snapshot_type="memory",
                detail="discipline_context_unavailable"
                if exc.status_code == 503
                else "memory_write_error",
                conversation_id=conversation_id,
            )
        except Exception as exc:
            return apply_failure_result(
                snapshot_type="memory",
                error=exc,
                conversation_id=conversation_id,
            )
        record = result.get("record") if isinstance(result, dict) else None
        if isinstance(record, dict):
            await self.persist_orchestrator.after_long_term_memory_write(
                self.memory_service,
                record,
            )
        return result

    async def _apply_memory_update(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        payload = dict(snapshot.get("payload") or {})
        memory_id = str(payload.get("memory_id") or "").strip()
        update_memory = getattr(self.memory_service, "update_long_term_memory", None)
        if update_memory is None or not memory_id:
            return apply_failure_result(
                snapshot_type="memory_update",
                detail="missing_memory_id_or_updater",
            )
        metadata = dict(payload.get("metadata") or {})
        metadata.setdefault("source", "durable_write_confirmed")
        try:
            record = await update_memory(
                memory_id,
                memory_type=payload.get("memory_type"),
                content=str(payload.get("content") or payload.get("body") or ""),
                importance=int(payload.get("importance") or 3),
                active=True,
                metadata=metadata,
            )
        except Exception as exc:
            return apply_failure_result(
                snapshot_type="memory_update",
                error=exc,
            )
        if not isinstance(record, dict) or not record.get("id"):
            return apply_failure_result(
                snapshot_type="memory_update",
                detail="missing_record",
            )
        await self.persist_orchestrator.after_long_term_memory_write(
            self.memory_service,
            record,
        )
        return {"applied": True, "record": record, "merged": False}

    async def _apply_plan(
        self,
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
            record = await self.plan_service.create_plan(
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

    async def _apply_open_thread(
        self,
        snapshot: dict[str, Any],
        *,
        conversation_id: str,
        source_message_id: str | None,
    ) -> dict[str, Any]:
        payload = dict(snapshot.get("payload") or {})
        metadata = dict(payload.get("metadata") or {})
        metadata.setdefault("source", "durable_write_confirmed")
        try:
            record = await self.open_thread_service.create_thread(
                OpenThreadCreateRequest(
                    title=str(payload.get("title") or ""),
                    summary=payload.get("summary"),
                    status="active",
                    source="user_confirmed",
                    source_conversation_id=conversation_id,
                    source_message_id=source_message_id,
                    metadata=metadata,
                )
            )
        except Exception as exc:
            return apply_failure_result(
                snapshot_type="open_thread",
                error=exc,
                conversation_id=conversation_id,
            )
        if not isinstance(record, dict) or not record.get("id"):
            return apply_failure_result(
                snapshot_type="open_thread",
                detail="missing_record",
                conversation_id=conversation_id,
            )
        return {"applied": True, "record": record, "merged": False}

    async def _apply_open_thread_update(
        self,
        snapshot: dict[str, Any],
        *,
        conversation_id: str,
    ) -> dict[str, Any]:
        payload = dict(snapshot.get("payload") or {})
        thread_id = str(payload.get("thread_id") or "").strip()
        if not thread_id:
            return apply_failure_result(
                snapshot_type="open_thread_update",
                detail="missing_thread_id",
                conversation_id=conversation_id,
            )
        metadata = dict(payload.get("metadata") or {})
        metadata.setdefault("source", "durable_write_confirmed")
        try:
            record = await self.open_thread_service.update_thread(
                thread_id,
                OpenThreadUpdateRequest(
                    title=str(payload.get("title") or "") or None,
                    summary=payload.get("summary"),
                    metadata=metadata,
                ),
            )
        except Exception as exc:
            return apply_failure_result(
                snapshot_type="open_thread_update",
                error=exc,
                conversation_id=conversation_id,
            )
        if not isinstance(record, dict) or not record.get("id"):
            return apply_failure_result(
                snapshot_type="open_thread_update",
                detail="missing_record",
                conversation_id=conversation_id,
            )
        return {
            "applied": True,
            "record": record,
            "merged": False,
            "updated_count": 1,
        }

    async def _apply_bulk_plan_target_date(
        self,
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
                record = await self.plan_service.update_plan(
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

    async def _apply_record_delete(
        self,
        snapshot: dict[str, Any],
    ) -> dict[str, Any]:
        payload = dict(snapshot.get("payload") or {})
        table = str(payload.get("table") or "").strip()
        record_id = str(payload.get("id") or "").strip()
        if not table or not record_id:
            return apply_failure_result(
                snapshot_type="record_delete",
                detail="invalid_payload",
            )

        ops = MemoryCorrectionRepositoryOps(self.memory_service)
        delete_applier = MemoryCorrectionDeleteApplier(ops)
        match = CorrectionAffectedRecord(
            table=table,
            id=record_id,
            action="would_delete",
            title=str(payload.get("title") or ""),
            previous={},
        )
        affected = await delete_applier.apply_single_delete_match(match)
        if affected is None:
            return apply_failure_result(
                snapshot_type="record_delete",
                detail="delete_not_applied",
            )
        return {
            "applied": True,
            "record": {
                "id": affected.id,
                "title": affected.title,
                "table": affected.table,
            },
            "merged": False,
            "deleted": True,
        }


async def preview_plan_merge_title(
    plan_service: PlanService,
    *,
    plan_type: str,
    title: str,
) -> str | None:
    try:
        existing = await plan_service.list_plans(plan_type=plan_type, active=True, limit=100)
    except Exception:
        return None
    normalized = normalize_text(title)
    for plan in existing:
        if normalize_text(plan.get("title")) == normalized:
            return str(plan.get("title") or "")
    return None


def _decision_from_snapshot(snapshot: dict[str, Any]) -> MemoryDisciplineDecision | None:
    raw = snapshot.get("decision")
    if not isinstance(raw, dict):
        return None
    try:
        return MemoryDisciplineDecision(
            action=MemoryDisciplineAction(str(raw.get("action"))),
            record_kind=MemoryRecordKind(str(raw.get("record_kind"))),
            payload=dict(raw.get("payload") or {}),
            reason=str(raw.get("reason") or ""),
            confidence=float(raw.get("confidence") or 0.75),
            target_table=raw.get("target_table"),
            target_id=raw.get("target_id"),
            requires_confirmation=False,
            related_records=[],
            metadata=dict(raw.get("metadata") or {}),
        )
    except Exception:
        return None
