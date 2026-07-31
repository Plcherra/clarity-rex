"""Knows deletes: confirm first, hard delete, and never claim an unverified delete."""

from __future__ import annotations

import pytest

from chat_memory_brain_support import scripted_turns, seed_flat_memory
from chat_service_fakes import FakeMemoryService
from durable_write_test_helpers import confirm_durable_write
from scripted_brain_fakes import reply_with_action

TONIGHT_PLAN_TITLE = "User plans to watch it tonight."


def _delete_tonight_plan_script(reply: str = "I can remove that.") -> dict[str, str]:
    return {
        "tonight plan": reply_with_action(
            reply,
            "delete_knows_item",
            {"title": TONIGHT_PLAN_TITLE},
        )
    }


def _seed_tonight_plan(store: FakeMemoryService) -> dict:
    return seed_flat_memory(
        store,
        memory_id="memory-tonight-plan",
        content=TONIGHT_PLAN_TITLE,
        memory_type="event",
        metadata={
            "fact_kind": "personal_plan",
            "topic_fingerprint": "event:personal_plan:watch:it",
        },
    )


@pytest.mark.asyncio
async def test_delete_action_confirms_first_then_hard_deletes():
    turns = scripted_turns(_delete_tonight_plan_script())
    _seed_tonight_plan(turns.store)

    requested = await turns.chat.send_message("Can you delete that tonight plan?")

    proposal = requested["memory_changes"]["write_proposals"][0]
    assert requested["memory_changes"]["confirmation_required"] == 1
    assert proposal["write_kind"] == "delete"
    assert "cannot be undone" in proposal["confirmation_text"].lower()
    assert TONIGHT_PLAN_TITLE in proposal["confirmation_text"]
    assert turns.store.long_term_memory[0]["active"] is True

    confirmed = await confirm_durable_write(turns.chat, requested)

    assert "Permanently deleted" in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert turns.store.long_term_memory == []
    assert turns.brain.generate_calls == 1


@pytest.mark.asyncio
async def test_delete_action_removes_a_saved_entity_event():
    turns = scripted_turns(
        {
            "birthday note": reply_with_action(
                "Sure, removing it.",
                "delete_knows_item",
                {"title": "Mom birthday note"},
            )
        }
    )
    turns.store.entity_events.append(
        {
            "id": "event-birthday-note",
            "entity_id": "entity-mom",
            "event_type": "birthday",
            "title": "Mom birthday note",
            "content": "Mom's birthday is June 18.",
            "active": True,
        }
    )

    requested = await turns.chat.send_message("Delete the Mom birthday note")
    confirmed = await confirm_durable_write(turns.chat, requested)

    assert requested["memory_changes"]["confirmation_required"] == 1
    assert confirmed["memory_changes"]["archived"] == 1
    assert turns.store.entity_events == []


@pytest.mark.asyncio
async def test_delete_without_a_reference_asks_which_item():
    turns = scripted_turns(
        {
            "delete a memory": reply_with_action(
                "Sure.",
                "delete_knows_item",
                {},
            )
        }
    )
    _seed_tonight_plan(turns.store)

    result = await turns.chat.send_message("Can you delete a memory please?")

    assert "which Knows item to delete" in result["response"]
    assert "Nothing will be deleted until you confirm." in result["response"]
    assert result["memory_changes"]["archived"] == 0
    assert result["memory_changes"]["confirmation_required"] == 0
    assert turns.store.long_term_memory[0]["active"] is True


@pytest.mark.asyncio
async def test_delete_of_an_unknown_item_does_not_invent_a_target():
    turns = scripted_turns(
        {
            "gym plan": reply_with_action(
                "Let me check.",
                "delete_knows_item",
                {"title": "Gym plan"},
            )
        }
    )
    _seed_tonight_plan(turns.store)

    result = await turns.chat.send_message("Delete the gym plan")

    assert "couldn't find that item in Knows" in result["response"]
    assert result["memory_changes"]["archived"] == 0
    assert result["memory_changes"]["confirmation_required"] == 0
    assert turns.store.long_term_memory[0]["active"] is True


@pytest.mark.asyncio
async def test_delete_is_not_claimed_when_the_record_stays_active():
    class StaleActiveDeleteMemoryService(FakeMemoryService):
        async def delete_long_term_memory(self, memory_id):
            return True

    turns = scripted_turns(
        _delete_tonight_plan_script(),
        store=StaleActiveDeleteMemoryService(),
    )
    _seed_tonight_plan(turns.store)

    requested = await turns.chat.send_message("Can you delete that tonight plan?")
    confirmed = await confirm_durable_write(turns.chat, requested)

    assert "couldn't delete" in confirmed["response"].lower()
    assert "Permanently deleted" not in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 0
    assert turns.store.long_term_memory[0]["active"] is True


@pytest.mark.asyncio
async def test_declining_the_delete_keeps_the_saved_item():
    turns = scripted_turns(_delete_tonight_plan_script())
    _seed_tonight_plan(turns.store)

    requested = await turns.chat.send_message("Can you delete that tonight plan?")
    rejected = await turns.chat.send_message(
        "No",
        requested["conversation_id"],
    )

    assert rejected["memory_changes"]["skipped"] == 1
    assert rejected["memory_changes"]["archived"] == 0
    assert turns.store.long_term_memory[0]["active"] is True
    assert turns.store.pending_actions == {}


@pytest.mark.asyncio
async def test_delete_claim_without_an_action_is_replaced_by_an_honest_reply():
    turns = scripted_turns({"delete": "Done, I deleted it."})
    _seed_tonight_plan(turns.store)

    result = await turns.chat.send_message("Can you delete that?")

    assert "confirmed backend delete" in result["response"]
    assert "Done, I deleted it" not in result["response"]
    assert result["memory_changes"] is None
    assert turns.store.long_term_memory[0]["active"] is True


@pytest.mark.asyncio
async def test_delete_goal_action_confirms_then_removes_the_plan():
    turns = scripted_turns(
        {
            "junk goal": reply_with_action(
                "I'll clear that one.",
                "delete_goal",
                {"reference": "Be a goal/commitment"},
            )
        }
    )
    turns.store.plans.append(
        {
            "id": "plan-junk",
            "title": "Be a goal/commitment",
            "description": "be a goal/commitment",
            "plan_type": "personal",
            "active": True,
        }
    )

    requested = await turns.chat.send_message("Delete that junk goal")
    assert requested["memory_changes"]["confirmation_required"] == 1
    assert turns.store.plans[0]["active"] is True

    confirmed = await confirm_durable_write(turns.chat, requested)

    assert confirmed["memory_changes"]["archived"] == 1
    assert turns.store.plans == []
