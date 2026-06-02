import pytest

from test_memory_extraction_fakes import FakeExtractionAIService, FakeMemoryStore
from app.services.memory_extraction_service import (
    MEMORY_EXTRACTION_PROMPT,
    MemoryExtractionService,
)


@pytest.mark.asyncio
async def test_memory_extraction_saves_corrected_person_name_as_current_truth():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [
            {
              "memory_type": "fact",
              "content": "The woman I am planning a date with is named Melissa, not Al.",
              "importance": 4,
              "rationale": "The user corrected a stale person name."
            }
          ],
          "structured_memories": {
            "entities": [
              {
                "entity_type": "person",
                "display_name": "Melissa",
                "relationship": "Dating interest from work",
                "summary": "Melissa is the woman the user is planning to ask out.",
                "importance": 4,
                "rationale": "Corrected named person in recurring dating context."
              }
            ],
            "entity_events": [
              {
                "entity_name": "Melissa",
                "event_type": "relationship_update",
                "title": "Corrected name",
                "content": "The prior name Al was wrong; the correct name is Melissa.",
                "importance": 4,
                "rationale": "Prevents stale memory from using the wrong name."
              }
            ]
          }
        }
        """
    )
    memory_store = FakeMemoryStore(
        existing_memories=[
            {
                "id": "memory-existing",
                "memory_type": "event",
                "content": "I am planning to ask Al out for dinner Monday.",
                "importance": 3,
                "active": True,
            }
        ]
    )
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {
            "id": "message-1",
            "content": "Her name is not Al. Her name is Melissa.",
        },
        {"id": "message-2", "content": "Got it, Melissa."},
    )

    assert "correction" in MEMORY_EXTRACTION_PROMPT.lower()
    assert [item["extraction_kind"] for item in saved] == [
        "memory_candidate",
        "memory_candidate",
        "memory_candidate",
    ]
    assert memory_store.saved_memories == []
    assert memory_store.updated_memories == []
    assert memory_store.created_memory_corrections == []
    assert saved[0]["candidate_type"] == "long_term_memory"
    assert saved[0]["payload"]["content"] == (
        "The woman I am planning a date with is named Melissa, not Al."
    )
    assert saved[0]["risk_level"] == "medium"
    assert memory_store.created_entities[0]["display_name"] == "Melissa"
    assert memory_store.created_entities[0]["normalized_name"] == "melissa"


@pytest.mark.asyncio
async def test_memory_extraction_updates_stale_memory_when_correction_matches():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [
            {
              "memory_type": "fact",
              "content": "The person for the next-week date plan is Melissa, corrected from Al or AI.",
              "importance": 4,
              "rationale": "The user corrected the stale date-plan name."
            }
          ],
          "structured_memories": {}
        }
        """
    )
    memory_store = FakeMemoryStore(
        existing_memories=[
            {
                "id": "memory-stale",
                "memory_type": "event",
                "content": "I am planning to confidently ask Al out for dinner on her off day Monday at a restaurant near my house",
                "importance": 3,
                "active": True,
            }
        ]
    )
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {
            "id": "message-1",
            "content": "Change the Al memory to Melissa.",
        },
        {"id": "message-2", "content": "Saved."},
    )

    assert memory_store.saved_memories == []
    assert memory_store.updated_memories == []
    assert memory_store.created_memory_corrections == []
    assert saved[0]["candidate_type"] == "long_term_memory"
    assert saved[0]["payload"]["memory_type"] == "fact"
    assert saved[0]["payload"]["importance"] == 4
    assert saved[0]["payload"]["content"] == (
        "The person for the next-week date plan is Melissa, corrected from Al or AI."
    )
    assert saved[0]["extraction_action"] == "candidate_created"


