"""Voice writes what the brain asks for — after the user confirms, never before.

Grok is the only understanding layer, so these end-to-end voice turns script the
action the brain emits and then assert the body/Truth/TTS contract around it.
"""

from __future__ import annotations

import logging
from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeMemoryService
from durable_write_test_helpers import assert_self_location_person_entity
from scripted_brain_fakes import ScriptedAIService, reply_with_action
from voice_stream_async_client import (
    async_confirm_voice_proposal,
    async_voice_client,
    async_voice_websocket_turn,
)

MOM_BIRTHDAY_REPLY = "June 18 — good to know."
LOCATION_REPLY = "One o and one m — Somerville it is."

VOICE_BRAIN = {
    "mom's birthday": reply_with_action(
        MOM_BIRTHDAY_REPLY,
        "save_memory",
        {"content": "User's mom's birthday is June 18.", "memory_type": "fact"},
    ),
    # Person cards are materialized only from facts at importance 4 or higher.
    "somerville": reply_with_action(
        LOCATION_REPLY,
        "update_memory",
        {
            "record_id": "memory-existing",
            "content": "User lives in Somerville, Massachusetts.",
            "memory_type": "fact",
            "importance": 4,
            "previous_content": "User lives in Summerville, Massachusetts.",
        },
    ),
}


def _fixed_time_context_service() -> TimeContextService:
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


def _chat_service(ai_service, memory_service) -> ChatService:
    return ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )


def spoken(tts) -> str:
    """What Google TTS was actually asked to say this turn."""
    return " ".join(part.strip() for part in tts.calls if part.strip())


def assert_nothing_technical_spoken(tts) -> None:
    text = spoken(tts)
    assert "```" not in text
    assert "rex_action" not in text
    assert "save_memory" not in text
    assert "{" not in text and "}" not in text


def timing_logs(caplog) -> list[str]:
    return [
        record.message
        for record in caplog.records
        if "voice_turn_timing" in record.message
    ]


@pytest.mark.asyncio
async def test_voice_save_action_confirms_before_writing_to_knows(caplog):
    async with async_voice_client() as client:
        caplog.set_level(logging.INFO, logger="rex.voice_stream")
        ai_service = ScriptedAIService(VOICE_BRAIN)
        memory_service = FakeMemoryService()
        chat = _chat_service(ai_service, memory_service)

        proposed, propose_tts = await async_voice_websocket_turn(
            client,
            chat,
            "My mom's birthday is June 18",
        )

        assert proposed["memory_changes"]["confirmation_required"] == 1
        assert proposed["memory_changes"]["write_proposals"]
        assert memory_service.long_term_memory == []
        assert memory_service.entities == []
        assert proposed["response_text"] == MOM_BIRTHDAY_REPLY
        assert spoken(propose_tts) == MOM_BIRTHDAY_REPLY
        assert_nothing_technical_spoken(propose_tts)

        saved = await async_confirm_voice_proposal(client, chat, proposed)

        assert saved["memory_changes"]["created"] == 1
        assert saved["timings"]["tts_chunk_count"] >= 1
        assert [row["content"] for row in memory_service.long_term_memory] == [
            "User's mom's birthday is June 18."
        ]
        assert "Knows" in saved["response_text"]
        # Confirming applies the frozen snapshot; it never re-asks the brain.
        assert ai_service.stream_calls == 1
        assert ai_service.generate_calls == 0

        messages = timing_logs(caplog)
        assert any("memory_action=none" in message for message in messages)
        assert any("memory_action=direct_saved" in message for message in messages)


