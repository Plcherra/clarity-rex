"""Retrieval ranking for profile and person facts the user already saved.

Grok now asks for saved knowledge through capabilities instead of the backend
guessing when to dump memory into a prompt, so what stays testable here is the
ranking itself: the right saved fact comes back for the question, profile
context prefers high-importance identity facts, and archived rows never do.
"""

import pytest

from app.services.chat_context_service import PROFILE_MEMORY_QUERY
from app.services.memory_retrieval_service import MemoryRetrievalService
from app.services.memory_service import SupabaseMemoryService


class InMemoryProfileRecallService(SupabaseMemoryService):
    def __init__(self, memories):
        self.memories = memories

    async def list_long_term_memory(self, limit=50, memory_type=None, active=None):
        memories = self.memories
        if active is not None:
            memories = [memory for memory in memories if memory.get("active") is active]
        if memory_type is not None:
            memories = [
                memory
                for memory in memories
                if memory.get("memory_type") == memory_type
            ]
        return memories[:limit]


class InMemoryStructuredProfileStore:
    def __init__(self):
        self.entities = [
            {
                "id": "entity-self",
                "entity_type": "person",
                "display_name": "Pedro Martins",
                "normalized_name": "pedro martins",
                "relationship": "self",
                "summary": "Lives in Somerville.",
                "importance": 4,
                "status": "active",
                "active": True,
                "metadata": {"attributes": {"location": "Somerville"}},
                "updated_at": "2026-06-20T12:00:00Z",
            }
        ]

    async def list_long_term_memory(self, limit=100, active=True):
        return []

    async def list_entities(self, limit=50, active=True):
        return self.entities[:limit]

    async def list_entity_events(self, limit=50, active=True):
        return []

    async def list_personal_rules(self, limit=50, active=True):
        return []

    async def list_plans(self, limit=50, active=True):
        return []

    async def list_plan_milestones(self, limit=50, active=True):
        return []


def _mom_birthday_memory(**overrides):
    return {
        "id": "memory-mom-birthday",
        "memory_type": "fact",
        "content": "User's mom's birthday is June 18.",
        "importance": 5,
        "active": True,
        "metadata": {
            "fact_kind": "birthday",
            "entity_label": "mom",
            "normalized_date": "June 18",
            "topic_fingerprint": "fact:birthday:mom",
        },
        "created_at": "2026-06-01T12:00:00Z",
        "last_accessed_at": "2026-06-01T12:00:00Z",
        **overrides,
    }


@pytest.mark.asyncio
async def test_retrieves_mom_birthday_when_user_asks_directly():
    service = InMemoryProfileRecallService(
        [
            _mom_birthday_memory(),
            {
                "id": "memory-random",
                "memory_type": "fact",
                "content": "User once mentioned a random TV show.",
                "importance": 2,
                "active": True,
            },
        ]
    )

    memories = await service.get_relevant_memories(
        "Do you remember my mom's birthday?",
        limit=3,
    )

    assert [memory["id"] for memory in memories] == ["memory-mom-birthday"]
    assert "birthday" in memories[0]["relevance_reason"]


@pytest.mark.asyncio
async def test_retrieves_mom_memory_when_user_asks_anything_about_mom():
    service = InMemoryProfileRecallService(
        [
            _mom_birthday_memory(),
            {
                "id": "memory-random",
                "memory_type": "fact",
                "content": "User once mentioned a random TV show.",
                "importance": 2,
                "active": True,
            },
        ]
    )

    memories = await service.get_relevant_memories(
        "Do you know anything about my mom?",
        limit=3,
    )

    assert [memory["id"] for memory in memories] == ["memory-mom-birthday"]
    assert "mom" in memories[0]["relevance_reason"]


@pytest.mark.asyncio
async def test_profile_context_includes_high_importance_birthdays():
    service = InMemoryProfileRecallService([_mom_birthday_memory()])

    memories = await service.get_relevant_memories(PROFILE_MEMORY_QUERY, limit=4)

    assert [memory["id"] for memory in memories] == ["memory-mom-birthday"]
    assert "birthday" in memories[0]["relevance_reason"]
    assert "profile" in memories[0]["relevance_reason"]


@pytest.mark.asyncio
async def test_broad_inventory_recall_includes_self_profile_card():
    service = MemoryRetrievalService(InMemoryStructuredProfileStore())

    structured_context = await service.get_structured_memory_context(
        "What do you know?",
    )

    assert structured_context["entities"][0]["display_name"] == "Pedro Martins"
    assert structured_context["entities"][0]["relationship"] == "self"


@pytest.mark.asyncio
async def test_profile_recall_does_not_include_archived_birthdays():
    service = InMemoryProfileRecallService([_mom_birthday_memory(active=False)])

    memories = await service.get_relevant_memories(
        "Do you remember my mom's birthday?",
        limit=3,
    )

    assert memories == []
