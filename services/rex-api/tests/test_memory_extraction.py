import pytest

from test_memory_extraction_fakes import FakeExtractionAIService, FakeMemoryStore
from app.services.memory_extraction_service import (
    MEMORY_EXTRACTION_PROMPT,
    MemoryExtractionService,
)


@pytest.mark.asyncio
async def test_memory_extraction_saves_valid_candidates():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [
            {
              "memory_type": "preference",
              "content": "I prefer direct advice about career decisions.",
              "importance": 4,
              "rationale": "The user stated a recurring advice preference."
            }
          ]
        }
        """
    )
    memory_store = FakeMemoryStore()
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {
            "id": "message-1",
            "content": "Remember that I prefer direct advice about career decisions.",
        },
        {"id": "message-2", "content": "Got it."},
        brain_metadata={
            "source": "rex_brain",
            "decision": {"layer": "layer_1_contextual", "model_profile": "standard"},
        },
    )

    assert MEMORY_EXTRACTION_PROMPT in ai_service.messages[0]["content"]
    assert "structured_memories" in ai_service.messages[0]["content"]
    assert "Plan intelligence rules:" in ai_service.messages[0]["content"]
    assert "Entity normalization rules:" in ai_service.messages[0]["content"]
    assert "Memory Discipline rules:" in ai_service.messages[0]["content"]
    assert len(saved) == 1
    assert saved[0]["memory_type"] == "preference"
    assert saved[0]["candidate_type"] == "long_term_memory"
    assert saved[0]["extraction_kind"] == "memory_candidate"
    assert saved[0]["pending"] is True
    assert saved[0]["source_conversation_id"] == "conversation-1"
    assert saved[0]["source_message_id"] == "message-1"
    assert saved[0]["extraction_rationale"] == (
        "The user stated a recurring advice preference."
    )
    assert saved[0]["payload"]["metadata"]["rex_brain"] == {
        "source": "rex_brain",
        "decision": {"layer": "layer_1_contextual", "model_profile": "standard"},
    }
    assert memory_store.created_memory_candidates[0]["payload"]["metadata"][
        "rex_brain"
    ]["decision"]["layer"] == "layer_1_contextual"


@pytest.mark.asyncio
async def test_memory_extraction_parses_fenced_json_and_filters_noise():
    ai_service = FakeExtractionAIService(
        """
        ```json
        {
          "memories": [
            {
              "memory_type": "fact",
              "content": "I am waiting on my work visa renewal.",
              "importance": 5,
              "rationale": "Important immigration context."
            },
            {
              "memory_type": "fact",
              "content": "The user asked for advice.",
              "importance": 5,
              "rationale": "Noisy current-turn summary."
            },
            {
              "memory_type": "preference",
              "content": "I like tea.",
              "importance": 2,
              "rationale": "Low importance."
            }
          ]
        }
        ```
        """
    )
    memory_store = FakeMemoryStore()
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {"id": "message-1", "content": "My work visa renewal is stressing me out."},
        {"id": "message-2", "content": "That is important context."},
    )

    assert len(saved) == 1
    assert saved[0]["content"] == "I am waiting on my work visa renewal."


@pytest.mark.asyncio
async def test_memory_extraction_deduplicates_similar_existing_memories():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [
            {
              "memory_type": "fact",
              "content": "I work best in the morning.",
              "importance": 4,
              "rationale": "Recurring productivity context."
            }
          ]
        }
        """
    )
    memory_store = FakeMemoryStore(
        existing_memories=[
            {
                "id": "memory-existing",
                "memory_type": "fact",
                "content": "I work best during the morning.",
                "importance": 4,
                "active": True,
            }
        ]
    )
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {"id": "message-1", "content": "I work best in the morning."},
        {"id": "message-2", "content": "Makes sense."},
    )

    assert saved == []
    assert memory_store.saved_memories == []
    assert memory_store.relevant_queries[0]["query"] == "I work best in the morning."