@pytest.mark.asyncio
async def test_memory_extraction_creates_person_context_for_unstructured_correction():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [
            {
              "memory_type": "fact",
              "content": "The person for the next-week date plan is Melissa, not Al.",
              "importance": 4,
              "rationale": "The user corrected the stale person name."
            }
          ],
          "structured_memories": {}
        }
        """
    )
    memory_store = FakeMemoryStore(
        existing_memories=[
            {
                "id": "memory-existing",
                "memory_type": "event",
                "content": "I am planning to ask Al out for dinner Monday.",
                "importance": 3,
                "active": True,
            }
        ]
    )
    memory_store.created_plans.append(
        {
            "id": "plan-existing",
            "plan_type": "dating",
            "title": "Ask Al out for dinner",
            "description": "Dinner with Al on Monday near my house.",
            "desired_outcome": "Successful date with Al.",
            "priority": 4,
            "status": "active",
            "active": True,
            "metadata": {},
        }
    )
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {"id": "message-1", "content": "Her name is not Al. It is Melissa."},
        {"id": "message-2", "content": "Got it."},
    )

    assert [item["extraction_kind"] for item in saved] == ["memory_candidate"]
    assert memory_store.updated_memories == []
    assert saved[0]["payload"]["content"] == (
        "The person for the next-week date plan is Melissa, not Al."
    )
    assert len(memory_store.created_plans) == 1
    assert memory_store.created_plans[0]["title"] == "Ask Al out for dinner"


@pytest.mark.asyncio
async def test_memory_extraction_uses_user_message_to_apply_correction():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [
            {
              "memory_type": "fact",
              "content": "The person for the next-week date plan is Melissa.",
              "importance": 4,
              "rationale": "The user corrected the stale date-plan name."
            }
          ],
          "structured_memories": {}
        }
        """
    )
    memory_store = FakeMemoryStore(
        existing_memories=[
            {
                "id": "memory-stale",
                "memory_type": "event",
                "content": "I am planning to ask Al out for dinner Monday.",
                "importance": 3,
                "active": True,
            }
        ]
    )
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {
            "id": "message-1",
            "content": "Change the Al memory to Melissa.",
        },
        {"id": "message-2", "content": "Saved."},
    )

    assert memory_store.saved_memories == []
    assert memory_store.updated_memories == []
    assert saved[0]["payload"]["content"] == (
        "The person for the next-week date plan is Melissa."
    )
    assert memory_store.created_memory_corrections == []
    assert saved[0]["extraction_action"] == "candidate_created"


@pytest.mark.asyncio
async def test_memory_extraction_updates_stale_location_correction():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [
            {
              "memory_type": "fact",
              "content": "I live in Massachusetts.",
              "importance": 4,
              "rationale": "The user corrected their location."
            }
          ],
          "structured_memories": {}
        }
        """
    )
    memory_store = FakeMemoryStore(
        existing_memories=[
            {
                "id": "memory-location",
                "memory_type": "fact",
                "content": "I live in Europe.",
                "importance": 3,
                "active": True,
            }
        ]
    )
    service = MemoryExtractionService(ai_service, memory_store)

    await service.extract_and_save(
        "conversation-1",
        {
            "id": "message-1",
            "content": "I live in Massachusetts, not Europe.",
        },
        {"id": "message-2", "content": "Got it."},
    )

    assert memory_store.saved_memories == []
    assert memory_store.updated_memories == []
    assert memory_store.created_memory_corrections == []
    assert memory_store.created_memory_candidates[0]["payload"]["content"] == (
        "I live in Massachusetts."
    )


@pytest.mark.asyncio
async def test_memory_extraction_updates_stale_plan_detail_correction():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [
            {
              "memory_type": "event",
              "content": "The dinner plan is at Cafe Luna, not downtown.",
              "importance": 4,
              "rationale": "The user corrected the plan location."
            }
          ],
          "structured_memories": {}
        }
        """
    )
    memory_store = FakeMemoryStore(
        existing_memories=[
            {
                "id": "memory-plan",
                "memory_type": "event",
                "content": "The dinner plan is downtown on Monday.",
                "importance": 3,
                "active": True,
            }
        ]
    )
    service = MemoryExtractionService(ai_service, memory_store)

    await service.extract_and_save(
        "conversation-1",
        {
            "id": "message-1",
            "content": "The dinner plan is at Cafe Luna, not downtown.",
        },
        {"id": "message-2", "content": "Updated."},
    )

    assert memory_store.saved_memories == []
    assert memory_store.updated_memories == []
    assert memory_store.created_memory_corrections == []
    assert memory_store.created_memory_candidates[0]["payload"]["content"] == (
        "The dinner plan is at Cafe Luna, not downtown."
    )


@pytest.mark.asyncio
async def test_memory_extraction_deactivates_extra_stale_correction_matches():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [
            {
              "memory_type": "fact",
              "content": "The woman I am planning a date with is named Melissa, not Al.",
              "importance": 4,
              "rationale": "The user corrected the stale date-plan name."
            }
          ],
          "structured_memories": {}
        }
        """
    )
    memory_store = FakeMemoryStore(
        existing_memories=[
            {
                "id": "memory-stale-1",
                "memory_type": "event",
                "content": "I am planning to ask Al out for dinner Monday.",
                "importance": 3,
                "active": True,
            },
            {
                "id": "memory-stale-2",
                "memory_type": "event",
                "content": "Al has Monday off and I plan to ask her out.",
                "importance": 3,
                "active": True,
            },
        ]
    )
    service = MemoryExtractionService(ai_service, memory_store)

    await service.extract_and_save(
        "conversation-1",
        {
            "id": "message-1",
            "content": "Her name is not Al. It is Melissa.",
        },
        {"id": "message-2", "content": "Saved."},
    )

    assert memory_store.updated_memories == []
    assert memory_store.deactivated_memory_ids == []
    assert memory_store.created_memory_corrections == []
    assert memory_store.created_memory_candidates[0]["payload"]["content"] == (
        "The woman I am planning a date with is named Melissa, not Al."
    )
