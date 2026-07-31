"""Goal writes from a chat turn: the brain names the goal, the body confirms it."""

from __future__ import annotations

import pytest

from chat_memory_brain_support import scripted_turns
from durable_write_test_helpers import confirm_durable_write
from scripted_brain_fakes import reply_with_action

HARDWARE_GOAL = {
    "32gb": reply_with_action(
        "Locked in for next month.",
        "create_goal",
        {
            "title": "Upgrade computer hardware",
            "description": "Get 32GB-64GB RAM and 1TB-2TB storage by next month.",
            "plan_type": "personal",
            "target_date": "next month",
        },
    ),
}


@pytest.mark.asyncio
async def test_create_goal_action_confirms_before_creating_the_plan():
    turns = scripted_turns(HARDWARE_GOAL)

    requested = await turns.chat.send_message(
        "Get 32gb-64gb ram and 1tb-2tb storage by next month"
    )

    assert requested["memory_changes"]["confirmation_required"] == 1
    assert turns.store.created_plans == []

    confirmed = await confirm_durable_write(turns.chat, requested)

    assert confirmed["memory_changes"]["created"] == 1
    assert len(turns.store.created_plans) == 1
    assert turns.store.created_plans[0]["title"] == "Upgrade computer hardware"
    assert turns.brain.generate_calls == 1


@pytest.mark.asyncio
async def test_goal_talk_without_an_action_creates_no_plan():
    turns = scripted_turns(
        {"32gb": "That upgrade would make a real difference."}
    )

    result = await turns.chat.send_message(
        "Get 32gb-64gb ram and 1tb-2tb storage by next month"
    )

    assert result["memory_changes"] is None
    assert turns.store.created_plans == []
    assert turns.store.plans == []


@pytest.mark.asyncio
async def test_goal_success_claim_without_an_action_is_replaced():
    turns = scripted_turns(
        {"32gb": "Done — I created that goal for you in Goals."}
    )

    result = await turns.chat.send_message(
        "Get 32gb-64gb ram and 1tb-2tb storage by next month"
    )

    assert "Done — I created that goal" not in result["response"]
    assert turns.store.created_plans == []
