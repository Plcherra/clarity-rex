"""Flat Knows saves: propose, confirm, apply — and never save before confirm.

A turn writes only when Grok emits a ```rex_action```; the body then proposes,
and only an explicit confirmation applies the frozen snapshot.
"""

from __future__ import annotations

import pytest

from chat_memory_brain_support import scripted_turns, seed_flat_memory
from durable_write_test_helpers import (
    assert_companion_continuation_response,
    confirm_durable_write,
)
from scripted_brain_fakes import reply_with_action

DARK_MODE_SAVE = {
    "dark mode": reply_with_action(
        "Dark mode it is.",
        "save_memory",
        {"content": "User prefers dark mode.", "memory_type": "preference"},
    ),
}


def _tea_update_script(memory_id: str) -> dict[str, str]:
    return {
        "green tea": reply_with_action(
            "Green tea, noted.",
            "update_memory",
            {
                "memory_id": memory_id,
                "content": "User prefers green tea.",
                "previous_content": "User prefers black tea.",
            },
        ),
    }


@pytest.mark.asyncio
async def test_save_memory_action_proposes_and_saves_nothing_yet():
    turns = scripted_turns(DARK_MODE_SAVE)

    proposed = await turns.chat.send_message("I always use dark mode")

    changes = proposed["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes["created"] == 0
    assert changes["write_proposals"][0]["write_kind"] == "memory"
    assert changes["write_proposals"][0]["body"] == "User prefers dark mode."
    assert turns.store.long_term_memory == []
    assert proposed["response"] == "Dark mode it is."
    assert turns.brain.generate_calls == 1


@pytest.mark.asyncio
async def test_confirmed_save_applies_the_frozen_proposal():
    turns = scripted_turns(DARK_MODE_SAVE)

    proposed = await turns.chat.send_message("I always use dark mode")
    saved = await confirm_durable_write(turns.chat, proposed)

    changes = saved["memory_changes"]
    assert changes["created"] == 1
    assert changes["confirmation_required"] == 0
    assert changes["write_proposals"][0]["status"] == "applied"
    assert saved["response"] == "Saved to Clarity Knows: User prefers dark mode."
    assert saved["messages"][-1]["content"] == saved["response"]
    assert len(turns.store.long_term_memory) == 1
    assert turns.store.long_term_memory[0]["content"] == "User prefers dark mode."
    # The confirm turn is body-only — it must not spend another Grok call.
    assert turns.brain.generate_calls == 1


@pytest.mark.asyncio
async def test_typed_yes_confirms_the_pending_save():
    turns = scripted_turns(DARK_MODE_SAVE)

    proposed = await turns.chat.send_message("I always use dark mode")
    saved = await turns.chat.send_message("yes", proposed["conversation_id"])

    assert saved["memory_changes"]["created"] == 1
    assert len(turns.store.long_term_memory) == 1


@pytest.mark.asyncio
async def test_no_dismisses_the_pending_save_and_writes_nothing():
    turns = scripted_turns(DARK_MODE_SAVE)

    proposed = await turns.chat.send_message("I always use dark mode")
    rejected = await turns.chat.send_message("No", proposed["conversation_id"])

    changes = rejected["memory_changes"]
    assert changes["skipped"] == 1
    assert changes["created"] == 0
    assert changes["write_proposals"][0]["status"] == "dismissed"
    assert rejected["response"] == "Okay, I won't save User prefers dark mode.."
    assert turns.store.long_term_memory == []
    assert turns.store.pending_actions == {}


@pytest.mark.asyncio
async def test_unrelated_turn_keeps_the_proposal_pending_without_saving():
    turns = scripted_turns(DARK_MODE_SAVE)

    proposed = await turns.chat.send_message("I always use dark mode")
    follow_up = await turns.chat.send_message(
        "Why does that matter?",
        proposed["conversation_id"],
    )

    assert_companion_continuation_response(follow_up)
    assert follow_up["memory_changes"] is None
    assert turns.store.long_term_memory == []

    saved = await confirm_durable_write(turns.chat, proposed)
    assert saved["memory_changes"]["created"] == 1
    assert len(turns.store.long_term_memory) == 1


@pytest.mark.asyncio
async def test_yes_after_the_save_applied_does_not_save_again():
    turns = scripted_turns(DARK_MODE_SAVE)

    proposed = await turns.chat.send_message("I always use dark mode")
    saved = await confirm_durable_write(turns.chat, proposed)
    stray = await turns.chat.send_message("yes", saved["conversation_id"])

    assert_companion_continuation_response(stray)
    assert stray["memory_changes"] is None
    assert len(turns.store.long_term_memory) == 1


@pytest.mark.asyncio
async def test_repeating_a_saved_fact_updates_instead_of_duplicating():
    turns = scripted_turns(DARK_MODE_SAVE)

    first = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("I always use dark mode"),
    )
    repeated_proposal = await turns.chat.send_message(
        "I always use dark mode",
        first["conversation_id"],
    )
    repeated = await confirm_durable_write(turns.chat, repeated_proposal)

    assert first["memory_changes"]["created"] == 1
    assert repeated["memory_changes"]["created"] == 0
    assert repeated["memory_changes"]["updated"] == 1
    assert len(turns.store.long_term_memory) == 1
    assert turns.store.long_term_memory[0]["id"] == "memory-1"


