"""What actually reaches Grok on a base turn: tiny system + thin state.

Plan 05 replaced the always-on prompt sections (saved-memory dump, structured
Knows, accountability signals, finance) with a tiny system prompt plus
fetch-on-demand capabilities. These tests pin the base turn to that small
shape, because the token budget depends on it, and they pin the two pieces of
per-turn state that must still reach Grok: the clock and any attachment.
"""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.prompt_service import (
    ACCOUNTABILITY_CONTEXT_PREFIX,
    CONVERSATION_CONTEXT_PREFIX,
    LONG_TERM_MEMORY_PREFIX,
    STRUCTURED_MEMORY_PREFIX,
    TIME_CONTEXT_PREFIX,
)
from app.services.rex_channel import RexBrainChannel
from chat_service_fakes import FakeMemoryService, FakeUpload
from scripted_brain_fakes import ScriptedAIService, fixed_time_context_service

FINANCIAL_CONTEXT = {
    "schema": "clarity_unified_financial_context_v1",
    "cash_flow": {"spent_this_month": 100},
}


NOW = datetime(2026, 5, 12, 15, 30, tzinfo=ZoneInfo("America/New_York"))


def _chat_service(
    ai_service: ScriptedAIService,
    memory_service: FakeMemoryService,
) -> ChatService:
    return ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=fixed_time_context_service(NOW),
    )


def _saved_memory_fixture(memory_service: FakeMemoryService) -> None:
    memory_service.long_term_memory.append(
        {
            "id": "memory-1",
            "memory_type": "preference",
            "content": "I prefer concise answers",
            "importance": 4,
            "active": True,
        }
    )
    memory_service.structured_context = {
        "entities": [
            {
                "id": "entity-clara",
                "entity_type": "person",
                "display_name": "Clara",
                "relationship": "dating interest from work",
                "summary": "Clara touched my arm.",
            }
        ]
    }


@pytest.mark.asyncio
async def test_base_turn_carries_truth_gate_and_capability_names():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    await chat_service.send_message("Hello Rex")

    system_content = ai_service.prompts[-1]
    assert "Truth Rule:" in system_content
    assert "Auto Suggestions:" in system_content
    assert "Capability names (body executes after Auto Suggestions gate):" in (
        system_content
    )
    assert "save_memory" in system_content
    assert "search_chats" in system_content
    assert "just_chat" in system_content
    assert "create_transaction" not in system_content


@pytest.mark.asyncio
async def test_base_turn_keeps_saved_memory_and_chat_history_labels_apart():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    await chat_service.send_message("What do you know about me?")

    system_content = ai_service.prompts[-1]
    assert "Saved memory: an explicit fact saved to What Clarity Knows." in (
        system_content
    )
    assert (
        "Chat history: searchable past messages; not saved memory unless the "
        "user explicitly saved it."
    ) in system_content
    assert "Do not call chat search results 'saved memory'." in system_content


@pytest.mark.asyncio
async def test_base_turn_sends_recent_turns_as_thin_state():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    first = await chat_service.send_message("Hello Rex")
    await chat_service.send_message("What changed?", first["conversation_id"])

    assert [message["role"] for message in ai_service.messages] == [
        "system",
        "user",
        "assistant",
        "user",
    ]
    assert ai_service.messages[1:] == [
        {"role": "user", "content": "Hello Rex"},
        {"role": "assistant", "content": "Rex response"},
        {"role": "user", "content": "What changed?"},
    ]


@pytest.mark.asyncio
async def test_base_turn_never_dumps_saved_memory_or_structured_knows():
    ai_service = ScriptedAIService()
    memory_service = FakeMemoryService()
    _saved_memory_fixture(memory_service)
    chat_service = _chat_service(ai_service, memory_service)

    await chat_service.send_message("What do you remember about my preferences?")

    system_content = ai_service.prompts[-1]
    assert memory_service.relevant_memory_queries == []
    assert memory_service.structured_context_queries == []
    assert LONG_TERM_MEMORY_PREFIX not in system_content
    assert STRUCTURED_MEMORY_PREFIX not in system_content
    assert ACCOUNTABILITY_CONTEXT_PREFIX not in system_content
    assert "I prefer concise answers" not in system_content
    assert "Clara" not in system_content


@pytest.mark.asyncio
async def test_base_turn_carries_the_clock_but_no_conversation_metadata():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    await chat_service.send_message("What day is it?")

    system_content = ai_service.prompts[-1]
    assert TIME_CONTEXT_PREFIX in system_content
    assert "- Date: 2026-05-12" in system_content
    assert "- Clock: Tuesday afternoon (15:30" in system_content
    assert CONVERSATION_CONTEXT_PREFIX not in system_content


