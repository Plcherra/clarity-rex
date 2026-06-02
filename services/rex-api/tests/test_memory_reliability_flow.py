from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import (
    FakeAIService,
    FakeMemoryCandidateService,
    FakeMemoryCorrectionService,
    FakeMemoryExtractionService,
    FakeMemoryService,
)
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.memory_intent_service import MemoryIntentService
from app.services.rex_brain_contracts import RexBrainChannel
from app.services.time_context_service import TimeContextService


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
    memory_candidate_service=None,
    memory_correction_service=None,
    memory_extraction_service=None,
) -> ChatService:
    return ChatService(
        ai_service or FakeAIService(),
        FileService(),
        memory_service or ReliabilityMemoryService(),
        memory_extraction_service
        if memory_extraction_service is not None
        else FakeMemoryExtractionService(),
        time_context_service=_time_context_service(),
        memory_candidate_service=memory_candidate_service,
        memory_correction_service=memory_correction_service,
    )


@pytest.mark.asyncio
async def test_memory_reliability_mom_birthday_confirms_saves_and_recalls():
    ai_service = FakeAIService()
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(
        ai_service=ai_service,
        memory_service=memory_service,
    )

    confirmation = await chat_service.send_message("My mom's birthday is on the 18th")

    assert confirmation["response"] == "So your mom's birthday is June 18, correct?"
    assert confirmation["memory_changes"]["confirmation_required"] == 1
    assert confirmation["memory_changes"]["records"][0]["metadata"]["memory_path"] == (
        "pending_confirmation"
    )
    assert "rex_memory_confirmation" not in str(confirmation["messages"])
    assert memory_service.memory_confirmations[0]["status"] == "pending"

    saved = await chat_service.send_message("yes", confirmation["conversation_id"])

    assert saved["response"] == (
        "Saved. I'll remember that your mom's birthday is June 18."
    )
    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["records"][0]["action"] == "direct_saved"
    assert saved["memory_changes"]["records"][0]["metadata"]["memory_path"] == (
        "direct_save"
    )
    assert memory_service.memory_confirmations[0]["status"] == "confirmed"
    assert len(memory_service.long_term_memory) == 1

    await chat_service.send_message(
        "Do you remember my mom's birthday?",
        confirmation["conversation_id"],
    )

    assert (
        "- fact: User's mom's birthday is June 18."
        in ai_service.messages[0]["content"]
    )


@pytest.mark.asyncio
async def test_memory_reliability_rejection_does_not_save_or_recall():
    ai_service = FakeAIService()
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(
        ai_service=ai_service,
        memory_service=memory_service,
    )

    confirmation = await chat_service.send_message("My mom's birthday is June 18")
    rejected = await chat_service.send_message("no", confirmation["conversation_id"])
    await chat_service.send_message(
        "Do you remember my mom's birthday?",
        confirmation["conversation_id"],
    )

    assert rejected["response"] == "No problem. I won't save that."
    assert memory_service.memory_confirmations[0]["status"] == "rejected"
    assert memory_service.long_term_memory == []
    assert "mom's birthday" not in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_memory_reliability_duplicate_fact_does_not_create_duplicate_records():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    confirmation = await chat_service.send_message("My mom's birthday is on the 18th")
    repeated = await chat_service.send_message(
        "My mom's birthday is June 18",
        confirmation["conversation_id"],
    )
    saved = await chat_service.send_message("yes", confirmation["conversation_id"])
    already_saved = await chat_service.send_message(
        "My mom's birthday is on June 18",
        confirmation["conversation_id"],
    )

    assert repeated["response"] == "So your mom's birthday is June 18, correct?"
    assert len(memory_service.memory_confirmations) == 1
    assert saved["memory_changes"]["created"] == 1
    assert already_saved["response"] == "I already have that saved."
    assert len(memory_service.long_term_memory) == 1


@pytest.mark.asyncio
async def test_memory_reliability_correction_becomes_pending_review_not_direct_save():
    memory_service = ReliabilityMemoryService()
    memory_service.conversations.add("conversation-existing")
    candidate_service = FakeMemoryCandidateService()
    correction_service = FakeMemoryCorrectionService(payload={"applied": False})
    chat_service = _chat_service(
        memory_service=memory_service,
        memory_candidate_service=candidate_service,
        memory_correction_service=correction_service,
    )

    result = await chat_service.send_message(
        "Replace Flowfirst with FlowForce",
        "conversation-existing",
    )

    assert result["memory_correction"]["requires_confirmation"] is True
    assert result["memory_correction"]["memory_path"] == "pending_review"
    assert len(candidate_service.created) == 1
    candidate = candidate_service.created[0]
    assert candidate["candidate_type"] == "correction"
    assert candidate["risk_level"] == "high"
    assert candidate["payload"]["metadata"]["memory_path"] == "pending_review"
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_memory_reliability_voice_stream_saves_and_recalls_memory():
    ai_service = FakeAIService()
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(
        ai_service=ai_service,
        memory_service=memory_service,
    )

    confirmation_events = [
        event
        async for event in chat_service.stream_message(
            "My mom's birthday is June 18",
            channel=RexBrainChannel.VOICE,
        )
    ]
    saved_events = [
        event
        async for event in chat_service.stream_message(
            "correct",
            conversation_id="conversation-1",
            channel=RexBrainChannel.VOICE,
        )
    ]
    recall_events = [
        event
        async for event in chat_service.stream_message(
            "Do you remember my mom's birthday?",
            conversation_id="conversation-1",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert confirmation_events[-1]["response"] == (
        "So your mom's birthday is June 18, correct?"
    )
    assert saved_events[-1]["response"] == (
        "Saved. I'll remember that your mom's birthday is June 18."
    )
    assert recall_events[-1]["event"] == "done"
    assert (
        "- fact: User's mom's birthday is June 18."
        in ai_service.messages[0]["content"]
    )


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


@pytest.mark.asyncio
async def test_memory_reliability_old_hidden_marker_confirmation_still_migrates():
    memory_service = ReliabilityMemoryService()
    memory_service.conversations.add("conversation-existing")
    intent_service = MemoryIntentService()
    intent = intent_service.detect_simple_memory(
        "My mom's birthday is June 18",
        time_context={"date": "2026-06-01"},
    )
    marked_response = intent_service.with_confirmation_marker(
        "So your mom's birthday is June 18, correct?",
        intent,
    )
    await memory_service.save_message(
        "conversation-existing",
        "user",
        "My mom's birthday is June 18",
    )
    await memory_service.save_message(
        "conversation-existing",
        "assistant",
        marked_response,
    )
    chat_service = _chat_service(memory_service=memory_service)

    saved = await chat_service.send_message("yes", "conversation-existing")

    assert saved["response"] == (
        "Saved. I'll remember that your mom's birthday is June 18."
    )
    assert len(memory_service.long_term_memory) == 1
    assert "rex_memory_confirmation" not in str(saved["messages"])
