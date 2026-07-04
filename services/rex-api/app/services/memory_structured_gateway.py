from __future__ import annotations

from typing import Optional

from app.services.structured_memory_repository import StructuredMemoryRepository


class MemoryStructuredGateway:
    def _get_structured_memory_repository(self) -> StructuredMemoryRepository:
        repository = getattr(self, "structured_memory_repository", None)
        if repository is None:
            repository = StructuredMemoryRepository(self)
            self.structured_memory_repository = repository
        return repository

    async def create_entity(self, entity: dict) -> dict:
        return await self._get_structured_memory_repository().create_entity(entity)

    async def list_entities(
        self,
        limit: int = 50,
        entity_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        normalized_name: Optional[str] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_entities(
            limit=limit,
            entity_type=entity_type,
            status=status,
            active=active,
            normalized_name=normalized_name,
        )

    async def list_entities_paged(
        self,
        limit: int = 50,
        entity_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        normalized_name: Optional[str] = None,
        cursor: Optional[str] = None,
    ) -> tuple[list[dict], Optional[str], bool]:
        return await self._get_structured_memory_repository().list_entities_paged(
            limit=limit,
            entity_type=entity_type,
            status=status,
            active=active,
            normalized_name=normalized_name,
            cursor=cursor,
        )

    async def update_entity(self, entity_id: str, **updates: object) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_entity(
            entity_id,
            **updates,
        )

    async def deactivate_entity(self, entity_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_entity(
            entity_id,
        )

    async def create_entity_event(self, event: dict) -> dict:
        return await self._get_structured_memory_repository().create_entity_event(
            event,
        )

    async def list_entity_events(
        self,
        limit: int = 50,
        entity_id: Optional[str] = None,
        event_type: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_entity_events(
            limit=limit,
            entity_id=entity_id,
            event_type=event_type,
            active=active,
        )

    async def update_entity_event(
        self,
        event_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_entity_event(
            event_id,
            **updates,
        )

    async def deactivate_entity_event(self, event_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_entity_event(
            event_id,
        )

    async def create_personal_rule(self, rule: dict) -> dict:
        return await self._get_structured_memory_repository().create_personal_rule(
            rule,
        )

    async def list_personal_rules(
        self,
        limit: int = 50,
        rule_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_personal_rules(
            limit=limit,
            rule_type=rule_type,
            status=status,
            active=active,
        )

    async def list_personal_rules_paged(
        self,
        limit: int = 50,
        rule_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        cursor: Optional[str] = None,
    ) -> tuple[list[dict], Optional[str], bool]:
        return await self._get_structured_memory_repository().list_personal_rules_paged(
            limit=limit,
            rule_type=rule_type,
            status=status,
            active=active,
            cursor=cursor,
        )

    async def update_personal_rule(
        self,
        rule_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_personal_rule(
            rule_id,
            **updates,
        )

    async def deactivate_personal_rule(self, rule_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_personal_rule(
            rule_id,
        )

    async def create_plan(self, plan: dict) -> dict:
        return await self._get_structured_memory_repository().create_plan(plan)

    async def list_plans(
        self,
        limit: int = 50,
        plan_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_plans(
            limit=limit,
            plan_type=plan_type,
            status=status,
            active=active,
        )

    async def list_plans_paged(
        self,
        limit: int = 50,
        plan_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        cursor: Optional[str] = None,
    ) -> tuple[list[dict], Optional[str], bool]:
        return await self._get_structured_memory_repository().list_plans_paged(
            limit=limit,
            plan_type=plan_type,
            status=status,
            active=active,
            cursor=cursor,
        )

    async def update_plan(self, plan_id: str, **updates: object) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_plan(
            plan_id,
            **updates,
        )

    async def deactivate_plan(self, plan_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_plan(plan_id)

    async def create_plan_milestone(self, milestone: dict) -> dict:
        return await self._get_structured_memory_repository().create_plan_milestone(
            milestone,
        )

    async def list_plan_milestones(
        self,
        limit: int = 50,
        plan_id: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_plan_milestones(
            limit=limit,
            plan_id=plan_id,
            status=status,
            active=active,
        )

    async def update_plan_milestone(
        self,
        milestone_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_plan_milestone(
            milestone_id,
            **updates,
        )

    async def deactivate_plan_milestone(self, milestone_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_plan_milestone(
            milestone_id,
        )
