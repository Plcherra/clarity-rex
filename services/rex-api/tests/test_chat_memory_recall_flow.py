"""What a saved fact means for later turns: Knows visibility and a thin prompt.

Recall is no longer an always-on Knows dump in the base prompt. The base turn
stays thin and the brain must ask for a fetch capability, so these tests pin
both halves: the save is really visible in Knows, and the prompt does not carry
it for free.
"""

from __future__ import annotations

import pytest

from chat_memory_brain_support import active_person_cards, scripted_turns
from durable_write_test_helpers import confirm_durable_write
from scripted_brain_fakes import reply_with_action

MOM_BIRTHDAY_SAVE = {
    "my mom's birthday": reply_with_action(
        "June 18 — got it.",
        "save_person",
        {
            "display_name": "Mom",
            "relationship": "mom",
            "birthday": "June 18",
            "importance": 4,
        },
    ),
}


@pytest.mark.asyncio
async def test_confirmed_save_is_visible_in_knows_afterwards():
    turns = scripted_turns(MOM_BIRTHDAY_SAVE)

    saved = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My mom's birthday is June 18"),
    )

    assert saved["memory_changes"]["created"] == 1
    cards = active_person_cards(turns.store)
    assert len(cards) == 1
    assert cards[0]["relationship"] == "mother"
    listed = await turns.store.list_entities(active=True, limit=50)
    assert [row["id"] for row in listed] == [cards[0]["id"]]


@pytest.mark.asyncio
async def test_saved_flat_detail_stays_readable_in_knows():
    turns = scripted_turns(
        {
            "my mom's birthday": reply_with_action(
                "June 18 — got it.",
                "save_memory",
                {
                    "content": "User's mom's birthday is June 18.",
                    "importance": 4,
                    "memory_category": "People",
                },
            )
        }
    )

    await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My mom's birthday is June 18"),
    )

    listed = await turns.store.list_long_term_memory(active=True)
    assert [row["content"] for row in listed] == ["User's mom's birthday is June 18."]


@pytest.mark.asyncio
async def test_base_recall_turn_stays_thin_and_does_not_dump_knows():
    turns = scripted_turns(MOM_BIRTHDAY_SAVE)

    saved = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My mom's birthday is June 18"),
    )
    await turns.chat.send_message(
        "Do you remember my mom's birthday?",
        saved["conversation_id"],
    )

    system_prompt = turns.brain.messages[0]["content"]
    assert turns.brain.messages[0]["role"] == "system"
    # No always-on Knows dump: the saved detail is not free in the base turn.
    assert "June 18" not in system_prompt
    # It is reachable instead through named fetch capabilities.
    assert "fetch_person_context" in system_prompt
    assert "search_chats" in system_prompt


@pytest.mark.asyncio
async def test_recent_turns_are_the_only_thin_state_carried_forward():
    turns = scripted_turns(MOM_BIRTHDAY_SAVE)

    saved = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My mom's birthday is June 18"),
    )
    await turns.chat.send_message(
        "Do you remember my mom's birthday?",
        saved["conversation_id"],
    )

    roles = [message["role"] for message in turns.brain.messages]
    contents = [message["content"] for message in turns.brain.messages]
    assert roles[0] == "system"
    assert "My mom's birthday is June 18" in contents
    assert contents[-1] == "Do you remember my mom's birthday?"


@pytest.mark.asyncio
async def test_read_only_fetch_action_writes_nothing():
    turns = scripted_turns(
        {
            "tell me about my mom": reply_with_action(
                "Let me pull up what you've saved about her.",
                "fetch_person_context",
                {"display_name": "Mom"},
            )
        }
    )

    result = await turns.chat.send_message("Tell me about my mom")

    assert result["response"] == "Let me pull up what you've saved about her."
    assert result["memory_changes"] is None
    assert turns.store.long_term_memory == []
    assert turns.store.entities == []


@pytest.mark.asyncio
async def test_recall_answer_without_a_write_makes_no_saved_claim():
    turns = scripted_turns(
        {"what do you know": "I don't have anything saved about that yet."}
    )

    result = await turns.chat.send_message("What do you know about my mom?")

    assert result["response"] == "I don't have anything saved about that yet."
    assert result["memory_changes"] is None
    assert turns.store.long_term_memory == []
