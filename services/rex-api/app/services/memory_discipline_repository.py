from typing import Optional, Protocol


class MemoryDisciplineRepository(Protocol):
    async def list_long_term_memory(
        self,
        limit: int = 50,
        memory_type: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        pass

    async def list_entities(
        self,
        limit: int = 50,
        entity_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        normalized_name: Optional[str] = None,
    ) -> list[dict]:
        pass

    async def list_personal_rules(
        self,
        limit: int = 50,
        rule_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        pass

    async def list_plans(
        self,
        limit: int = 50,
        plan_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        pass

    async def list_plan_milestones(
        self,
        limit: int = 50,
        plan_id: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        pass

    async def list_commitments(
        self,
        limit: int = 50,
        commitment_type: Optional[str] = None,
        plan_id: Optional[str] = None,
        milestone_id: Optional[str] = None,
        entity_id: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        pass
