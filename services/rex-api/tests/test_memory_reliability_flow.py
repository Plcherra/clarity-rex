"""Memory reliability once Grok has asked the body to write.

Grok decides that a turn saves something; the body must then never lose the
write, never duplicate a fact it already holds, and never claim success it did
not get. The brain is scripted here so each test exercises the body contract
rather than any wording of the user's message.
"""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.memory_service import SupabaseMemoryService
from app.services.rex_channel import RexBrainChannel
from chat_service_fakes import FakeMemoryService
from durable_write_test_helpers import confirm_durable_write
from memory_persist_assertions import assert_person_card_covers
from scripted_brain_fakes import (
    ScriptedAIService,
    fixed_time_context_service,
    reply_with_action,
)

MOM_BIRTHDAY = "User's mom's birthday is June 18."
MOM_BIRTHDAY_CORRECTED = "User's mom's birthday is June 28."

SAVE_BRAIN = {
    "birthday is on the 18th": reply_with_action(
        "June 18 — good to know.",
        "save_memory",
        {"content": MOM_BIRTHDAY, "memory_type": "fact", "importance": 5},
    ),
    "birthday is june 28": reply_with_action(
        "June 28 then.",
        "save_memory",
        {"content": MOM_BIRTHDAY_CORRECTED, "memory_type": "fact", "importance": 5},
    ),
    "mom is ariadyna": reply_with_action(
        "I can save Ariadyna as your mom.",
        "save_person",
        {
            "display_name": "Ariadyna",
            "relationship": "mom",
            "birthday": "June 18",
            "importance": 5,
        },
    ),
    "don't save that": "No problem, I won't save that.",
}


class ReliabilityMemoryService(FakeMemoryService):
    def __init__(self):
        super().__init__()
        self.voice_turns = []

    async def save_voice_turn(self, **payload):
        voice_turn = {"id": f"voice-turn-{len(self.voice_turns) + 1}", **payload}
        self.voice_turns.append(voice_turn)
        return voice_turn


class RecallRankingStore(SupabaseMemoryService):
    """Real retrieval ranking over whatever the chat turn actually persisted."""

    def __init__(self, memories):
        self.memories = memories

    async def list_long_term_memory(self, limit=50, memory_type=None, active=None):
        memories = self.memories
        if active is not None:
            memories = [
                memory for memory in memories if memory.get("active", True) is active
            ]
        if memory_type is not None:
            memories = [
                memory
                for memory in memories
                if memory.get("memory_type") == memory_type
            ]
        return memories[:limit]


def _chat_service(
    *,
    ai_service=None,
    memory_service=None,
) -> ChatService:
    return ChatService(
        ai_service or ScriptedAIService(SAVE_BRAIN),
        FileService(),
        memory_service or ReliabilityMemoryService(),
        time_context_service=fixed_time_context_service(),
    )


def _active_memories(memory_service) -> list[dict]:
    return [
        memory
        for memory in memory_service.long_term_memory
        if memory.get("active", True) is True
    ]


@pytest.mark.asyncio
async def test_confirmed_save_lands_in_knows_and_reports_created():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    assert memory_service.long_term_memory == []

    saved = await confirm_durable_write(chat_service, proposed)

    assert saved["response"] == f"Saved to Clarity Knows: {MOM_BIRTHDAY}"
    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["confirmation_required"] == 0
    assert [memory["content"] for memory in _active_memories(memory_service)] == [
        MOM_BIRTHDAY
    ]


@pytest.mark.asyncio
async def test_confirmed_person_save_becomes_a_person_card():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    proposed = await chat_service.send_message("My mom is Ariadyna")
    person_card = proposed["memory_changes"]["write_proposals"][0]["person_card"]
    assert person_card["display_name"] == "Ariadyna"
    assert person_card["relationship"] == "mother"

    saved = await confirm_durable_write(chat_service, proposed)

    assert saved["memory_changes"]["created"] == 1
    assert_person_card_covers(
        memory_service,
        relationship="mother",
        display_name_contains="Ariadyna",
        flat_content_gone="User's mother is Ariadyna",
    )


