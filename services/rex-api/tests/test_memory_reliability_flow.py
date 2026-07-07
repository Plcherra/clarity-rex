from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import (
    FakeAIService,
    FakeMemoryService,
)
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_channel import RexBrainChannel
from app.services.time_context_service import TimeContextService
from durable_write_test_helpers import assert_companion_continuation_response, confirm_durable_write


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


class ReliabilityMemoryService(FakeMemoryService):
    def __init__(self):
        super().__init__()
        self.voice_turns = []

    async def get_relevant_memories(self, query, limit=8):
        self.relevant_memory_queries.append({"query": query, "limit": limit})
        active = [
            memory
            for memory in self.long_term_memory
            if memory.get("active", True) is True
        ]
        return active[-limit:]

    async def save_voice_turn(self, **payload):
        voice_turn = {"id": f"voice-turn-{len(self.voice_turns) + 1}", **payload}
        self.voice_turns.append(voice_turn)
        return voice_turn


def _chat_service(
    *,
    ai_service=None,
    memory_service=None,
) -> ChatService:
    return ChatService(
        ai_service or FakeAIService(),
        FileService(),
        memory_service or ReliabilityMemoryService(),
        time_context_service=_time_context_service(),
    )


@pytest.mark.asyncio
async def test_memory_reliability_mom_birthday_saves_and_recalls_directly():
    ai_service = FakeAIService()
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(
        ai_service=ai_service,
        memory_service=memory_service,
    )

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    saved = await confirm_durable_write(chat_service, proposed)

    assert_companion_continuation_response(saved)
    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["confirmation_required"] == 0
    assert len(memory_service.long_term_memory) == 1

    await chat_service.send_message(
        "Do you remember my mom's birthday?",
        saved["conversation_id"],
    )

    assert "- fact: User's mom's birthday is June 18." in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_memory_reliability_rejection_does_not_save_or_recall():
    ai_service = FakeAIService()
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(
        ai_service=ai_service,
        memory_service=memory_service,
    )

    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        conversation_id,
        "user",
        "My mom's birthday is June 18.",
    )
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "Want me to remember that?",
    )

    rejected = await chat_service.send_message("no don't save that", conversation_id)
    await chat_service.send_message(
        "Do you remember my mom's birthday?",
        conversation_id,
    )

    assert rejected["response"] == "Rex response"
    assert rejected["memory_changes"]["skipped"] == 1
    assert memory_service.long_term_memory == []
    assert ai_service.generate_calls >= 1
    assert "mom's birthday" not in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_memory_reliability_duplicate_fact_does_not_create_duplicate_records():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    saved = await confirm_durable_write(chat_service, proposed)
    repeated = await chat_service.send_message(
        "My mom's birthday is June 18",
        saved["conversation_id"],
    )

    assert saved["memory_changes"]["created"] == 1
    assert repeated["response"] == "I already have that saved."
    assert repeated["memory_changes"]["skipped"] == 1
    assert len(memory_service.long_term_memory) == 1


@pytest.mark.asyncio
async def test_memory_reliability_simple_correction_updates_directly():
    memory_service = ReliabilityMemoryService()
    memory_service.conversations.add("conversation-existing")
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
    chat_service = _chat_service(memory_service=memory_service)

    proposed = await chat_service.send_message(
        "My mom's birthday is June 28",
        "conversation-existing",
    )
    assert proposed["memory_changes"]["confirmation_required"] == 1
    result = await confirm_durable_write(chat_service, proposed)

    assert result["memory_correction"] is None
    assert result["memory_changes"]["updated"] == 1
    assert result["memory_changes"]["confirmation_required"] == 0
    assert len(memory_service.long_term_memory) == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 28."
    )


@pytest.mark.asyncio
async def test_memory_reliability_voice_stream_saves_and_recalls_memory():
    ai_service = FakeAIService()
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(
        ai_service=ai_service,
        memory_service=memory_service,
    )

    proposed_events = [
        event
        async for event in chat_service.stream_message(
            "My mom's birthday is June 18",
            channel=RexBrainChannel.VOICE,
        )
    ]
    assert proposed_events[-1]["memory_changes"]["confirmation_required"] == 1
    confirmed_events = [
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
    recall_events = [
        event
        async for event in chat_service.stream_message(
            "Do you remember my mom's birthday?",
            conversation_id=proposed_events[-1]["conversation_id"],
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert_companion_continuation_response(confirmed_events[-1])
    assert confirmed_events[-1]["memory_changes"]["created"] == 1
    assert recall_events[-1]["event"] == "done"
    assert "- fact: User's mom's birthday is June 18." in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_memory_reliability_voice_metadata_is_best_effort_and_persisted_when_available():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    saved = await chat_service.save_voice_turn_metadata(
        conversation_id="conversation-1",
        user_message_id="message-user",
        assistant_message_id="message-assistant",
        transcript_confidence=0.91,
        audio_duration_seconds=4.2,
        input_mime_type="audio/m4a",
        output_audio_encoding="mp3",
        metadata={"channel": "voice"},
    )

    assert saved["id"] == "voice-turn-1"
    assert memory_service.voice_turns[0]["transcript_confidence"] == 0.91
    assert memory_service.voice_turns[0]["metadata"] == {"channel": "voice"}


@pytest.mark.asyncio
async def test_memory_reliability_archived_memory_is_not_recalled():
    ai_service = FakeAIService()
    memory_service = ReliabilityMemoryService()
    memory_service.conversations.add("conversation-existing")
    memory_service.long_term_memory.append(
        {
            "id": "memory-archived",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "active": False,
        }
    )
    chat_service = _chat_service(
        ai_service=ai_service,
        memory_service=memory_service,
    )

    await chat_service.send_message(
        "Do you remember my mom's birthday?",
        "conversation-existing",
    )

    assert "mom's birthday is June 18" not in ai_service.messages[0]["content"]