@pytest.mark.asyncio
async def test_base_turn_reports_the_gap_since_the_previous_message():
    ai_service = ScriptedAIService()
    memory_service = FakeMemoryService()
    memory_service.conversations.add("conversation-existing")
    memory_service.messages.append(
        {
            "id": "message-existing",
            "conversation_id": "conversation-existing",
            "role": "assistant",
            "content": "Previous response",
            "timestamp": "2026-05-10T15:30:00-04:00",
        }
    )
    chat_service = _chat_service(ai_service, memory_service)

    await chat_service.send_message("What changed?", "conversation-existing")

    system_content = ai_service.prompts[-1]
    assert "- Previous message delta: 2 days ago" in system_content
    assert "conversation-existing" not in system_content


@pytest.mark.asyncio
async def test_attached_financial_context_never_enters_the_base_prompt():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    await chat_service.send_message(
        "Can you check anything you have about my mom?",
        financial_context=FINANCIAL_CONTEXT,
    )

    system_content = ai_service.prompts[-1]
    assert "Clarity financial summary:" not in system_content
    assert "spent_this_month" not in system_content
    assert "fetch_spend_insight" in system_content


@pytest.mark.asyncio
async def test_open_thread_titles_are_added_to_the_thin_state():
    ai_service = ScriptedAIService()
    memory_service = FakeMemoryService()
    memory_service.open_threads.append(
        {
            "id": "thread-1",
            "title": "Wake up at 4am",
            "status": "active",
            "summary": "Morning routine",
        }
    )
    chat_service = _chat_service(ai_service, memory_service)

    await chat_service.send_message("How am I doing?")

    system_content = ai_service.prompts[-1]
    assert "thread-1: Wake up at 4am" in system_content
    assert "Morning routine" in system_content


@pytest.mark.asyncio
async def test_streaming_turn_builds_the_same_tiny_system_prompt():
    ai_service = ScriptedAIService()
    memory_service = FakeMemoryService()
    _saved_memory_fixture(memory_service)
    chat_service = _chat_service(ai_service, memory_service)

    events = [
        event
        async for event in chat_service.stream_message(
            "Hello Rex",
            file=None,
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert events[-1]["event"] == "done"
    system_content = ai_service.prompts[-1]
    assert "Truth Rule:" in system_content
    assert TIME_CONTEXT_PREFIX in system_content
    assert LONG_TERM_MEMORY_PREFIX not in system_content
    assert "I prefer concise answers" not in system_content


@pytest.mark.asyncio
async def test_uploaded_text_file_reaches_grok_with_the_question():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    await chat_service.send_message(
        "Read this file",
        file=FakeUpload("notes.md", b"Project notes"),
    )

    assert ai_service.messages[-2]["content"] == (
        "Attached file notes.md:\nProject notes"
    )
    assert ai_service.messages[-1]["content"] == "Read this file"


@pytest.mark.asyncio
async def test_uploaded_image_reaches_grok_as_multimodal_content():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    await chat_service.send_message(
        "What is in this image?",
        file=FakeUpload("receipt.png", b"image-bytes", content_type="image/png"),
    )

    assert ai_service.messages[-1]["content"] == [
        {"type": "text", "text": "What is in this image?"},
        {
            "type": "image_url",
            "image_url": {
                "url": "data:image/png;base64,aW1hZ2UtYnl0ZXM=",
                "detail": "auto",
            },
        },
    ]


@pytest.mark.asyncio
async def test_image_without_a_question_still_asks_grok_to_look():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    await chat_service.send_message(
        "",
        file=FakeUpload("games.png", b"image-bytes", content_type="image/png"),
    )

    assert ai_service.messages[-1]["content"][0] == {
        "type": "text",
        "text": "Please look at this image.",
    }


@pytest.mark.asyncio
async def test_oversized_attachment_is_capped_before_it_reaches_grok():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    await chat_service.send_message(
        "Summarize this",
        file=FakeUpload("long.txt", b"x" * 40_000),
    )

    attachment_message = ai_service.messages[-2]["content"]
    assert len(attachment_message) < 13_000
    assert attachment_message.endswith("[Attachment truncated for this turn.]")


@pytest.mark.asyncio
async def test_base_turn_input_stays_inside_the_token_budget():
    ai_service = ScriptedAIService()
    chat_service = _chat_service(ai_service, FakeMemoryService())

    await chat_service.send_message("Hello Rex")

    # ~4 chars per token: a base turn aims to stay under ~1k input tokens.
    base_chars = sum(len(message["content"]) for message in ai_service.messages)
    assert base_chars < 4000
