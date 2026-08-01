"""Goal durable writes — propose a plan, confirm it, see it in Goals.

A goal with no stated deadline must ask for one rather than land without a
progress bar.
"""

from __future__ import annotations

import pytest

from chat_service_fakes import FakeMemoryService
from durable_write_brain_scripts import (
    confirm_proposal,
    only_proposal,
    pending_apply_snapshot,
    scripted_chat_service,
)
from scripted_brain_fakes import reply_with_action

GOAL_BRAIN = {
    "dumbbells": reply_with_action(
        "Dumbbells it is — 40 to 60 pounds.",
        "create_goal",
        {
            "title": "Buy dumbbells",
            "description": "Buy dumbbells from 40 to 60 pounds",
        },
    ),
    "$5000": reply_with_action(
        "Saving $5000 by August is a clear target.",
        "create_goal",
        {
            "title": "Save $5000 by August",
            "description": "Save $5000 by August",
            "plan_type": "finance",
            "target_date": "2026-08-31",
            "target_amount": 5000,
        },
    ),
}


def _chat_service(memory_service: FakeMemoryService):
    return scripted_chat_service(GOAL_BRAIN, memory_service)


@pytest.mark.asyncio
async def test_create_goal_requires_confirmation_before_save():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("Track save $5000 by August as a goal")

    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = only_proposal(proposed)
    assert proposal["write_kind"] == "plan"
    assert proposal["status"] == "pending"
    snapshot = pending_apply_snapshot(memory_service, proposed["conversation_id"])
    assert snapshot["type"] == "plan"
    assert snapshot["payload"]["target_date"] == "2026-08-31"
    assert float(snapshot["payload"]["target_amount"]) == 5000
    assert memory_service.plans == []


@pytest.mark.asyncio
async def test_create_goal_confirm_creates_plan():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("Track save $5000 by August as a goal")
    confirmed = await confirm_proposal(chat_service, proposed)

    assert confirmed["memory_changes"]["created"] == 1
    assert confirmed["memory_changes"]["write_proposals"][0]["status"] == "applied"
    assert len(memory_service.plans) == 1
    plan = memory_service.plans[0]
    assert plan["title"] == "Save $5000 by August"
    assert plan["plan_type"] == "finance"
    assert float(plan.get("target_amount") or 0) == 5000
    assert "Saved plan in Goals" in confirmed["response"]


@pytest.mark.asyncio
async def test_goal_without_a_deadline_asks_instead_of_saving():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message(
        "I want to buy dumbbells, maybe 40 to sixty pounds."
    )

    assert proposed["memory_changes"]["created"] == 0
    assert proposed["memory_changes"].get("confirmation_required", 0) == 0
    assert memory_service.plans == []
    assert "due date" in proposed["response"].lower()
