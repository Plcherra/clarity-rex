"""Confirmed People saves become person cards in Knows.

The brain names the person; the body proposes, and the confirmed write is what
materializes (or merges into) a card and removes the flat it covers.
"""

from __future__ import annotations

import pytest

from chat_memory_brain_support import active_person_cards, scripted_turns
from durable_write_test_helpers import confirm_durable_write
from memory_persist_assertions import assert_person_card_covers
from scripted_brain_fakes import reply_with_action

MOM_SAVE = reply_with_action(
    "Ariadyna — good to know.",
    "save_person",
    {"display_name": "Ariadyna", "relationship": "mom", "importance": 4},
)


def _seed_mom_card(store, *, display_name: str = "S Mom") -> dict:
    entity = {
        "id": "entity-mom",
        "entity_type": "person",
        "display_name": display_name,
        "normalized_name": display_name.casefold(),
        "relationship": "mother",
        "aliases": [],
        "metadata": {"attributes": {"birthday": "June 18"}},
        "active": True,
    }
    store.entities.append(entity)
    return entity


@pytest.mark.asyncio
async def test_confirmed_person_save_materializes_a_person_card():
    turns = scripted_turns({"my mom": MOM_SAVE})

    proposed = await turns.chat.send_message("My mom is Ariadyna")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    assert proposed["memory_changes"]["write_proposals"][0]["person_card"][
        "display_name"
    ] == "Ariadyna"
    assert turns.store.entities == []

    saved = await confirm_durable_write(turns.chat, proposed)

    assert saved["memory_changes"]["created"] == 1
    person = assert_person_card_covers(
        turns.store,
        relationship="mother",
        display_name_contains="Ariadyna",
    )
    assert person["display_name"] == "Ariadyna"
    # The flat the card now covers is deleted, not left as a duplicate.
    assert turns.store.long_term_memory == []


@pytest.mark.asyncio
async def test_person_save_without_two_details_cannot_apply():
    turns = scripted_turns(
        {
            "ariadyna": reply_with_action(
                "Ariadyna, got it.",
                "save_person",
                {"display_name": "Ariadyna"},
            )
        }
    )

    proposed = await turns.chat.send_message("Save Ariadyna please")
    blocked = await confirm_durable_write(turns.chat, proposed)

    assert "at least two person details" in blocked["response"]
    assert blocked["memory_changes"]["created"] == 0
    assert blocked["memory_changes"]["write_proposals"][0]["status"] == "failed"
    assert turns.store.entities == []
    assert turns.store.long_term_memory == []


@pytest.mark.asyncio
async def test_confirmed_self_facts_merge_into_one_self_card():
    script = {
        "my name is": reply_with_action(
            "Good to meet you, Pedro.",
            "save_memory",
            {"content": "User's name is Pedro Martins.", "importance": 4},
        ),
        "i live in": reply_with_action(
            "Somerville, nice.",
            "save_memory",
            {"content": "User lives in Somerville.", "importance": 4},
        ),
        "my birthday": reply_with_action(
            "June 18 — noted.",
            "save_memory",
            {"content": "User's birthday is June 18.", "importance": 4},
        ),
        "i work at": reply_with_action(
            "Bom Dough, got it.",
            "save_memory",
            {"content": "User works at Bom Dough.", "importance": 4},
        ),
    }
    turns = scripted_turns(script)

    name = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My name is Pedro Martins."),
    )
    conversation_id = name["conversation_id"]
    location = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("I live in Somerville.", conversation_id),
    )
    birthday = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My birthday is June 18.", conversation_id),
    )
    work = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("I work at Bom Dough.", conversation_id),
    )

    assert name["memory_changes"]["created"] == 1
    assert location["memory_changes"]["created"] == 1
    assert birthday["memory_changes"]["created"] == 1
    assert work["memory_changes"]["created"] == 1
    assert len(active_person_cards(turns.store)) == 1
    person = assert_person_card_covers(
        turns.store,
        relationship="self",
        display_name_contains="Pedro",
        attribute_contains={
            "full_name": "Pedro Martins",
            "location": "Somerville",
            "birthday": "June 18",
        },
    )
    attributes = person["metadata"]["attributes"]
    assert "Bom Dough" in str(attributes.get("workplace") or attributes.get("notes"))
    assert turns.store.long_term_memory == []