@pytest.mark.asyncio
async def test_memory_extraction_accepts_top_level_list_response():
    ai_service = FakeExtractionAIService(
        """
        [
          {
            "memory_type": "event",
            "content": "I started a new job in May 2026.",
            "importance": 4,
            "rationale": "Important work timeline."
          }
        ]
        """
    )
    memory_store = FakeMemoryStore()
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {"id": "message-1", "content": "I started a new job in May 2026."},
        {"id": "message-2", "content": "That matters."},
    )

    assert len(saved) == 1
    assert saved[0]["memory_type"] == "event"


@pytest.mark.asyncio
async def test_memory_extraction_rejects_unreadable_json_safely():
    ai_service = FakeExtractionAIService("not json")
    memory_store = FakeMemoryStore()
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {"id": "message-1", "content": "Remember this."},
        {"id": "message-2", "content": "Okay."},
    )

    assert saved == []
    assert memory_store.saved_memories == []


@pytest.mark.asyncio
async def test_memory_extraction_deduplicates_and_links_structured_candidates():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [],
          "structured_memories": {
            "entities": [
              {
                "entity_type": "person",
                "display_name": "Clara from work",
                "relationship": "Dating interest",
                "summary": "Clara is someone the user knows from work.",
                "importance": 4,
                "rationale": "Named person."
              }
            ],
            "entity_events": [
              {
                "entity_name": "Clara",
                "event_type": "interaction",
                "title": "Lunch conversation",
                "content": "The user talked with Clara at lunch.",
                "importance": 4,
                "rationale": "Relevant relationship context."
              }
            ],
            "personal_rules": [
              {
                "rule_type": "food_delivery",
                "title": "No delivery",
                "rule_text": "No DoorDash this month.",
                "trigger_keywords": ["DoorDash", "Uber Eats"],
                "priority": 5,
                "rationale": "Budget rule."
              }
            ],
            "plans": [
              {
                "plan_type": "immigration",
                "title": "Move abroad",
                "desired_outcome": "Leave with enough runway.",
                "priority": 5,
                "rationale": "Major plan."
              }
            ],
            "plan_milestones": [
              {
                "plan_title": "Move abroad",
                "title": "Save $5k relocation runway",
                "milestone_type": "goal",
                "priority": 4,
                "rationale": "Progress marker."
              }
            ],
            "commitments": [
              {
                "commitment_type": "relationship",
                "title": "Text Clara",
                "commitment_text": "Text Clara tomorrow.",
                "entity_name": "Clara",
                "priority": 4,
                "rationale": "Direct commitment."
              }
            ]
          }
        }
        """
    )
    memory_store = FakeMemoryStore()
    memory_store.created_entities.append(
        {
            "id": "entity-existing",
            "entity_type": "person",
            "display_name": "Clara",
            "normalized_name": "clara",
            "aliases": ["Clara"],
            "importance": 3,
            "active": True,
            "metadata": {},
        }
    )
    memory_store.created_rules.append(
        {
            "id": "rule-existing",
            "rule_type": "food_delivery",
            "title": "No DoorDash",
            "rule_text": "No DoorDash this month.",
            "trigger_keywords": ["DoorDash"],
            "priority": 3,
            "active": True,
            "metadata": {},
        }
    )
    memory_store.created_plans.append(
        {
            "id": "plan-existing",
            "plan_type": "immigration",
            "title": "Move abroad",
            "priority": 3,
            "active": True,
            "metadata": {},
        }
    )
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {"id": "message-1", "content": "I need to text Clara tomorrow."},
        {"id": "message-2", "content": "I will track that."},
    )

    assert [item["structured_type"] for item in saved] == [
        "entity",
        "entity_event",
        "personal_rule",
        "plan",
        "plan_milestone",
        "commitment",
    ]
    assert len(memory_store.created_entities) == 1
    updated_entity = memory_store.created_entities[0]
    assert updated_entity["id"] == "entity-existing"
    assert updated_entity["display_name"] == "Clara from work"
    assert updated_entity["normalized_name"] == "clara from work"
    assert updated_entity["aliases"] == []
    assert updated_entity["importance"] == 4
    assert updated_entity["relationship"] == "Dating interest"
    assert updated_entity["summary"] == "Clara is someone the user knows from work."
    assert updated_entity["source_conversation_id"] == "conversation-1"
    assert updated_entity["source_message_id"] == "message-1"
    assert updated_entity["metadata"]["extraction_rationale"] == "Named person."
    assert memory_store.created_entity_events[0]["entity_id"] == "entity-existing"
    assert memory_store.created_rules[0]["id"] == "rule-existing"
    assert memory_store.created_rules[0]["trigger_keywords"] == [
        "DoorDash",
        "Uber Eats",
    ]
    assert memory_store.created_plans[0]["id"] == "plan-existing"
    assert memory_store.created_milestones[0]["plan_id"] == "plan-existing"
    assert memory_store.created_commitments[0]["entity_id"] == "entity-existing"


@pytest.mark.asyncio
async def test_memory_extraction_filters_low_value_structured_candidates():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [],
          "structured_memories": {
            "entities": [
              {
                "entity_type": "person",
                "display_name": "someone",
                "importance": 5,
                "rationale": "Too vague."
              },
              {
                "entity_type": "person",
                "display_name": "girl from work",
                "importance": 5,
                "rationale": "Descriptor without a name."
              },
              {
                "entity_type": "person",
                "display_name": "Clara",
                "importance": 2,
                "rationale": "Too low."
              }
            ],
            "personal_rules": [
              {
                "rule_type": "finance",
                "title": "Current request",
                "rule_text": "The user asked Rex to answer the current question.",
                "priority": 5,
                "rationale": "Noisy."
              }
            ]
          }
        }
        """
    )
    memory_store = FakeMemoryStore()
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {"id": "message-1", "content": "Can you answer this?"},
        {"id": "message-2", "content": "Yes."},
    )

    assert saved == []
    assert memory_store.created_entities == []
    assert memory_store.created_rules == []


