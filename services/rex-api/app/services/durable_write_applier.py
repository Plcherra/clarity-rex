"""Apply frozen durable write snapshots after user confirmation."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineDecision,
    MemoryRecordKind,
)
from app.models.plan import PlanCreateRequest
from app.services.confirmed_plan_write_applier import ConfirmedPlanWriteApplier
from app.services.durable_write_proposal import DurableWriteProposal
from app.services.memory_discipline_confirmed_writes import CONFIRMED_PLAN_SERVICE_CHANNEL
from app.services.open_thread_service import OpenThreadService
from app.models.open_thread import OpenThreadCreateRequest
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
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)
        self.open_thread_service = open_thread_service or OpenThreadService(memory_service)
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
                return {"applied": False}
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
        return {"applied": False, "reason": f"unsupported snapshot type: {snapshot_type}"}

    async def _apply_memory(
        self,
        snapshot: dict[str, Any],
        *,
        conversation_id: str,
        source_message_id: str | None,
    ) -> dict[str, Any]:
        payload = dict(snapshot.get("payload") or {})
        metadata = dict(payload.get("metadata") or {})
        metadata.setdefault("source", "durable_write_confirmed")
        metadata.setdefault("discipline_write_channel", CONFIRMED_PLAN_SERVICE_CHANNEL)
        try:
            record = await self.memory_service.save_long_term_memory(
                memory_type=str(payload.get("memory_type") or "fact"),
                content=str(payload.get("content") or payload.get("body") or ""),
                source_conversation_id=conversation_id,
                source_message_id=source_message_id,
                importance=int(payload.get("importance") or 3),
                metadata=metadata,
            )
        except Exception:
            return {"applied": False}
        if not isinstance(record, dict) or not record.get("id"):
            return {"applied": False}
        return {"applied": True, "record": record, "merged": False}

    async def _apply_memory_update(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        payload = dict(snapshot.get("payload") or {})
        memory_id = str(payload.get("memory_id") or "").strip()
        update_memory = getattr(self.memory_service, "update_long_term_memory", None)
        if update_memory is None or not memory_id:
            return {"applied": False}
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
        except Exception:
            return {"applied": False}
        if not isinstance(record, dict) or not record.get("id"):
            return {"applied": False}
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
        except PlanServiceError:
            return {"applied": False}
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
        except Exception:
            return {"applied": False}
        if not isinstance(record, dict) or not record.get("id"):
            return {"applied": False}
        return {"applied": True, "record": record, "merged": False}


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
