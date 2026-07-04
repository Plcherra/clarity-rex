"""Apply confirmed conversational plan discipline decisions via service layer."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import MemoryDisciplineAction, MemoryDisciplineDecision
from app.models.plan import (
    PlanCreateRequest,
    PlanMilestoneCreateRequest,
    PlanMilestoneUpdateRequest,
    PlanUpdateRequest,
)
from app.services.conversational_plan_decision_store import confirmed_decision
from app.services.memory_discipline_confirmed_writes import CONFIRMED_PLAN_SERVICE_CHANNEL
from app.services.plan_errors import PlanServiceError
from app.services.plan_service import PlanService


class ConfirmedPlanWriteApplier:
    def __init__(
        self,
        memory_service: Any,
        *,
        plan_service: Optional[PlanService] = None,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)

    async def apply_confirmed_decision(
        self,
        decision: MemoryDisciplineDecision,
        *,
        conversation_id: str,
        source_message_id: str | None = None,
    ) -> dict[str, Any]:
        confirmed = confirmed_decision(decision)
        action = confirmed.action
        payload = dict(confirmed.payload)
        metadata = _confirmed_metadata(payload, confirmed)

        try:
            if action == MemoryDisciplineAction.CREATE_PLAN:
                record = await self.plan_service.create_plan(
                    PlanCreateRequest(
                        plan_type=payload.get("plan_type") or "personal",
                        title=str(payload.get("title") or ""),
                        description=payload.get("description"),
                        desired_outcome=payload.get("desired_outcome"),
                        primary_entity_id=payload.get("primary_entity_id"),
                        source_conversation_id=conversation_id,
                        source_message_id=source_message_id,
                        source_memory_id=payload.get("source_memory_id"),
                        priority=int(payload.get("priority") or 4),
                        target_date=payload.get("target_date"),
                        metadata=metadata,
                    )
                )
            elif action == MemoryDisciplineAction.CREATE_MILESTONE:
                plan_id = payload.get("plan_id") or confirmed.metadata.get("parent_plan_id")
                record = await self.plan_service.create_milestone(
                    PlanMilestoneCreateRequest(
                        plan_id=str(plan_id or ""),
                        title=str(payload.get("title") or ""),
                        description=payload.get("description"),
                        milestone_type=payload.get("milestone_type") or "checkpoint",
                        target_date=payload.get("target_date"),
                        source_conversation_id=conversation_id,
                        source_message_id=source_message_id,
                        source_memory_id=payload.get("source_memory_id"),
                        priority=int(payload.get("priority") or 3),
                        status=payload.get("status") or "open",
                        metadata=metadata,
                    )
                )
            elif action == MemoryDisciplineAction.UPDATE_PLAN:
                target_id = str(confirmed.target_id or "")
                record = await self.plan_service.update_plan(
                    target_id,
                    PlanUpdateRequest(
                        **{
                            key: payload[key]
                            for key in (
                                "plan_type",
                                "title",
                                "description",
                                "desired_outcome",
                                "primary_entity_id",
                                "priority",
                                "status",
                                "target_date",
                            )
                            if key in payload and payload[key] is not None
                        },
                        metadata=metadata,
                    ),
                )
            elif action == MemoryDisciplineAction.UPDATE_MILESTONE:
                target_id = str(confirmed.target_id or "")
                record = await self.plan_service.update_milestone(
                    target_id,
                    PlanMilestoneUpdateRequest(
                        **{
                            key: payload[key]
                            for key in (
                                "title",
                                "description",
                                "milestone_type",
                                "target_date",
                                "priority",
                                "status",
                            )
                            if key in payload and payload[key] is not None
                        },
                        metadata=metadata,
                    ),
                )
            elif action == MemoryDisciplineAction.CREATE_ENTITY_EVENT:
                write_payload = {
                    **payload,
                    "source_conversation_id": conversation_id,
                    "metadata": metadata,
                }
                if source_message_id:
                    write_payload["source_message_id"] = source_message_id
                record = await self.memory_service.create_entity_event(write_payload)
            else:
                return {
                    "action": action.value,
                    "applied": False,
                    "reason": f"Unsupported confirmed action: {action.value}",
                }
        except PlanServiceError:
            return {"action": action.value, "applied": False}
        except Exception:
            return {"action": action.value, "applied": False}

        if not isinstance(record, dict) or not record.get("id"):
            return {"action": action.value, "applied": False}

        merged = _record_was_merged(record)
        return {
            "action": action.value,
            "applied": True,
            "record": record,
            "merged": merged,
        }


def _confirmed_metadata(
    payload: dict[str, Any],
    decision: MemoryDisciplineDecision,
) -> dict[str, Any]:
    metadata = {
        **dict(payload.get("metadata") or {}),
        **dict(decision.metadata or {}),
        "source": "conversational_plan_confirmed",
        "discipline_write_channel": CONFIRMED_PLAN_SERVICE_CHANNEL,
    }
    if decision.action == MemoryDisciplineAction.CREATE_PLAN:
        metadata.setdefault("allow_auto_merge", True)
    metadata.pop("prevent_related_merge", None)
    return metadata


def _record_was_merged(record: dict[str, Any]) -> bool:
    metadata = record.get("metadata") or {}
    return bool(
        metadata.get("merged_into_existing_plan_id")
        or metadata.get("merge_reason")
    )
