from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import (
    FakeAIService,
    FakeMemoryExtractionService,
    FakeMemoryService,
)
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_brain_contracts import RexBrainChannel
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


@pytest.mark.asyncio
async def test_simple_memory_asks_confirmation_then_saves_durable_memory():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    extraction_service = FakeMemoryExtractionService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        extraction_service,
        time_context_service=_fixed_time_context_service(),
    )

    confirmation = await chat_service.send_message("My mom's birthday is on the 18th")

    assert confirmation["response"] == "So your mom's birthday is June 18, correct?"
    assert confirmation["memory_changes"]["confirmation_required"] == 1
    assert confirmation["messages"][-1]["content"] == confirmation["response"]
    assert "rex_memory_confirmation" not in confirmation["messages"][-1]["content"]
    assert "rex_memory_confirmation" in memory_service.messages[-1]["content"]
    assert ai_service.messages == []
    assert extraction_service.calls == []

    saved = await chat_service.send_message("yes", confirmation["conversation_id"])

    assert saved["response"] == (
        "Saved. I'll remember that your mom's birthday is June 18."
    )
    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["records"][0]["action"] == "direct_saved"
    assert memory_service.long_term_memory[0]["memory_type"] == "personal_fact"
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert extraction_service.calls == []

    await chat_service.send_message(
        "Do you remember my mom's birthday?",
        confirmation["conversation_id"],
    )

    assert (
        "- personal_fact: User's mom's birthday is June 18."
        in ai_service.messages[0]["content"]
    )
    assert "rex_memory_confirmation" not in str(ai_service.messages)


@pytest.mark.asyncio
async def test_simple_memory_confirmation_works_in_voice_stream():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    confirmation_events = [
        event
        async for event in chat_service.stream_message(
            "My mom's birthday is June 18",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert confirmation_events[0] == {
        "event": "conversation",
        "conversation_id": "conversation-1",
    }
    assert confirmation_events[1] == {
        "event": "token",
        "token": "So your mom's birthday is June 18, correct?",
    }
    assert confirmation_events[-1]["response"] == (
        "So your mom's birthday is June 18, correct?"
    )
    assert "rex_memory_confirmation" not in str(confirmation_events)
    assert ai_service.messages == []

    saved_events = [
        event
        async for event in chat_service.stream_message(
            "correct",
            conversation_id="conversation-1",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert saved_events[-1]["response"] == (
        "Saved. I'll remember that your mom's birthday is June 18."
    )
    assert saved_events[-1]["memory_changes"]["created"] == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )

    follow_up_events = [
        event
        async for event in chat_service.stream_message(
            "Do you remember my mom's birthday?",
            conversation_id="conversation-1",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert follow_up_events[-1]["event"] == "done"
    assert (
        "- personal_fact: User's mom's birthday is June 18."
        in ai_service.messages[0]["content"]
    )


@pytest.mark.asyncio
async def test_simple_memory_rejection_does_not_create_durable_memory():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    confirmation = await chat_service.send_message("My mom's birthday is June 18")
    rejected = await chat_service.send_message("no", confirmation["conversation_id"])

    assert rejected["response"] == "No problem. I won't save that."
    assert rejected["memory_changes"]["skipped"] == 1
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_simple_memory_non_confirmation_continues_normal_chat_without_save():
    ai_service = FakeAIService(response="Rex normal follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    confirmation = await chat_service.send_message("My mom's birthday is June 18")
    follow_up = await chat_service.send_message(
        "Why does that matter?",
        confirmation["conversation_id"],
    )

    assert follow_up["response"] == "Rex normal follow-up"
    assert follow_up["memory_changes"] is None
    assert memory_service.long_term_memory == []
    assert "rex_memory_confirmation" not in str(ai_service.messages)
    assert ai_service.messages[-1]["content"] == "Why does that matter?"
