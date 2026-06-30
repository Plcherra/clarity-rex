"""Durable write proposal flow — propose, confirm, apply from frozen snapshot."""

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import FakeAIService, FakeMemoryService
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService


def _fixed_time_context_service():
    return TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: datetime(
            2026,
            6,
            1,
            12,
            0,
            tzinfo=ZoneInfo("America/New_York"),
        ),
    )


def _chat_service(memory_service: FakeMemoryService | None = None) -> ChatService:
    return ChatService(
        FakeAIService(),
        FileService(),
        memory_service or FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )


@pytest.mark.asyncio
async def test_simple_memory_requires_confirmation_before_save():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")

    assert proposed["memory_changes"]["confirmation_required"] == 1
    assert proposed["memory_changes"]["created"] == 0
    assert len(proposed["memory_changes"]["write_proposals"]) == 1
    assert proposed["memory_changes"]["write_proposals"][0]["write_kind"] == "memory"
    assert memory_service.long_term_memory == []
    assert chat_service.ai_service.messages == []


@pytest.mark.asyncio
async def test_simple_memory_confirm_applies_frozen_snapshot():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    conversation_id = proposed["conversation_id"]
    proposal = proposed["memory_changes"]["write_proposals"][0]

    confirmed = await chat_service.send_message(
        "Yes",
        conversation_id=conversation_id,
        write_confirmation={
            "proposal_id": proposal["id"],
            "edits": {"title": proposal["title"], "body": proposal["body"]},
        },
    )

    assert confirmed["memory_changes"]["created"] == 1
    assert confirmed["memory_changes"]["confirmation_required"] == 0
    assert len(memory_service.long_term_memory) == 1
    assert memory_service.long_term_memory[0]["content"] == proposal["body"]


@pytest.mark.asyncio
async def test_explicit_goal_requires_confirmation_before_save():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message(
        "Track save $5000 by August as a goal"
    )

    assert proposed["memory_changes"]["confirmation_required"] == 1
    assert proposed["memory_changes"]["write_proposals"][0]["write_kind"] == "plan"
    assert memory_service.plans == []


@pytest.mark.asyncio
async def test_explicit_goal_confirm_creates_plan():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message(
        "Track save $5000 by August as a goal"
    )
    conversation_id = proposed["conversation_id"]
    proposal = proposed["memory_changes"]["write_proposals"][0]

    confirmed = await chat_service.send_message(
        "Yes",
        conversation_id=conversation_id,
        write_confirmation={"proposal_id": proposal["id"]},
    )

    assert confirmed["memory_changes"]["created"] == 1
    assert len(memory_service.plans) == 1


@pytest.mark.asyncio
async def test_durable_write_reject_does_not_save():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    conversation_id = proposed["conversation_id"]

    rejected = await chat_service.send_message("No", conversation_id=conversation_id)

    assert rejected["memory_changes"]["skipped"] == 1
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_birthday_with_it_is_requires_confirmation():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message(
        "Can you remember my mom's birthday it's June 18?"
    )

    assert proposed["memory_changes"]["confirmation_required"] == 1
    assert proposed["memory_changes"]["created"] == 0
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_new_save_supersedes_stale_pending_proposal():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    first = await chat_service.send_message("My mom's birthday is June 18")
    conversation_id = first["conversation_id"]

    second = await chat_service.send_message(
        "Save that I have an Omen 45L PC",
        conversation_id=conversation_id,
    )

    assert second["memory_changes"]["confirmation_required"] == 1
    proposal = second["memory_changes"]["write_proposals"][0]
    assert "Omen" in proposal["body"] or "PC" in proposal["body"]
    assert "mom" not in proposal["body"].lower()


@pytest.mark.asyncio
async def test_yes_after_recall_save_offer_proposes_pc():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(conversation_id, "user", "Can you save my PC model?")
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "Sure, what's the model?",
    )
    await memory_service.save_message(
        conversation_id,
        "user",
        "Search into our old chats",
    )
    await memory_service.save_message(
        conversation_id,
        "assistant",
        (
            "From our old chats, you mentioned having an Omen 45L PC. "
            "Want me to save that to Clarity Knows?"
        ),
    )

    proposed = await chat_service.send_message("Yes", conversation_id=conversation_id)

    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = proposed["memory_changes"]["write_proposals"][0]
    assert "Omen" in proposal["body"] or "PC" in proposal["body"]
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_confirm_with_edits_applies_edited_body():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    conversation_id = proposed["conversation_id"]
    proposal = proposed["memory_changes"]["write_proposals"][0]

    confirmed = await chat_service.send_message(
        "Yes",
        conversation_id=conversation_id,
        write_confirmation={
            "proposal_id": proposal["id"],
            "edits": {
                "title": "Mom's birthday",
                "body": "User's mom's birthday is June 18.",
            },
        },
    )

    assert confirmed["memory_changes"]["created"] == 1
    assert len(memory_service.long_term_memory) == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    applied = confirmed["memory_changes"]["write_proposals"][0]
    assert applied["status"] == "applied"
    assert applied["result"]
    assert applied["result"][0]["action"] == "direct_saved"
