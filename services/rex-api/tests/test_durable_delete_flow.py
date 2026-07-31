"""Durable delete confirmation cards with permanent removal.

A delete only happens when the brain asks for it and the user confirms the
high-risk card; open-thread deletes are not body-wired, so Rex says so
instead of quietly removing the thread.
"""

from __future__ import annotations

import pytest

from chat_service_fakes import FakeMemoryService
from durable_write_brain_scripts import (
    confirm_proposal,
    only_proposal,
    scripted_chat_service,
)
from scripted_brain_fakes import reply_with_action

DELETE_BRAIN = {
    "tonight": reply_with_action(
        "I can remove that tonight plan.",
        "delete_knows_item",
        {
            "id": "memory-tonight-plan",
            "table": "long_term_memory",
            "title": "User plans to watch it tonight.",
        },
    ),
    "goal": reply_with_action(
        "I can delete that goal.",
        "delete_goal",
        {"plan_id": "plan-junk", "title": "Buy dumbbells"},
    ),
    "thread": reply_with_action(
        "Let me look at that thread.",
        "delete_open_thread",
        {"title": "Morning routine"},
    ),
}


def _chat_service(memory_service: FakeMemoryService):
    return scripted_chat_service(DELETE_BRAIN, memory_service)


@pytest.mark.asyncio
async def test_delete_memory_proposes_high_risk_card_and_hard_deletes():
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-tonight-plan",
            "memory_type": "event",
            "content": "User plans to watch it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {"fact_kind": "personal_plan"},
        }
    )
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("Delete the tonight plan you saved")

    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = only_proposal(proposed)
    assert proposal["write_kind"] == "delete"
    assert proposal["risk_level"] == "high"
    assert proposal["delete_table"] == "long_term_memory"
    assert "cannot be undone" in proposal["confirmation_text"].lower()
    assert len(memory_service.long_term_memory) == 1

    confirmed = await confirm_proposal(chat_service, proposed)

    assert "Permanently deleted" in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_delete_goal_uses_same_card_flow():
    memory_service = FakeMemoryService()
    memory_service.plans.append(
        {
            "id": "plan-junk",
            "title": "Buy dumbbells",
            "description": "Buy dumbbells",
            "plan_type": "personal",
            "active": True,
        }
    )
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("Delete the goal Buy dumbbells")

    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = only_proposal(proposed)
    assert proposal["write_kind"] == "delete"
    assert proposal["delete_table"] == "plans"
    assert len(memory_service.plans) == 1

    confirmed = await confirm_proposal(chat_service, proposed)

    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.plans == []


@pytest.mark.asyncio
async def test_delete_open_thread_is_refused_instead_of_silently_dropped():
    memory_service = FakeMemoryService()
    memory_service.open_threads.append(
        {
            "id": "thread-1",
            "title": "Morning routine",
            "summary": "Follow up on morning routine",
            "status": "active",
        }
    )
    chat_service = _chat_service(memory_service)

    turn = await chat_service.send_message('Delete the open thread "Morning routine"')

    changes = turn["memory_changes"]
    assert changes["confirmation_required"] == 0
    assert changes.get("write_proposals") in (None, [])
    assert "can't delete an open thread from chat yet" in turn["response"].lower()
    assert "goals" in turn["response"].lower()
    assert memory_service.open_threads == [
        {
            "id": "thread-1",
            "title": "Morning routine",
            "summary": "Follow up on morning routine",
            "status": "active",
        }
    ]
    assert memory_service.pending_actions == {}
