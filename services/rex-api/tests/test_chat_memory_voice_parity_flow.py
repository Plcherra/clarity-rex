"""Voice turns use the same brain, proposals, and confirm path as chat."""

from __future__ import annotations

import pytest

from app.services.rex_channel import RexBrainChannel
from chat_memory_brain_support import scripted_turns, seed_flat_memory
from durable_write_test_helpers import confirm_durable_write
from memory_persist_assertions import assert_person_card_covers
from scripted_brain_fakes import reply_with_action

MOM_BIRTHDAY_SAVE = {
    "my mom's birthday": reply_with_action(
        "June 18 — noted.",
        "save_person",
        {
            "display_name": "Mom",
            "relationship": "mom",
            "birthday": "June 18",
            "importance": 4,
        },
    ),
}


async def _voice_events(chat, message: str, conversation_id: str | None = None):
    return [
        event
        async for event in chat.stream_message(
            message,
            conversation_id=conversation_id,
            channel=RexBrainChannel.VOICE,
        )
    ]


def _proposal_result(events: list[dict]) -> dict:
    return {
        "conversation_id": events[-1]["conversation_id"],
        "memory_changes": events[-1]["memory_changes"],
    }


@pytest.mark.asyncio
async def test_voice_save_proposes_first_and_confirm_materializes_the_card():
    turns = scripted_turns(MOM_BIRTHDAY_SAVE)

    events = await _voice_events(turns.chat, "My mom's birthday is June 18")

    assert events[0] == {"event": "conversation", "conversation_id": "conversation-1"}
    assert events[-1]["event"] == "done"
    assert events[-1]["memory_changes"]["confirmation_required"] == 1
    assert turns.store.long_term_memory == []
    assert turns.store.entities == []

    confirmed = await confirm_durable_write(turns.chat, _proposal_result(events))

    assert confirmed["memory_changes"]["created"] == 1
    assert_person_card_covers(
        turns.store,
        relationship="mother",
        flat_content_gone="mom's birthday",
    )


@pytest.mark.asyncio
async def test_voice_update_rewrites_the_existing_memory_after_confirm():
    turns = scripted_turns(
        {
            "one o and one m": reply_with_action(
                "Fixed the spelling.",
                "update_memory",
                {
                    "memory_id": "memory-existing",
                    "content": "User lives in Somerville, Massachusetts.",
                    "importance": 4,
                },
            )
        }
    )
    seed_flat_memory(
        turns.store,
        memory_id="memory-existing",
        content="User lives in Summerville, Massachusetts.",
    )

    events = await _voice_events(
        turns.chat,
        "Can you change my location? It's Somerville with one o and one m.",
    )

    assert events[-1]["memory_changes"]["confirmation_required"] == 1
    assert turns.store.long_term_memory[0]["content"] == (
        "User lives in Summerville, Massachusetts."
    )

    confirmed = await confirm_durable_write(turns.chat, _proposal_result(events))

    assert confirmed["memory_changes"]["updated"] == 1
    assert turns.brain.generate_calls == 0
    assert turns.brain.stream_calls == 1
    person = assert_person_card_covers(
        turns.store,
        relationship="self",
        attribute_contains={"location": "Somerville"},
    )
    assert person["metadata"]["attributes"]["location"] == "Somerville, Massachusetts"
    # Covered location flat is hard-deleted once the self card holds it.
    assert turns.store.long_term_memory == []


@pytest.mark.asyncio
async def test_voice_turn_without_an_action_saves_nothing():
    turns = scripted_turns(
        {"masters of the universe": "That sounds like a fun night."}
    )

    events = await _voice_events(
        turns.chat,
        "They released Masters of the Universe today. I'm gonna watch it.",
    )

    assert events[-1]["event"] == "done"
    assert events[-1]["memory_changes"] is None
    assert turns.store.long_term_memory == []
