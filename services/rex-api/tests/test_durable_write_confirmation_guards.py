"""Guards around confirming a pending durable write.

Covers the answers that are not a plain confirm-card tap: a typed yes, a
rejection, a newer proposal superseding an older one, and stale or empty
confirmation payloads that must never save.
"""

from __future__ import annotations

import pytest

from app.services.durable_write_pending import pending_action_for_durable_write
from app.services.durable_write_proposal import DurableWriteProposal
from chat_service_fakes import FakeMemoryService
from durable_write_brain_scripts import only_proposal, scripted_chat_service
from scripted_brain_fakes import reply_with_action

SAVE_BRAIN = {
    "mom's birthday": reply_with_action(
        "June 18 — good to know.",
        "save_memory",
        {"content": "User's mom's birthday is June 18.", "memory_type": "fact"},
    ),
    "omen": reply_with_action(
        "An Omen 45L — noted.",
        "save_memory",
        {"content": "User has an Omen 45L PC.", "memory_type": "fact"},
    ),
}


def _chat_service(memory_service: FakeMemoryService):
    return scripted_chat_service(SAVE_BRAIN, memory_service)


def _pc_proposal() -> DurableWriteProposal:
    return DurableWriteProposal(
        write_kind="memory",
        title="User has an Omen 45L PC",
        body="User has an Omen 45L PC.",
        proposal_id="write-current",
        apply_snapshot={
            "type": "memory",
            "payload": {
                "memory_type": "fact",
                "content": "User has an Omen 45L PC.",
                "importance": 4,
                "metadata": {},
            },
        },
    )


@pytest.mark.asyncio
async def test_typed_yes_confirms_the_pending_proposal():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    conversation_id = proposed["conversation_id"]

    confirmed = await chat_service.send_message("Yes", conversation_id=conversation_id)

    assert confirmed["memory_changes"]["created"] == 1
    assert len(memory_service.long_term_memory) == 1
    assert (
        memory_service.long_term_memory[0]["content"]
        == "User's mom's birthday is June 18."
    )
    assert conversation_id not in memory_service.pending_actions
    # The pending confirm is answered by the body, not by a second brain turn.
    assert chat_service.ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_reject_does_not_save():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    conversation_id = proposed["conversation_id"]

    rejected = await chat_service.send_message("No", conversation_id=conversation_id)

    assert rejected["memory_changes"]["skipped"] == 1
    assert memory_service.long_term_memory == []
    assert conversation_id not in memory_service.pending_actions


@pytest.mark.asyncio
async def test_new_save_supersedes_stale_pending_proposal():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    first = await chat_service.send_message("My mom's birthday is June 18")
    conversation_id = first["conversation_id"]

    second = await chat_service.send_message(
        "I also have an Omen 45L PC",
        conversation_id=conversation_id,
    )

    assert second["memory_changes"]["confirmation_required"] == 1
    proposal = only_proposal(second)
    assert "Omen" in proposal["body"]
    assert "mom" not in proposal["body"].lower()
    assert proposal["id"] != only_proposal(first)["id"]
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_write_confirmation_id_mismatch_returns_failure():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    conversation_id = proposed["conversation_id"]
    memory_service.pending_actions[conversation_id] = pending_action_for_durable_write(
        proposal=_pc_proposal(),
    ).to_dict()

    failed = await chat_service.send_message(
        "Yes",
        conversation_id=conversation_id,
        write_confirmation={"proposal_id": "write-stale"},
    )

    assert "no longer current" in failed["response"].lower()
    assert failed["memory_changes"]["write_proposals"][0]["status"] == "failed"
    assert memory_service.long_term_memory == []
    assert conversation_id not in memory_service.pending_actions


@pytest.mark.asyncio
async def test_write_confirmation_empty_dict_does_not_confirm():
    from app.services.durable_write_service import DurableWriteService

    memory_service = FakeMemoryService()
    durable = DurableWriteService(memory_service=memory_service)
    conversation_id = "conversation-empty-confirm"
    pending = pending_action_for_durable_write(proposal=_pc_proposal()).to_dict()
    memory_service.pending_actions[conversation_id] = pending

    result = await durable.try_handle_pending(
        "What time is it?",
        pending_action=pending,
        conversation_id=conversation_id,
        user_message={"id": "u1", "content": "What time is it?"},
        write_confirmation={},
    )

    assert result is None
    assert conversation_id in memory_service.pending_actions
    assert memory_service.long_term_memory == []