@pytest.mark.asyncio
async def test_memory_extraction_ignores_invalid_structured_payloads_but_keeps_valid():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [],
          "structured_memories": {
            "entities": "not a list",
            "personal_rules": [
              {
                "rule_type": "finance",
                "title": "Current request",
                "rule_text": "The user asked Rex to answer the current question.",
                "priority": 5,
                "rationale": "Noisy current-turn instruction."
              },
              {
                "rule_type": "food_delivery",
                "title": "No DoorDash",
                "rule_text": "Do not order DoorDash this week.",
                "trigger_keywords": ["DoorDash", "delivery"],
                "priority": 4,
                "rationale": "Useful recurring budget rule."
              },
              {
                "rule_type": "random",
                "title": "Invalid",
                "rule_text": "This should not save.",
                "priority": 5,
                "rationale": "Invalid enum."
              }
            ],
            "plans": [
              "not an object",
              {
                "plan_type": "immigration",
                "title": "",
                "priority": 5,
                "rationale": "Missing title."
              }
            ]
          }
        }
        """
    )
    memory_store = FakeMemoryStore()
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {"id": "message-1", "content": "No DoorDash this week."},
        {"id": "message-2", "content": "I will hold you to that."},
    )

    assert [item["structured_type"] for item in saved] == ["personal_rule"]
    assert memory_store.created_rules == [
        {
            "id": "rule-1",
            "rule_type": "food_delivery",
            "title": "No DoorDash",
            "rule_text": "Do not order DoorDash this week.",
            "trigger_keywords": ["DoorDash", "delivery"],
            "enforcement_style": "gentle_direct",
            "source_conversation_id": "conversation-1",
            "source_message_id": "message-1",
            "priority": 4,
            "status": "active",
            "active": True,
            "metadata": {
                "extraction_rationale": "Useful recurring budget rule.",
                "memory_path": "pending_review",
                "review_required": True,
                "decision_reason": (
                    "Structured memory needs review before changing saved records."
                ),
                "candidate_type": "personal_rule",
                "risk_level": "medium",
                "review_reason": (
                    "Structured memory needs review before changing saved records."
                ),
                "review_rationale": "Useful recurring budget rule.",
            },
        }
    ]
    assert memory_store.created_entities == []
    assert memory_store.created_plans == []