@pytest.mark.asyncio
async def test_low_importance_self_fact_stays_flat_in_knows():
    """Materialization is reserved for facts the brain marks durable (>= 4)."""
    turns = scripted_turns(
        {
            "i live in": reply_with_action(
                "Somerville, nice.",
                "save_memory",
                {"content": "User lives in Somerville.", "importance": 3},
            )
        }
    )

    saved = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("I live in Somerville."),
    )

    assert saved["memory_changes"]["created"] == 1
    assert active_person_cards(turns.store) == []
    assert len(turns.store.long_term_memory) == 1
    assert turns.store.long_term_memory[0]["content"] == "User lives in Somerville."


@pytest.mark.asyncio
async def test_person_save_with_a_new_name_updates_the_existing_card():
    turns = scripted_turns({"my mom": MOM_SAVE})
    existing = _seed_mom_card(turns.store)

    saved = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My mom is Ariadyna, not S Mom"),
    )

    assert saved["memory_changes"]["write_proposals"][0]["person_card"][
        "merge_hint"
    ]
    cards = active_person_cards(turns.store)
    assert len(cards) == 1
    assert cards[0]["id"] == existing["id"]
    assert cards[0]["display_name"] == "Ariadyna"
    # Details already on the card survive the rename.
    assert cards[0]["metadata"]["attributes"]["birthday"] == "June 18"
    assert turns.store.long_term_memory == []


@pytest.mark.asyncio
async def test_saving_the_same_person_twice_keeps_one_card():
    turns = scripted_turns({"my mom": MOM_SAVE})

    first = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My mom is Ariadyna"),
    )
    second = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My mom is Ariadyna", first["conversation_id"]),
    )

    assert second["memory_changes"]["confirmation_required"] == 0
    assert len(active_person_cards(turns.store)) == 1
    assert turns.store.long_term_memory == []


@pytest.mark.asyncio
async def test_two_people_get_their_own_cards():
    script = {
        "my mom": MOM_SAVE,
        "best friend": reply_with_action(
            "Pedro, noted.",
            "save_person",
            {"display_name": "Pedro", "relationship": "friend", "importance": 4},
        ),
    }
    turns = scripted_turns(script)

    mom = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("My mom is Ariadyna"),
    )
    friend = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message(
            "Remember that my best friend is Pedro.",
            mom["conversation_id"],
        ),
    )

    assert friend["memory_changes"]["created"] == 1
    assert len(active_person_cards(turns.store)) == 2
    assert_person_card_covers(
        turns.store,
        relationship="mother",
        display_name_contains="Ariadyna",
    )
    assert_person_card_covers(
        turns.store,
        relationship="friend",
        display_name_contains="Pedro",
    )
    assert turns.store.long_term_memory == []


@pytest.mark.asyncio
async def test_person_state_and_note_updates_land_on_the_saved_card():
    script = {
        "visiting this week": reply_with_action(
            "Nice, a visit.",
            "update_person_state",
            {"person_id": "entity-mom", "state": "Visiting this week"},
        ),
        "brought pasta": reply_with_action(
            "Pasta night.",
            "add_person_note",
            {"person_id": "entity-mom", "note": "Brought pasta"},
        ),
    }
    turns = scripted_turns(script)
    entity = _seed_mom_card(turns.store, display_name="Ariadyna")

    state_proposed = await turns.chat.send_message("Mom is visiting this week")
    assert state_proposed["memory_changes"]["confirmation_required"] == 1
    assert entity.get("summary") is None

    state = await confirm_durable_write(turns.chat, state_proposed)
    assert state["memory_changes"]["updated"] == 1
    assert entity["summary"] == "Visiting this week"

    note = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message(
            "She brought pasta",
            state["conversation_id"],
        ),
    )
    assert note["memory_changes"]["updated"] == 1
    assert "Brought pasta" in entity["metadata"]["attributes"]["notes"]
    assert len(active_person_cards(turns.store)) == 1
