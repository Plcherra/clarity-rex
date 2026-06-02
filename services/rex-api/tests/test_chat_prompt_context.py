from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import (
    FakeAIService,
    FakeAccountabilityService,
    FakeMemoryService,
    FakeUpload,
)
from app.services.chat_context_service import PROFILE_MEMORY_QUERY
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.prompt_service import (
    ACCOUNTABILITY_CONTEXT_PREFIX,
    FILE_CONTEXT_PREFIX,
    LONG_TERM_MEMORY_PREFIX,
    STRUCTURED_MEMORY_PREFIX,
)
from app.services.time_context_service import TimeContextService


@pytest.mark.asyncio
async def test_chat_service_injects_current_time_for_new_conversation():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    time_context_service = TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: datetime(
            2026,
            5,
            12,
            15,
            30,
            tzinfo=ZoneInfo("America/New_York"),
        ),
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=time_context_service,
    )

    await chat_service.send_message("Hello Rex")

    system_content = ai_service.messages[0]["content"]
    assert "Current time context:" in system_content
    assert "- Clock: Tuesday afternoon (15:30 America/New_York (EDT))" in (
        system_content
    )
    assert "- Date: 2026-05-12" in system_content
    assert "- Weekday: Tuesday" in system_content
    assert "- Time: 15:30" in system_content
    assert "- Timezone: America/New_York (EDT)" in system_content
    assert "Conversation context:" in system_content
    assert "- Conversation ID: conversation-1" in system_content


@pytest.mark.asyncio
async def test_chat_service_injects_session_gap_for_existing_conversation():
    ai_service = FakeAIService()
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
    time_context_service = TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: datetime(
            2026,
            5,
            12,
            15,
            30,
            tzinfo=ZoneInfo("America/New_York"),
        ),
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=time_context_service,
    )

    await chat_service.send_message("What changed?", "conversation-existing")

    system_content = ai_service.messages[0]["content"]
    assert "- Previous message delta: 2 days ago" in system_content
    assert "- Conversation ID: conversation-existing" in system_content
    assert "- Conversation timestamp: 2026-05-10T15:30:00-04:00" in system_content
    assert "- Last message timestamp: 2026-05-10T15:30:00-04:00" in system_content


@pytest.mark.asyncio
async def test_chat_service_injects_time_context_for_streaming_chat():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    time_context_service = TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: datetime(
            2026,
            5,
            12,
            23,
            10,
            tzinfo=ZoneInfo("America/New_York"),
        ),
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=time_context_service,
    )

    events = [
        event async for event in chat_service.stream_message("Hello Rex", file=None)
    ]

    assert events[-1]["event"] == "done"
    system_content = ai_service.messages[0]["content"]
    assert "Current time context:" in system_content
    assert "- Clock: Tuesday night (23:10 America/New_York (EDT))" in system_content


@pytest.mark.asyncio
async def test_chat_service_handles_file_upload():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)
    upload = FakeUpload("notes.md", b"Project notes")

    result = await chat_service.send_message("Read this file", file=upload)

    assert result["response"] == "Rex response"
    assert ai_service.messages[-2]["content"] == (f"{FILE_CONTEXT_PREFIX}Project notes")
    assert ai_service.messages[-1]["content"] == "Read this file"


