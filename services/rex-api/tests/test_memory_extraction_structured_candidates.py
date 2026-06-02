import pytest

from test_memory_extraction_fakes import FakeExtractionAIService, FakeMemoryStore
from app.services.memory_extraction_service import MemoryExtractionService


@pytest.mark.asyncio
async def test_memory_extraction_saves_structured_candidates():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [],
          "structured_memories": {
            "entities": [
              {
                "id": "entity-1",
                "entity_type": "person",
                "display_name": "Clara",
                "aliases": ["Clara from work", "Clara from work"],
                "relationship": "Dating interest",
                "summary": "Clara is someone from work the user is interested in.",
                "importance": 4,
                "rationale": "Named person in recurring dating context."
              }
            ],
            "entity_events": [
              {
                "entity_id": "entity-1",
                "event_type": "interaction",
                "title": "Touched arm",
                "content": "Clara touched the user's arm at work.",
                "importance": 4,
                "rationale": "Relevant dating interaction."
              }
            ],
            "personal_rules": [
              {
                "rule_type": "food_delivery",
                "title": "No DoorDash",
                "rule_text": "Avoid DoorDash while the budget is slipping.",
                "trigger_keywords": ["DoorDash"],
                "priority": 5,
                "rationale": "Recurring money rule."
              }
            ],
            "plans": [
              {
                "id": "plan-1",
                "plan_type": "immigration",
                "title": "Move abroad",
                "desired_outcome": "Leave with enough financial runway.",
                "priority": 5,
                "rationale": "Major long-term life plan."
              }
            ],
            "plan_milestones": [
              {
                "plan_id": "plan-1",
                "title": "Save $5k relocation runway",
                "milestone_type": "goal",
                "priority": 4,
                "rationale": "Concrete progress marker."
              }
            ],
            "commitments": [
              {
                "commitment_type": "health",
                "title": "Morning workout",
                "commitment_text": "Work out tomorrow morning.",
                "due_at": "2026-05-18T12:00:00Z",
                "priority": 4,
                "rationale": "The user made a direct commitment."
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
        {
            "id": "message-1",
            "content": "Clara from work touched my arm. Also no DoorDash. I will work out tomorrow.",
        },
        {"id": "message-2", "content": "That is worth tracking."},
    )

    assert [item["structured_type"] for item in saved] == [
        "entity",
        "entity_event",
        "personal_rule",
        "plan",
        "plan_milestone",
        "commitment",
    ]
    assert memory_store.created_entities[0]["display_name"] == "Clara"
    assert memory_store.created_entities[0]["normalized_name"] == "clara"
    assert memory_store.created_entities[0]["aliases"] == ["Clara from work"]
    assert memory_store.created_entities[0]["source_conversation_id"] == (
        "conversation-1"
    )
    assert memory_store.created_rules[0]["rule_type"] == "food_delivery"
    assert memory_store.created_plans[0]["plan_type"] == "immigration"
    assert memory_store.created_entity_events[0]["entity_id"] == "entity-1"
    assert memory_store.created_milestones[0]["plan_id"] == "plan-1"
    assert memory_store.created_commitments[0]["due_at"] == "2026-05-18T12:00:00Z"


@pytest.mark.asyncio
async def test_memory_extraction_preserves_person_descriptor_aliases():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [],
          "structured_memories": {
            "entities": [
              {
                "entity_type": "person",
                "display_name": "Melissa",
                "relationship": "Girl from work",
                "summary": "Melissa is the coworker involved in the next-week date plan.",
                "importance": 4,
                "rationale": "Named person in recurring dating context."
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
        {
            "id": "message-1",
            "content": "Her name is Melissa. She is the girl from work.",
        },
        {"id": "message-2", "content": "I will remember Melissa."},
    )

    assert [item["structured_type"] for item in saved] == ["entity"]
    assert memory_store.created_entities[0]["display_name"] == "Melissa"
    assert memory_store.created_entities[0]["normalized_name"] == "melissa"
    assert memory_store.created_entities[0]["aliases"] == []


@pytest.mark.asyncio
async def test_memory_extraction_links_plan_to_named_person_entity():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [],
          "structured_memories": {
            "entities": [
              {
                "id": "entity-melissa",
                "entity_type": "person",
                "display_name": "Melissa",
                "relationship": "Dating interest",
                "importance": 4,
                "rationale": "Named person."
              }
            ],
            "plans": [
              {
                "plan_type": "dating",
                "title": "Ask Melissa out for dinner",
                "description": "Plan dinner with Melissa next Monday.",
                "desired_outcome": "Successful date with Melissa.",
                "entity_name": "Melissa",
                "priority": 4,
                "rationale": "Dating plan tied to a person."
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
        {
            "id": "message-1",
            "content": "I want to ask Melissa out for dinner next Monday.",
        },
        {"id": "message-2", "content": "Let's make the plan concrete."},
    )

    assert [item["structured_type"] for item in saved] == ["entity", "plan"]
    assert memory_store.created_plans[0]["primary_entity_id"] == "entity-1"
    assert memory_store.created_plans[0]["title"] == "Ask Melissa out for dinner"


@pytest.mark.asyncio
async def test_memory_extraction_routes_related_plan_to_existing_plan_milestone():
    ai_service = FakeExtractionAIService(
        """
        {
          "memories": [],
          "structured_memories": {
            "plans": [
              {
                "plan_type": "finance",
                "title": "$5k monthly revenue target",
                "description": "Reach $5k monthly revenue from EchoDesk and FlowForce.",
                "desired_outcome": "Location-independent income for the Europe move.",
                "priority": 5,
                "rationale": "Income target belongs under the larger relocation goal."
              }
            ]
          }
        }
        """
    )
    memory_store = FakeMemoryStore()
    memory_store.created_plans.append(
        {
            "id": "plan-europe",
            "plan_type": "personal",
            "title": "Relocate to Europe next year",
            "description": "Move to Europe with stable location-independent income.",
            "desired_outcome": "Living in Europe sustainably.",
            "priority": 5,
            "status": "active",
            "active": True,
            "metadata": {},
        }
    )
    service = MemoryExtractionService(ai_service, memory_store)

    saved = await service.extract_and_save(
        "conversation-1",
        {"id": "message-1", "content": "I need $5k/month before Europe."},
        {"id": "message-2", "content": "That belongs under your Europe plan."},
    )

    assert [item["structured_type"] for item in saved] == ["plan_milestone"]
    assert len(memory_store.created_plans) == 1
    assert memory_store.created_milestones[0]["plan_id"] == "plan-europe"
    assert memory_store.created_milestones[0]["title"] == "$5k monthly revenue target"
    assert saved[0]["extraction_action"] == "candidate_created"
    assert saved[0]["payload"]["memory_discipline"]["action"] == "create_milestone"
