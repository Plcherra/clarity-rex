import pytest

from app.services.memory_reference_resolver import MemoryReferenceResolver


class FakeReferenceStore:
    def __init__(self):
        self.memories = [
            {
                "id": "memory-event",
                "memory_type": "event",
                "content": "User plans to watch it tonight.",
                "active": True,
                "metadata": {"fact_kind": "personal_plan"},
            }
        ]
        self.entities = [
            {
                "id": "entity-1",
                "display_name": "Mom",
                "normalized_name": "mom",
                "aliases": ["mother"],
            }
        ]
        self.entity_events = [
            {
                "id": "entity-event-1",
                "title": "Mom birthday note",
                "content": "Mom's birthday is June 18.",
                "active": True,
            }
        ]
        self.plans = [
            {
                "id": "plan-1",
                "title": "Mom birthday plan",
                "description": "Send something thoughtful",
            }
        ]

    async def list_long_term_memory(self, active=True, limit=100):
        memories = self.memories
        if active is not None:
            memories = [memory for memory in memories if memory.get("active", True) is active]
        return memories[:limit]

    async def list_entities(self, active=True, limit=100):
        return self.entities

    async def list_entity_events(self, active=True, limit=100):
        events = self.entity_events
        if active is not None:
            events = [event for event in events if event.get("active", True) is active]
        return events[:limit]

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


@pytest.mark.asyncio
async def test_memory_reference_resolver_resolves_single_visible_event_category():
    resolver = MemoryReferenceResolver(FakeReferenceStore())

    matches = await resolver.resolve_knows_delete_reference("event")

    assert len(matches) == 2
    assert {match.table for match in matches} == {
        "long_term_memory",
        "entity_events",
    }


@pytest.mark.asyncio
async def test_memory_reference_resolver_matches_visible_person_attribute():
    store = FakeReferenceStore()
    store.entities = [
        {
            "id": "entity-self",
            "entity_type": "person",
            "display_name": "Pedro Martins",
            "normalized_name": "pedro martins",
            "relationship": "self",
            "summary": "Lives in Somerville.",
            "aliases": [],
            "active": True,
            "metadata": {
                "attributes": {"location": "Somerville"},
                "attribute_source_memory_ids": {"location": ["memory-location"]},
            },
        }
    ]
    resolver = MemoryReferenceResolver(store)

    matches = await resolver.resolve_knows_delete_reference("Location: Somerville")

    assert len(matches) == 1
    assert matches[0].table == "entities"
    assert matches[0].action == "would_remove_attribute"
    assert matches[0].attribute_key == "location"
    assert matches[0].source_memory_ids == ("memory-location",)
