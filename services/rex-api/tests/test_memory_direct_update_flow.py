from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_channel import RexBrainChannel
from app.services.time_context_service import TimeContextService
from chat_service_fakes import (
    FakeAIService,
    FakeMemoryService,
)
from memory_turn_fakes import FakeMemoryTurnStore
from durable_write_test_helpers import (
    assert_companion_continuation_response,
    assert_mom_birthday_person_entity,
    confirm_durable_write,
)
from app.services.memory_turn_service import MemoryTurnService


def _time_context_service() -> TimeContextService:
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


def _seed_mom_birthday(memory_service: FakeMemoryService) -> None:
    memory_service.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "active": True,
            "metadata": {
                "memory_path": "direct_save",
                "review_required": False,
                "topic_fingerprint": "fact:birthday:mom",
                "fact_kind": "birthday",
                "entity_label": "mom",
                "normalized_date": "June 18",
            },
        }
    )


@pytest.mark.asyncio
async def test_memory_turn_updates_existing_simple_fact_without_duplicate():
    store = FakeMemoryTurnStore()
    _seed_mom_birthday(store)
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "My mom's birthday is June 28",
        conversation_id="conversation-1",
        user_message={
            "id": "message-correction",
            "content": "My mom's birthday is June 28",
        },
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == (
        "Got it, I updated that: your mom's birthday is June 28."
    )
    assert result["memory_changes"]["created"] == 0
    assert result["memory_changes"]["updated"] == 1
    assert result["memory_changes"]["records"][0]["action"] == "direct_updated"
    assert len(store.long_term_memory) == 1
    assert store.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 28."
    )


@pytest.mark.asyncio
async def test_contextual_date_correction_updates_existing_simple_fact():
    store = FakeMemoryTurnStore()
    _seed_mom_birthday(store)
    store.messages.extend(
        [
            {
                "id": "message-1",
                "conversation_id": "conversation-1",
                "role": "user",
                "content": "Maybe her birthday?",
            },
            {
                "id": "message-2",
                "conversation_id": "conversation-1",
                "role": "assistant",
                "content": "Sure, what's the date? I'll add it.",
            },
            {
                "id": "message-3",
                "conversation_id": "conversation-1",
                "role": "user",
                "content": "June 18",
            },
            {
                "id": "message-4",
                "conversation_id": "conversation-1",
                "role": "assistant",
                "content": "Got it, mom's birthday June 18. Saving that.",
            },
        ]
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "No, it's June 28",
        conversation_id="conversation-1",
        user_message={"id": "message-5", "content": "No, it's June 28"},
        conversation_history=store.messages,
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["memory_changes"]["records"][0]["action"] == "direct_updated"
    assert len(store.long_term_memory) == 1
    assert store.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 28."
    )


@pytest.mark.asyncio
async def test_chat_simple_fact_correction_updates_directly():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    _seed_mom_birthday(memory_service)
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_time_context_service(),
    )

    proposed = await chat_service.send_message("My mom's birthday is June 28")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    result = await confirm_durable_write(chat_service, proposed)

    assert_companion_continuation_response(result)
    assert result["memory_changes"]["updated"] == 1
    assert result["memory_changes"]["confirmation_required"] == 0
    assert ai_service.generate_calls == 1
    assert_mom_birthday_person_entity(memory_service, "June 28")


@pytest.mark.asyncio
async def test_voice_simple_fact_correction_updates_directly():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    _seed_mom_birthday(memory_service)
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_time_context_service(),
    )

    proposed_events = [
        event
        async for event in chat_service.stream_message(
            "My mom's birthday is June 28",
            channel=RexBrainChannel.VOICE,
        )
    ]
    assert proposed_events[-1]["memory_changes"]["confirmation_required"] == 1
    events = [
        event
        async for event in chat_service.stream_message(
            "Yes",
            conversation_id=proposed_events[-1]["conversation_id"],
            channel=RexBrainChannel.VOICE,
            write_confirmation={
                "proposal_id": proposed_events[-1]["memory_changes"]["write_proposals"][0]["id"]
            },
        )
    ]

    assert events[-1]["memory_changes"]["updated"] == 1
    assert events[-1]["memory_changes"]["confirmation_required"] == 0
    assert ai_service.generate_calls == 1
    assert_mom_birthday_person_entity(memory_service, "June 28")
