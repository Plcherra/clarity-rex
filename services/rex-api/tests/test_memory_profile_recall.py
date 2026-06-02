import pytest

from chat_service_fakes import FakeAIService, FakeMemoryService
from app.services.chat_context_service import PROFILE_MEMORY_QUERY
from app.services.chat_service import ChatService
from app.services.file_service import FileService
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
async def test_profile_context_includes_high_importance_birthdays():
    service = InMemoryProfileRecallService([_mom_birthday_memory()])

    memories = await service.get_relevant_memories(PROFILE_MEMORY_QUERY, limit=4)

    assert [memory["id"] for memory in memories] == ["memory-mom-birthday"]
    assert "birthday" in memories[0]["relevance_reason"]
    assert "profile" in memories[0]["relevance_reason"]


@pytest.mark.asyncio
async def test_profile_recall_does_not_include_archived_birthdays():
    service = InMemoryProfileRecallService(
        [_mom_birthday_memory(active=False)]
    )

    memories = await service.get_relevant_memories(
        "Do you remember my mom's birthday?",
        limit=3,
    )

    assert memories == []


@pytest.mark.asyncio
async def test_chat_prompt_includes_saved_mom_birthday_on_recall_question():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(_mom_birthday_memory())
    chat_service = ChatService(ai_service, FileService(), memory_service)

    await chat_service.send_message("Do you remember my mom's birthday?")

    system_content = ai_service.messages[0]["content"]
    assert "- fact: User's mom's birthday is June 18." in system_content