@pytest.mark.asyncio
async def test_voice_update_action_rewrites_the_same_saved_fact():
    async with async_voice_client() as client:
        ai_service = ScriptedAIService(VOICE_BRAIN)
        memory_service = FakeMemoryService()
        memory_service.conversations.add("conversation-existing")
        memory_service.long_term_memory.append(
            {
                "id": "memory-existing",
                "memory_type": "fact",
                "content": "User lives in Summerville, Massachusetts.",
                "importance": 4,
                "metadata": {"topic_fingerprint": "fact:identity:location"},
                "active": True,
            }
        )
        chat = _chat_service(ai_service, memory_service)

        proposed, _ = await async_voice_websocket_turn(
            client,
            chat,
            "Can you change my location? It's Somerville with one o and one m.",
            "conversation-existing",
        )
        assert proposed["memory_changes"]["confirmation_required"] == 1
        assert memory_service.long_term_memory[0]["content"] == (
            "User lives in Summerville, Massachusetts."
        )

        updated = await async_confirm_voice_proposal(client, chat, proposed)

        assert updated["memory_changes"]["updated"] == 1
        assert updated["memory_changes"]["created"] == 0
        assert_self_location_person_entity(
            memory_service,
            "Somerville, Massachusetts",
        )


@pytest.mark.asyncio
async def test_voice_never_speaks_the_action_fence():
    reply = "Locking that in for you."
    raw = reply_with_action(
        reply,
        "save_memory",
        {"content": "User prefers dark mode.", "memory_type": "preference"},
    )
    async with async_voice_client() as client:
        ai_service = ScriptedAIService(
            # Small tokens so the fence markers arrive split across chunks.
            stream_tokens=[raw[index : index + 7] for index in range(0, len(raw), 7)],
        )
        memory_service = FakeMemoryService()
        chat = _chat_service(ai_service, memory_service)

        done, tts = await async_voice_websocket_turn(
            client,
            chat,
            "Remember that I prefer dark mode",
        )

        assert done["response_text"] == reply
        assert spoken(tts) == reply
        assert_nothing_technical_spoken(tts)
        assert done["memory_changes"]["confirmation_required"] == 1


@pytest.mark.asyncio
async def test_voice_base_turn_does_not_dump_saved_knows_into_the_prompt():
    answer = "You live in Somerville, Massachusetts."
    memory_content = "User lives in Somerville, Massachusetts."
    async with async_voice_client() as client:
        ai_service = ScriptedAIService(stream_tokens=[answer])
        memory_service = FakeMemoryService()
        memory_service.long_term_memory.append(
            {
                "id": "memory-existing",
                "memory_type": "fact",
                "content": memory_content,
                "importance": 4,
                "metadata": {},
                "active": True,
            }
        )
        chat = _chat_service(ai_service, memory_service)

        done, tts = await async_voice_websocket_turn(
            client,
            chat,
            "Do you know where I'm located?",
        )

        assert done["response_text"] == answer
        assert spoken(tts) == answer

        prompt_text = "\n".join(
            str(message["content"]) for message in ai_service.messages
        )
        # Knows is fetched on demand, never dumped into every base turn.
        assert memory_content not in prompt_text
        assert memory_service.relevant_memory_queries == []
        assert ai_service.stream_calls == 1


@pytest.mark.asyncio
async def test_voice_carries_recent_turns_into_the_next_voice_prompt():
    async with async_voice_client() as client:
        ai_service = ScriptedAIService(
            {
                "masters of the universe": "Masters of the Universe tonight — nice.",
                "what did i just say": "You said you're watching Masters of the Universe tonight.",
            }
        )
        memory_service = FakeMemoryService()
        chat = _chat_service(ai_service, memory_service)

        first, _ = await async_voice_websocket_turn(
            client,
            chat,
            "I'm watching Masters of the Universe tonight.",
        )
        second, _ = await async_voice_websocket_turn(
            client,
            chat,
            "What did I just say?",
            first["conversation_id"],
        )

        assert second["response_text"] == (
            "You said you're watching Masters of the Universe tonight."
        )
        prompt_text = "\n".join(
            str(message["content"]) for message in ai_service.messages
        )
        assert "I'm watching Masters of the Universe tonight." in prompt_text
        assert "Masters of the Universe tonight — nice." in prompt_text
