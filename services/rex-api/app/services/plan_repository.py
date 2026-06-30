from __future__ import annotations

from typing import Any

from app.services.memory_service import SupabaseMemoryService


class PlanRepository:
    def __init__(self, memory_service: SupabaseMemoryService) -> None:
        self.memory_service = memory_service

    async def create_plan(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self.memory_service.create_plan(payload)

    async def list_plans(
        self,
        *,
        plan_type: str | None = None,
        status: str | None = None,
        active: bool | None = True,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        return await self.memory_service.list_plans(
            plan_type=plan_type,
            status=status,
            active=active,
            limit=limit,
        )

    async def list_plans_paged(
        self,
        *,
        plan_type: str | None = None,
        status: str | None = None,
        active: bool | None = True,
        limit: int = 50,
        cursor: str | None = None,
    ) -> tuple[list[dict[str, Any]], str | None, bool]:
        return await self.memory_service.list_plans_paged(
            plan_type=plan_type,
            status=status,
            active=active,
            limit=limit,
            cursor=cursor,
        )

    async def update_plan(
        self,
        plan_id: str,
        **updates: object,
    ) -> dict[str, Any] | None:
        return await self.memory_service.update_plan(plan_id, **updates)

    async def deactivate_plan(self, plan_id: str) -> dict[str, Any] | None:
        return await self.memory_service.deactivate_plan(plan_id)

    async def create_plan_milestone(
        self,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        return await self.memory_service.create_plan_milestone(payload)

    async def list_plan_milestones(
        self,
        *,
        plan_id: str | None = None,
        status: str | None = None,
        active: bool | None = True,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        return await self.memory_service.list_plan_milestones(
            plan_id=plan_id,
            status=status,
            active=active,
            limit=limit,
        )

    async def update_plan_milestone(
        self,
        milestone_id: str,
        **updates: object,
    ) -> dict[str, Any] | None:
        return await self.memory_service.update_plan_milestone(
            milestone_id,
            **updates,
        )

    async def deactivate_plan_milestone(
        self,
        milestone_id: str,
    ) -> dict[str, Any] | None:
        return await self.memory_service.deactivate_plan_milestone(milestone_id)

    async def list_entities(
        self,
        *,
        active: bool | None = True,
        limit: int = 100,
    ) -> list[dict[str, Any]]:
        list_entities = getattr(self.memory_service, "list_entities", None)
        if list_entities is None:
            return []
        return await list_entities(active=active, limit=limit)