@pytest.mark.asyncio
async def test_chat_service_includes_long_term_memory():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-1",
            "memory_type": "preference",
            "content": "I prefer concise answers",
            "importance": 4,
        }
    )
    chat_service = ChatService(ai_service, FileService(), memory_service)

    await chat_service.send_message("What should I do next?")

    assert memory_service.relevant_memory_queries == [
        {"query": "What should I do next?", "limit": 8},
        {"query": PROFILE_MEMORY_QUERY, "limit": 4},
    ]
    assert ai_service.messages[0]["role"] == "system"
    assert "Relevant long-term memory" in ai_service.messages[0]["content"]
    assert "- preference: I prefer concise answers" in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_chat_service_includes_profile_memory_for_new_chat_openers():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-location",
            "memory_type": "fact",
            "content": "I am in Massachusetts.",
            "importance": 3,
        }
    )
    chat_service = ChatService(ai_service, FileService(), memory_service)

    await chat_service.send_message("Hey")

    assert memory_service.relevant_memory_queries == [
        {"query": "Hey", "limit": 8},
        {"query": PROFILE_MEMORY_QUERY, "limit": 4},
    ]
    assert "- fact: I am in Massachusetts." in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_chat_service_includes_structured_memory_context():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.structured_context = {
        "entities": [
            {
                "id": "entity-clara",
                "entity_type": "person",
                "display_name": "Clara",
                "relationship": "dating interest from work",
                "summary": "Clara touched my arm.",
                "relevance_reason": "Matched current message terms: clara",
            }
        ]
    }
    chat_service = ChatService(ai_service, FileService(), memory_service)

    await chat_service.send_message("I saw Clara today.")

    assert memory_service.structured_context_queries == ["I saw Clara today."]
    assert ai_service.messages[0]["role"] == "system"
    assert STRUCTURED_MEMORY_PREFIX in ai_service.messages[0]["content"]
    assert "- entity/person Clara - dating interest from work" in (
        ai_service.messages[0]["content"]
    )


@pytest.mark.asyncio
async def test_chat_service_injects_accountability_context():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.structured_context = {
        "personal_rules": [
            {
                "id": "rule-doordash",
                "rule_type": "food_delivery",
                "title": "Avoid DoorDash",
                "rule_text": "Do not order DoorDash while budget is slipping.",
                "priority": 5,
                "status": "active",
                "active": True,
            }
        ]
    }
    memory_service.long_term_memory.append(
        {
            "id": "memory-doordash",
            "memory_type": "event",
            "content": "I committed to stop ordering DoorDash in May.",
            "active": True,
        }
    )
    accountability_service = FakeAccountabilityService(
        signals=[
            {
                "signal_type": "rule_violation",
                "severity": "high",
                "title": "Possible rule violation: Avoid DoorDash",
                "reason": "DoorDash matched an active rule.",
                "suggested_prompt": "This sounds like the same pattern again.",
            }
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        accountability_service=accountability_service,
    )

    await chat_service.send_message("I ordered DoorDash again.")

    assert len(accountability_service.calls) == 1
    call = accountability_service.calls[0]
    assert call["message"] == "I ordered DoorDash again."
    assert call["personal_rules"] == memory_service.structured_context["personal_rules"]
    assert call["relevant_memories"][0]["id"] == "memory-doordash"
    system_content = ai_service.messages[0]["content"]
    assert ACCOUNTABILITY_CONTEXT_PREFIX in system_content
    assert "rule_violation/high: Possible rule violation" in system_content
    assert "This sounds like the same pattern again." in system_content


@pytest.mark.asyncio
async def test_chat_service_injects_accountability_context_for_streaming_chat():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    accountability_service = FakeAccountabilityService(
        signals=[
            {
                "signal_type": "repeated_pattern",
                "severity": "medium",
                "title": "Repeated pattern: delivery food",
                "reason": "Found related recent records.",
            }
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        accountability_service=accountability_service,
    )

    events = [
        event
        async for event in chat_service.stream_message(
            "I ordered DoorDash again.",
            file=None,
        )
    ]

    assert events[-1]["event"] == "done"
    assert len(accountability_service.calls) == 1
    system_content = ai_service.messages[0]["content"]
    assert ACCOUNTABILITY_CONTEXT_PREFIX in system_content
    assert "repeated_pattern/medium: Repeated pattern: delivery food" in system_content


@pytest.mark.asyncio
async def test_chat_service_ignores_accountability_failures():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        accountability_service=FakeAccountabilityService(should_fail=True),
    )

    result = await chat_service.send_message("Hello Rex")

    assert result["response"] == "Rex response"
    assert ACCOUNTABILITY_CONTEXT_PREFIX not in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_chat_service_limits_injected_memory_context():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-1",
            "memory_type": "fact",
            "content": "work " * 1000,
            "importance": 5,
        }
    )
    chat_service = ChatService(ai_service, FileService(), memory_service)

    await chat_service.send_message("I need advice about work.")

    memory_section = ai_service.messages[0]["content"].split(
        LONG_TERM_MEMORY_PREFIX,
        1,
    )[1]
    assert len(memory_section) < 2200
    assert "[truncated]" in ai_service.messages[0]["content"]
