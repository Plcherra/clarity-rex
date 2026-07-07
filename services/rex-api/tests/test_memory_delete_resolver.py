import pytest

from app.services.memory_delete_resolver import (
    GOAL_DELETE_SCOPE,
    MemoryDeleteResolver,
    is_vague_delete_reference,
    parse_delete_request,
)


class FakeDeleteMemoryStore:
    def __init__(
        self,
        *,
        plans: list[dict] | None = None,
        milestones: list[dict] | None = None,
        memories: list[dict] | None = None,
    ) -> None:
        self.plans = plans or []
        self.milestones = milestones or []
        self.memories = memories or []

    async def list_plans(self, **kwargs):
        return self.plans

    async def list_plan_milestones(self, **kwargs):
        return self.milestones

    async def list_long_term_memory(self, **kwargs):
        return self.memories

    async def list_entities(self, **kwargs):
        return []

    async def list_entity_events(self, **kwargs):
        return []

    async def list_personal_rules(self, **kwargs):
        return []


def test_vague_delete_reference_detects_kind_only_targets():
    assert is_vague_delete_reference("goal")
    assert is_vague_delete_reference("a memory please")
    assert not is_vague_delete_reference("Wake at 5 AM")


def test_parse_delete_request_scopes_saved_goal_without_title():
    parsed = parse_delete_request("Can you delete the goal we have saved?")
    assert parsed is not None
    assert parsed.reference == "saved"
    assert parsed.scope_tables == GOAL_DELETE_SCOPE
    assert parsed.is_vague is False


def test_parse_delete_request_scopes_named_goal():
    parsed = parse_delete_request('Delete the goal "Buy RAM"')
    assert parsed is not None
    assert parsed.reference == "Buy RAM"
    assert parsed.scope_tables == GOAL_DELETE_SCOPE
    assert parsed.is_vague is False


@pytest.mark.asyncio
async def test_resolver_returns_empty_for_vague_goal_delete():
    store = FakeDeleteMemoryStore(
        plans=[
            {
                "id": "p-1",
                "title": "Buy RAM",
                "description": "Buy 32GB RAM",
                "active": True,
            }
        ],
        memories=[
            {
                "id": "m-1",
                "content": "goal reminder",
                "active": True,
            }
        ],
    )
    resolver = MemoryDeleteResolver(store)
    parsed = parse_delete_request("Delete the goal we have saved")
    assert parsed is not None

    matches = await resolver.resolve(parsed)
    assert matches == []


@pytest.mark.asyncio
async def test_resolver_scoped_goal_delete_skips_memory_tables():
    store = FakeDeleteMemoryStore(
        plans=[
            {
                "id": "p-1",
                "title": "Buy RAM",
                "description": "Buy 32GB RAM",
                "active": True,
            }
        ],
        memories=[
            {
                "id": "m-1",
                "content": "Buy RAM every month",
                "active": True,
            }
        ],
    )
    resolver = MemoryDeleteResolver(store)
    parsed = parse_delete_request('Delete the goal "Buy RAM"')
    assert parsed is not None

    matches = await resolver.resolve(parsed)
    assert len(matches) == 1
    assert matches[0].table == "plans"
    assert matches[0].id == "p-1"


@pytest.mark.asyncio
async def test_resolver_unscoped_delete_can_match_memory():
    store = FakeDeleteMemoryStore(
        memories=[
            {
                "id": "m-1",
                "content": "Mom birthday is June 18",
                "active": True,
            }
        ],
    )
    resolver = MemoryDeleteResolver(store)
    matches = await resolver.resolve("Mom birthday")
    assert len(matches) == 1
    assert matches[0].table == "long_term_memory"
    assert matches[0].id == "m-1"