@pytest.mark.asyncio
async def test_turn_without_a_brain_action_saves_nothing():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    turn = await chat_service.send_message("No, don't save that")

    assert turn["response"] == "No problem, I won't save that."
    assert turn["memory_changes"] is None
    assert memory_service.long_term_memory == []
    assert memory_service.entities == []


@pytest.mark.asyncio
async def test_repeating_a_saved_fact_updates_instead_of_duplicating():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    saved = await confirm_durable_write(chat_service, proposed)
    assert saved["memory_changes"]["created"] == 1

    repeated = await chat_service.send_message(
        "My mom's birthday is on the 18th",
        saved["conversation_id"],
    )
    reconfirmed = await confirm_durable_write(chat_service, repeated)

    assert reconfirmed["response"] == f"Updated Clarity Knows: {MOM_BIRTHDAY}"
    assert reconfirmed["memory_changes"]["created"] == 0
    assert reconfirmed["memory_changes"]["updated"] == 1
    assert [memory["content"] for memory in _active_memories(memory_service)] == [
        MOM_BIRTHDAY
    ]


@pytest.mark.asyncio
async def test_corrected_fact_updates_the_existing_record():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    saved = await confirm_durable_write(chat_service, proposed)

    corrected = await chat_service.send_message(
        "My mom's birthday is June 28",
        saved["conversation_id"],
    )
    applied = await confirm_durable_write(chat_service, corrected)

    assert applied["memory_correction"] is None
    assert applied["memory_changes"]["updated"] == 1
    assert applied["memory_changes"]["confirmation_required"] == 0
    remaining = _active_memories(memory_service)
    assert [memory["content"] for memory in remaining] == [MOM_BIRTHDAY_CORRECTED]
    assert remaining[0]["metadata"]["previous_content"] == MOM_BIRTHDAY


@pytest.mark.asyncio
async def test_failed_write_reports_honestly_and_saves_nothing():
    memory_service = ReliabilityMemoryService()

    async def failing_save(*args, **kwargs):
        raise RuntimeError("supabase unavailable")

    chat_service = _chat_service(memory_service=memory_service)
    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    memory_service.save_long_term_memory = failing_save

    failed = await confirm_durable_write(chat_service, proposed)

    assert "couldn't save it just now" in failed["response"]
    assert "Saved to Clarity Knows" not in failed["response"]
    changes = failed["memory_changes"]
    assert changes["created"] == 0
    assert changes["updated"] == 0
    assert changes["write_proposals"][0]["status"] == "failed"
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_saved_fact_is_findable_by_the_recall_ranker():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    await confirm_durable_write(chat_service, proposed)

    ranker = RecallRankingStore(memory_service.long_term_memory)
    found = await ranker.get_relevant_memories(
        "Do you remember my mom's birthday?",
        limit=3,
    )

    assert [memory["content"] for memory in found] == [MOM_BIRTHDAY]
    assert "birthday" in found[0]["relevance_reason"]


@pytest.mark.asyncio
async def test_voice_stream_uses_the_same_write_proposal_confirm_path():
    memory_service = ReliabilityMemoryService()
    chat_service = _chat_service(memory_service=memory_service)

    proposed_events = [
        event
        async for event in chat_service.stream_message(
            "My mom's birthday is on the 18th",
            channel=RexBrainChannel.VOICE,
        )
    ]
    proposed_changes = proposed_events[-1]["memory_changes"]
    assert proposed_changes["confirmation_required"] == 1
    assert memory_service.long_term_memory == []

    confirmed_events = [
        event
        async for event in chat_service.stream_message(
            "Yes",
            conversation_id=proposed_events[-1]["conversation_id"],
            channel=RexBrainChannel.VOICE,
            write_confirmation={
                "proposal_id": proposed_changes["write_proposals"][0]["id"]
            },
        )
    ]

    confirmed = confirmed_events[-1]
    assert confirmed["event"] == "done"
    assert confirmed["response"] == f"Saved to Clarity Knows: {MOM_BIRTHDAY}"
    assert confirmed["memory_changes"]["created"] == 1
    assert [memory["content"] for memory in _active_memories(memory_service)] == [
        MOM_BIRTHDAY
    ]


@pytest.mark.asyncio
async def test_voice_metadata_is_best_effort_and_persisted_when_available():
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
