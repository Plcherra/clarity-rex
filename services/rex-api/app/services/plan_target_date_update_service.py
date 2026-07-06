"""Confirm and apply target-date updates for existing goals."""

from __future__ import annotations

from typing import Any, Optional

from app.services.conversation_pending_action import PendingAction
from app.services.durable_write_builders import proposal_from_bulk_plan_target_date
from app.services.plan_service import PlanService
from app.services.plan_target_date_parsing import (
    looks_like_plan_target_date_update,
    resolve_plan_target_date_iso,
    selects_all_active_plans,
)


class PlanTargetDateUpdateService:
    def __init__(
        self,
        memory_service: Any,
        *,
        plan_service: Optional[PlanService] = None,
        durable_write_service=None,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)
        self.durable_write_service = durable_write_service

    async def handle_turn(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        time_context: dict,
        pending_action=None,
    ) -> Optional[dict]:
        if self.durable_write_service is None:
            return None
        if not looks_like_plan_target_date_update(message):
            return None
        if self._has_non_durable_pending(pending_action):
            return None

        target_date = resolve_plan_target_date_iso(
            message,
            time_context=time_context,
        )
        if not target_date:
            return None

        try:
            plans = await self.plan_service.list_plans(active=True, status="active")
        except Exception:
            return None
        selected = self._select_plans(message, plans)
        if not selected:
            return None

        proposal = proposal_from_bulk_plan_target_date(
            selected,
            target_date=target_date,
            time_context=time_context,
        )
        return await self.durable_write_service._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
        )

    def _select_plans(
        self,
        message: str,
        plans: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        active = [plan for plan in plans if plan.get("id") and plan.get("title")]
        if not active:
            return []
        if selects_all_active_plans(message):
            return active
        missing_dates = [
            plan for plan in active if not str(plan.get("target_date") or "").strip()
        ]
        if missing_dates:
            return missing_dates
        return active

    def _has_non_durable_pending(self, pending_action) -> bool:
        pending = (
            pending_action
            if isinstance(pending_action, PendingAction)
            else PendingAction.from_dict(pending_action)
        )
        if pending is None:
            return False
        return pending.action_type != "durable_write"
