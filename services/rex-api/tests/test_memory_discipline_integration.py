import pytest

from app.models.entity import EntityCreateRequest
from app.models.memory_discipline import MemoryRecordKind
from app.models.personal_rule import PersonalRuleCreateRequest
from app.services.entity_service import EntityService
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_discipline_writes import execute_disciplined_create
from app.services.rule_service import RuleService


class DisciplineMemoryStore:
    def __init__(self):
        self.entities = []
        self.rules = []
        self.memories = []
        self.plans = []

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
        rows = self.plans
        if plan_type is not None:
            rows = [row for row in rows if row.get("plan_type") == plan_type]
        if active is not None:
            rows = [row for row in rows if row.get("active") is active]
        return rows[:limit]

    async def list_plan_milestones(
        self,
        plan_id=None,
        status=None,
        active=True,
        limit=50,
    ):
        return []

    async def save_long_term_memory(
        self,
        memory_type,
        content,
        source_conversation_id=None,
        source_message_id=None,
        importance=3,
        metadata=None,
    ):
        row = {
            "id": f"memory-{len(self.memories) + 1}",
            "memory_type": memory_type,
            "content": content,
            "importance": importance,
            "metadata": metadata or {},
            "active": True,
        }
        self.memories.append(row)
        return row

    async def update_long_term_memory(self, memory_id, **updates):
        for row in self.memories:
            if row["id"] == memory_id:
                row.update(updates)
                return row
        return None


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
            metadata={"allow_auto_merge": True},
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


@pytest.mark.asyncio
async def test_long_term_memory_create_bypasses_generic_confirmation_gate():
    store = DisciplineMemoryStore()
    discipline = MemoryDisciplineService(store)
    payload = {
        "memory_type": "fact",
        "content": "User's mom's birthday is June 18.",
        "importance": 4,
        "metadata": {"fact_kind": "birthday", "entity_label": "mom"},
    }

    async def create_fn(item):
        return await store.save_long_term_memory(
            memory_type=str(item["memory_type"]),
            content=str(item["content"]),
            importance=int(item.get("importance") or 3),
            metadata=dict(item.get("metadata") or {}),
        )

    record = await execute_disciplined_create(
        discipline,
        kind=MemoryRecordKind.LONG_TERM_MEMORY,
        payload=payload,
        create_fn=create_fn,
    )

    assert record["id"] == "memory-1"
    assert len(store.memories) == 1


@pytest.mark.asyncio
async def test_explicit_goal_command_bypasses_plan_intelligence_confirmation():
    store = DisciplineMemoryStore()
    discipline = MemoryDisciplineService(store)
    payload = {
        "plan_type": "personal",
        "title": "Get 32GB RAM",
        "description": "Get 32gb-64gb ram",
        "desired_outcome": "Get 32gb-64gb ram",
        "target_date": "July 31",
        "priority": 4,
        "metadata": {
            "source": "explicit_goal_command",
            "prevent_related_merge": True,
            "discipline_write_channel": "confirmed_plan_service",
        },
    }

    async def create_fn(item):
        row = {"id": f"plan-{len(store.plans) + 1}", **item}
        store.plans.append(row)
        return row

    record = await execute_disciplined_create(
        discipline,
        kind=MemoryRecordKind.PLAN,
        payload=payload,
        create_fn=create_fn,
    )

    assert record["id"] == "plan-1"
    assert len(store.plans) == 1