@pytest.mark.asyncio
async def test_update_memory_action_rewrites_the_existing_record():
    turns = scripted_turns(_tea_update_script("memory-tea"))
    seed_flat_memory(
        turns.store,
        memory_id="memory-tea",
        content="User prefers black tea.",
        memory_type="preference",
    )

    proposed = await turns.chat.send_message("Actually I switched to green tea")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    assert turns.store.long_term_memory[0]["content"] == "User prefers black tea."

    updated = await confirm_durable_write(turns.chat, proposed)

    assert updated["memory_changes"]["updated"] == 1
    assert updated["memory_changes"]["created"] == 0
    assert updated["response"] == "Updated Clarity Knows: User prefers green tea."
    assert len(turns.store.long_term_memory) == 1
    assert turns.store.long_term_memory[0]["content"] == "User prefers green tea."


@pytest.mark.asyncio
async def test_a_plan_memory_stays_one_record_across_updates():
    script = {
        "watch it tonight": reply_with_action(
            "Enjoy the movie.",
            "save_memory",
            {"content": "User plans to watch Masters of the Universe tonight."},
        ),
        "bought the tickets": reply_with_action(
            "Nice, tickets sorted.",
            "update_memory",
            {
                "memory_id": "memory-1",
                "content": (
                    "User bought tickets to watch Masters of the Universe tonight."
                ),
            },
        ),
        "have to cancel": reply_with_action(
            "That's a fair call.",
            "update_memory",
            {
                "memory_id": "memory-1",
                "content": (
                    "User canceled the plan to watch Masters of the Universe "
                    "tonight because money is tight."
                ),
            },
        ),
    }
    turns = scripted_turns(script)

    planned = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("I'm gonna watch it tonight"),
    )
    conversation_id = planned["conversation_id"]
    tickets = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message("I already bought the tickets", conversation_id),
    )
    canceled = await confirm_durable_write(
        turns.chat,
        await turns.chat.send_message(
            "I have to cancel, money is tight",
            conversation_id,
        ),
    )

    assert planned["memory_changes"]["created"] == 1
    assert tickets["memory_changes"]["updated"] == 1
    assert canceled["memory_changes"]["updated"] == 1
    assert len(turns.store.long_term_memory) == 1
    assert turns.store.long_term_memory[0]["content"] == (
        "User canceled the plan to watch Masters of the Universe tonight "
        "because money is tight."
    )


@pytest.mark.asyncio
async def test_save_claim_without_an_action_is_replaced_by_an_honest_reply():
    turns = scripted_turns(
        {"remember": "Saved that to your Knows — I'll remember it."}
    )

    result = await turns.chat.send_message("Please remember that I prefer tea.")

    assert "don't have a confirmed saved change" in result["response"]
    assert "Saved that to your Knows" not in result["response"]
    assert result["memory_changes"] is None
    assert turns.store.long_term_memory == []


@pytest.mark.asyncio
async def test_save_memory_without_content_asks_instead_of_saving():
    turns = scripted_turns(
        {"remember": reply_with_action("Sure thing.", "save_memory", {})}
    )

    result = await turns.chat.send_message("Remember this for me")

    assert "I need a clear fact or preference to save" in result["response"]
    assert result["memory_changes"]["confirmation_required"] == 0
    assert result["memory_changes"]["created"] == 0
    assert turns.store.long_term_memory == []
