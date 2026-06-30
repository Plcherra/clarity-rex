import pytest

from app.services.entity_service import EntityService
from app.services.memory_retrieval_service import MemoryRetrievalService
from app.services.person_memory_materializer import PersonMemoryMaterializer
from tests.test_memory_retrieval import InMemoryRetrievalService


@pytest.mark.asyncio
async def test_structured_context_read_path_does_not_materialize_flat_memories():
    store = InMemoryRetrievalService(
        [
            {
                "id": "memory-ana-birthday",
                "memory_type": "fact",
                "content": "User's cousin ana's birthday is July 9.",
                "importance": 5,
                "active": True,
                "metadata": {
                    "fact_kind": "birthday",
                    "memory_category": "Events",
                    "entity_label": "cousin ana",
                    "normalized_date": "July 9",
                },
            },
        ]
    )
    retrieval = MemoryRetrievalService(store)

    context = await retrieval.get_structured_memory_context(
        "What does Clarity know about cousin Ana?"
    )

    assert store.entities == []
    assert context["entities"] == []
    assert store.memories[0]["active"] is True


@pytest.mark.asyncio
async def test_entity_list_read_path_does_not_materialize_flat_memories():
    memory_service = _EntityListMemoryService(
        memories=[
            {
                "id": "memory-ana-birthday",
                "memory_type": "fact",
                "content": "User's cousin ana's birthday is July 9.",
                "importance": 5,
                "active": True,
                "metadata": {"fact_kind": "birthday", "entity_label": "cousin ana"},
            },
        ]
    )
    service = EntityService(memory_service)

    entities = await service.list_entities(entity_type="person")

    assert entities == []
    assert memory_service.entities == []


@pytest.mark.asyncio
async def test_save_path_materializer_still_builds_person_cards():
    store = InMemoryRetrievalService(
        [
            {
                "id": "memory-ana-birthday",
                "memory_type": "fact",
                "content": "User's cousin ana's birthday is July 9.",
                "importance": 5,
                "active": True,
                "metadata": {
                    "fact_kind": "birthday",
                    "memory_category": "Events",
                    "entity_label": "cousin ana",
                    "normalized_date": "July 9",
                    "topic_fingerprint": "fact:birthday:cousin ana",
                },
            },
        ]
    )
    materializer = PersonMemoryMaterializer()
    await materializer.materialize_from_active_memories(store)

    assert len(store.entities) == 1
    assert store.memories[0]["active"] is False

    retrieval = MemoryRetrievalService(store)
    context = await retrieval.get_structured_memory_context(
        "What does Clarity know about cousin Ana?"
    )

    assert context["entities"][0]["display_name"] == "Cousin Ana"


class _EntityListMemoryService:
    def __init__(self, memories):
        self.memories = memories
        self.entities = []

    async def list_entities(self, **kwargs):
        return self.entities[: kwargs.get("limit", 50)]

    async def create_entity(self, payload):
        row = {"id": f"entity-{len(self.entities) + 1}", **payload}
        self.entities.append(row)
        return row

    async def update_entity(self, entity_id, **updates):
        for row in self.entities:
            if row["id"] == entity_id:
                row.update(updates)
                return row
        return None

    async def list_long_term_memory(self, **kwargs):
        return self.memories

    async def update_long_term_memory(self, memory_id, **updates):
        for memory in self.memories:
            if memory["id"] == memory_id:
                memory.update(updates)
                return memory
        return None

    async def deactivate_long_term_memory(self, memory_id):
        return await self.update_long_term_memory(memory_id, active=False)
