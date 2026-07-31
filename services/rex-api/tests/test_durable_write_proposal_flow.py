"""Durable write proposal flow — propose, confirm, apply from frozen snapshot.

Grok decides that a turn saves something; the body only proposes and applies.
Each test scripts the brain action and asserts the propose → confirm → apply
contract, including that nothing lands in Knows before the user confirms.
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
from memory_persist_assertions import assert_person_card_covers
from scripted_brain_fakes import reply_with_action

MOM_BIRTHDAY_CONTENT = "User's mom's birthday is June 18."

SAVE_BRAIN = {
    "mom's birthday": reply_with_action(
        "June 18 — good to know.",
        "save_memory",
        {"content": MOM_BIRTHDAY_CONTENT, "memory_type": "fact"},
    ),
    "mom's name": reply_with_action(
        "I can save Ariadyna as your mom.",
        "save_person",
        {
            "display_name": "Ariadyna",
            "relationship": "mom",
            "birthday": "June 18",
            "importance": 5,
        },
    ),
}


def _chat_service(memory_service: FakeMemoryService):
    return scripted_chat_service(SAVE_BRAIN, memory_service)


@pytest.mark.asyncio
async def test_save_memory_action_requires_confirmation_before_save():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")

    changes = proposed["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes["created"] == 0
    proposal = only_proposal(proposed)
    assert proposal["write_kind"] == "memory"
    assert proposal["status"] == "pending"
    assert "Save to Clarity Knows" in proposal["confirmation_text"]
    assert memory_service.long_term_memory == []
    # The brain runs every turn now — the body never infers a save on its own.
    assert chat_service.ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_confirm_applies_the_frozen_snapshot():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    snapshot = pending_apply_snapshot(memory_service, proposed["conversation_id"])
    assert snapshot["type"] == "memory"

    confirmed = await confirm_proposal(chat_service, proposed)

    changes = confirmed["memory_changes"]
    assert changes["created"] == 1
    assert changes["confirmation_required"] == 0
    applied = changes["write_proposals"][0]
    assert applied["status"] == "applied"
    assert applied["result"][0]["action"] == "direct_saved"
    assert len(memory_service.long_term_memory) == 1
    saved = memory_service.long_term_memory[0]
    assert saved["content"] == snapshot["payload"]["content"]
    assert saved["memory_type"] == snapshot["payload"]["memory_type"]
    assert "Saved to Clarity Knows" in confirmed["response"]


@pytest.mark.asyncio
async def test_confirm_with_edits_applies_edited_body():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    confirmed = await confirm_proposal(
        chat_service,
        proposed,
        edits={
            "title": "Mom's birthday",
            "body": "User's mom's birthday is June 18 (confirmed by user).",
        },
    )

    assert confirmed["memory_changes"]["created"] == 1
    applied = confirmed["memory_changes"]["write_proposals"][0]
    assert applied["status"] == "applied"
    assert applied["result"][0]["action"] == "direct_saved"
    assert len(memory_service.long_term_memory) == 1
    assert (
        memory_service.long_term_memory[0]["content"]
        == "User's mom's birthday is June 18 (confirmed by user)."
    )


@pytest.mark.asyncio
async def test_confirm_person_proposal_creates_the_person_card():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("Save my mom's name as Ariadyna")
    proposal = only_proposal(proposed)
    assert (proposal.get("person_card") or {}).get("relationship") == "mother"
    assert memory_service.entities == []

    confirmed = await confirm_proposal(chat_service, proposed)

    assert confirmed["memory_changes"]["created"] == 1
    assert_person_card_covers(
        memory_service,
        relationship="mother",
        display_name_contains="Ariadyna",
        flat_content_gone="Ariadyna",
    )


@pytest.mark.asyncio
async def test_propose_routes_semantic_duplicate_to_update():
    memory_service = FakeMemoryService()
    await memory_service.save_long_term_memory(
        memory_type="fact",
        content=MOM_BIRTHDAY_CONTENT,
        importance=3,
        metadata={"fact_kind": "birthday"},
    )
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")

    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = only_proposal(proposed)
    assert proposal["status"] == "pending"
    assert proposal["write_kind"] == "memory"
    snapshot = pending_apply_snapshot(memory_service, proposed["conversation_id"])
    assert snapshot["type"] == "memory_update"
    assert snapshot["payload"]["memory_id"] == "memory-1"
    assert len(memory_service.long_term_memory) == 1

    confirmed = await confirm_proposal(chat_service, proposed)

    assert confirmed["memory_changes"]["updated"] == 1
    assert confirmed["memory_changes"]["created"] == 0
    assert len(memory_service.long_term_memory) == 1


@pytest.mark.asyncio
async def test_confirm_merges_duplicate_created_between_propose_and_apply():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    proposal = only_proposal(proposed)

    # Another save of the same fact lands before the user confirms.
    await memory_service.save_long_term_memory(
        memory_type="fact",
        content=proposal["body"],
        importance=3,
        metadata={"source": "parallel_save"},
    )
    assert len(memory_service.long_term_memory) == 1

    confirmed = await confirm_proposal(chat_service, proposed)

    changes = confirmed["memory_changes"]
    assert changes["write_proposals"][0]["status"] == "applied"
    assert changes["created"] == 0
    assert changes["merged"] + changes["updated"] == 1
    assert len(memory_service.long_term_memory) == 1
