"""A confirmed person save has to be visible in Knows, with what was confirmed.

Rex offers "Save person card for your mother (Ariadyna)" and then says "Saved to
Clarity Knows". The Truth Rule makes both halves binding: an `entities` person
card must exist afterwards, and every detail on the confirm card must survive on
it — the body cannot quietly downgrade the save to a flat note or drop a field.
"""

from __future__ import annotations

import pytest

from app.services.capabilities.memory_action_payload import (
    simple_memory_intent_from_payload,
)
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.person_card_builder import PersonCardBuilder
from chat_memory_brain_support import scripted_turns, seed_flat_memory
from chat_service_fakes import FakeMemoryService
from durable_write_test_helpers import confirm_durable_write
from memory_persist_assertions import assert_person_card_covers
from scripted_brain_fakes import ScriptedAIService, reply_with_action

# No importance: Grok is not required to volunteer one for a person save.
PERSON_BRAIN = {
    "my mom is ariadyna": reply_with_action(
        "I can save Ariadyna as your mom.",
        "save_person",
        {
            "display_name": "Ariadyna",
            "relationship": "mom",
            "birthday": "June 18",
        },
    ),
}


def _chat_service(memory_service: FakeMemoryService) -> ChatService:
    return ChatService(
        ScriptedAIService(PERSON_BRAIN),
        FileService(),
        memory_service,
    )


@pytest.mark.asyncio
async def test_confirmed_person_save_reaches_knows_without_a_stated_importance():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom is Ariadyna")
    saved = await confirm_durable_write(chat_service, proposed)

    assert saved["memory_changes"]["created"] == 1
    assert_person_card_covers(
        memory_service,
        relationship="mother",
        display_name_contains="Ariadyna",
    )


@pytest.mark.asyncio
async def test_confirmed_birthday_survives_on_the_person_card():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom is Ariadyna")
    assert proposed["memory_changes"]["write_proposals"][0]["person_card"][
        "birthday"
    ] == "June 18"

    await confirm_durable_write(chat_service, proposed)

    card = assert_person_card_covers(
        memory_service,
        relationship="mother",
        attribute_contains={"birthday": "June 18"},
    )
    assert "June 18" in card["summary"]


@pytest.mark.asyncio
async def test_correcting_a_fact_keeps_the_importance_that_holds_its_card():
    turns = scripted_turns(
        {
            "moved to boston": reply_with_action(
                "Boston it is.",
                "update_memory",
                {
                    "memory_id": "memory-city",
                    "content": "User lives in Boston.",
                    "previous_content": "User lives in Somervile.",
                },
            )
        }
    )
    seed_flat_memory(
        turns.store,
        memory_id="memory-city",
        content="User lives in Somervile.",
        importance=5,
    )

    proposed = await turns.chat.send_message("I moved to Boston")
    await confirm_durable_write(turns.chat, proposed)

    # The correction kept importance 5, so the fact still carries the self card
    # instead of being demoted into an invisible flat note.
    assert_person_card_covers(
        turns.store,
        relationship="self",
        attribute_contains={"location": "Boston"},
    )


def test_person_save_intent_carries_person_card_importance():
    intent = simple_memory_intent_from_payload(
        {"display_name": "Ariadyna", "relationship": "mom"},
        for_person=True,
    )

    assert intent is not None
    assert intent.importance >= 4


def test_relationship_card_keeps_the_birthday_it_was_saved_with():
    card = PersonCardBuilder().person_card_from_memory(
        {
            "id": "memory-1",
            "memory_type": "fact",
            "content": "User's mother is Ariadyna.",
            "importance": 4,
            "metadata": {
                "fact_kind": "relationship",
                "entity_label": "Ariadyna",
                "relationship": "mother",
                "normalized_date": "June 18",
                "notes": "Lives in Boston",
            },
        }
    )

    assert card is not None
    attributes = card["metadata"]["attributes"]
    assert attributes["relationship_to_user"] == "mother"
    assert attributes["birthday"] == "June 18"
    assert attributes["notes"] == "Lives in Boston"
