import pytest

from app.services.memory_reference_resolver import MemoryReferenceResolver


class FakeReferenceStore:
    def __init__(self):
        self.entities = [
            {
                "id": "entity-1",
                "display_name": "Mom",
                "normalized_name": "mom",
                "aliases": ["mother"],
            }
        ]
        self.plans = [
            {
                "id": "plan-1",
                "title": "Mom birthday plan",
                "description": "Send something thoughtful",
            }
        ]

    async def list_entities(self, active=True, limit=100):
        return self.entities

    async def list_plans(self, active=True, limit=100):
        return self.plans


@pytest.mark.asyncio
async def test_memory_reference_resolver_loads_and_resolves_entity_key():
    resolver = MemoryReferenceResolver(FakeReferenceStore())
    keys = {}
    await resolver.load_existing_entity_keys(keys)
    candidate = {"entity_name": "mother"}

    await resolver.resolve_entity_reference(candidate, keys)

    assert keys["mom"] == "entity-1"
    assert keys["mother"] == "entity-1"
    assert candidate["entity_id"] == "entity-1"


@pytest.mark.asyncio
async def test_memory_reference_resolver_finds_entity_when_key_cache_misses():
    resolver = MemoryReferenceResolver(FakeReferenceStore())
    candidate = {"entity_name": "Mom"}
    keys = {}

    await resolver.resolve_entity_reference(candidate, keys)

    assert candidate["entity_id"] == "entity-1"
    assert keys["mom"] == "entity-1"


@pytest.mark.asyncio
async def test_memory_reference_resolver_resolves_plan_title():
    resolver = MemoryReferenceResolver(FakeReferenceStore())
    keys = {}
    await resolver.load_existing_plan_keys(keys)
    candidate = {"plan_title": "Mom birthday plan"}

    await resolver.resolve_plan_reference(candidate, keys)

    assert candidate["plan_id"] == "plan-1"
