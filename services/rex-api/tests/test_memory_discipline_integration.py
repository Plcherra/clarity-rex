import pytest

from app.models.entity import EntityCreateRequest
from app.models.personal_rule import PersonalRuleCreateRequest
from app.services.entity_service import EntityService
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.rule_service import RuleService


class DisciplineMemoryStore:
    def __init__(self):
        self.entities = []
        self.rules = []
        self.memories = []

    async def create_entity(self, payload):
        row = {"id": f"entity-{len(self.entities) + 1}", **payload}
        self.entities.append(row)
        return row

    async def list_entities(
        self,
        entity_type=None,
        normalized_name=None,
        status=None,
        active=True,
        limit=50,
    ):
        rows = self.entities
        if entity_type is not None:
            rows = [row for row in rows if row.get("entity_type") == entity_type]
        if normalized_name is not None:
            rows = [
                row for row in rows if row.get("normalized_name") == normalized_name
            ]
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        if active is not None:
            rows = [row for row in rows if row.get("active") is active]
        return rows[:limit]

    async def update_entity(self, entity_id, **updates):
        for row in self.entities:
            if row["id"] == entity_id:
                row.update(updates)
                return row
        return None

    async def create_personal_rule(self, payload):
        row = {"id": f"rule-{len(self.rules) + 1}", **payload}
        self.rules.append(row)
        return row

    async def list_personal_rules(
        self,
        rule_type=None,
        status=None,
        active=True,
        limit=50,
    ):
        rows = self.rules
        if rule_type is not None:
            rows = [row for row in rows if row.get("rule_type") == rule_type]
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        if active is not None:
            rows = [row for row in rows if row.get("active") is active]
        return rows[:limit]

    async def update_personal_rule(self, rule_id, **updates):
        for row in self.rules:
            if row["id"] == rule_id:
                row.update(updates)
                return row
        return None

    async def list_long_term_memory(self, limit=50, memory_type=None, active=None):
        rows = self.memories
        if memory_type is not None:
            rows = [row for row in rows if row.get("memory_type") == memory_type]
        if active is not None:
            rows = [row for row in rows if row.get("active") is active]
        return rows[:limit]

    async def list_plans(self, plan_type=None, status=None, active=True, limit=50):
        return []

    async def list_plan_milestones(
        self,
        plan_id=None,
        status=None,
        active=True,
        limit=50,
    ):
        return []

    async def list_commitments(
        self,
        commitment_type=None,
        status=None,
        active=True,
        limit=50,
    ):
        return []


@pytest.mark.asyncio
async def test_duplicate_person_create_merges_instead_of_duplicating():
    store = DisciplineMemoryStore()
    discipline = MemoryDisciplineService(store)
    service = EntityService(store, discipline=discipline)

    first = await service.create_entity(
        EntityCreateRequest(
            entity_type="person",
            display_name="Clara",
            normalized_name="clara",
            relationship="friend",
        )
    )
    second = await service.create_entity(
        EntityCreateRequest(
            entity_type="person",
            display_name="Clara",
            normalized_name="clara",
            summary="Works downtown.",
        )
    )

    assert second["id"] == first["id"]
    assert len(store.entities) == 1
    assert "Works downtown." in (second.get("summary") or "")


@pytest.mark.asyncio
async def test_duplicate_rule_create_updates_existing_record():
    store = DisciplineMemoryStore()
    discipline = MemoryDisciplineService(store)
    service = RuleService(store, discipline=discipline)

    first = await service.create_rule(
        PersonalRuleCreateRequest(
            rule_type="personal",
            title="Be concise",
            rule_text="Keep advice direct.",
        )
    )
    second = await service.create_rule(
        PersonalRuleCreateRequest(
            rule_type="personal",
            title="Be concise",
            rule_text="Keep advice direct unless asked for depth.",
            priority=4,
        )
    )

    assert second["id"] == first["id"]
    assert len(store.rules) == 1
    assert second["rule_text"] == "Keep advice direct unless asked for depth."
    assert second["priority"] == 4
