from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.chat_service import (
    FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE,
    ChatService,
)
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService
from durable_write_test_helpers import (
    assert_mom_birthday_person_entity,
    assert_self_location_person_entity,
)
from voice_stream_async_client import (
    async_confirm_voice_proposal,
    async_voice_client,
    async_voice_websocket_turn,
)


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


def _chat_service(ai_service, memory_service):
    return ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )


@pytest.mark.asyncio
async def test_voice_refuses_finance_answer_without_financial_context():
    async with async_voice_client() as client:
        ai_service = FakeAIService(stream_tokens=["You spent ", "$42."])
        memory_service = FakeMemoryService()
        chat = _chat_service(ai_service, memory_service)

        done, tts = await async_voice_websocket_turn(
            client,
            chat,
            "How much did I spend on groceries?",
        )

        assert done["response_text"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
        assert ai_service.generate_calls == 0
        assert ai_service.stream_calls == 0
        assert " ".join(tts.calls) == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
        assert "without guessing" in done["response_text"]


@pytest.mark.asyncio
async def test_voice_saves_exact_movie_plan_and_updates_same_memory():
    async with async_voice_client() as client:
        ai_service = FakeAIService()
        memory_service = FakeMemoryService()
        chat = _chat_service(ai_service, memory_service)

        proposed, _ = await async_voice_websocket_turn(
            client,
            chat,
            "They just released Masters of the Universe, and I'm gonna watch it tonight.",
        )
        assert proposed["memory_changes"]["confirmation_required"] == 1
        planned = await async_confirm_voice_proposal(client, chat, proposed)
        tickets_proposed, _ = await async_voice_websocket_turn(
            client,
            chat,
            "I already bought the tickets.",
            planned["conversation_id"],
        )
        tickets = await async_confirm_voice_proposal(client, chat, tickets_proposed)
        canceled_proposed, _ = await async_voice_websocket_turn(
            client,
            chat,
            "I gotta cancel that because my money is tight.",
            planned["conversation_id"],
        )
        canceled = await async_confirm_voice_proposal(client, chat, canceled_proposed)

        assert planned["memory_changes"]["created"] == 1
        assert tickets["memory_changes"]["updated"] == 1
        assert canceled["memory_changes"]["updated"] == 1
        assert ai_service.generate_calls == 3
        assert ai_service.stream_calls == 0
        assert len(memory_service.long_term_memory) == 1
        assert memory_service.long_term_memory[0]["content"] == (
            "User canceled the plan to watch Masters of the Universe tonight because money is tight."
        )


@pytest.mark.asyncio
async def test_voice_updates_location_and_recall_loads_updated_fact():
    async with async_voice_client() as client:
        ai_service = FakeAIService()
        memory_service = FakeMemoryService()
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
        memory_service.conversations.add("conversation-existing")
        chat = _chat_service(ai_service, memory_service)

        updated_proposed, _ = await async_voice_websocket_turn(
            client,
            chat,
            "Can you fix my location? It's Somerville with one o and one m.",
            "conversation-existing",
        )
        assert updated_proposed["memory_changes"]["confirmation_required"] == 1
        updated = await async_confirm_voice_proposal(client, chat, updated_proposed)

        assert updated["memory_changes"]["updated"] == 1
        assert_self_location_person_entity(
            memory_service,
            "Somerville, Massachusetts",
        )

        ai_service.stream_tokens = ["You live in Somerville, Massachusetts."]
        recalled, _ = await async_voice_websocket_turn(
            client,
            chat,
            "Do you know where I'm located?",
            updated["conversation_id"],
        )

        assert recalled["response_text"] == "You live in Somerville, Massachusetts."
        assert ai_service.stream_calls == 1


@pytest.mark.asyncio
async def test_voice_saves_and_recalls_mom_birthday_without_pending_cards():
    async with async_voice_client() as client:
        ai_service = FakeAIService()
        memory_service = FakeMemoryService()
        chat = _chat_service(ai_service, memory_service)

        proposed, _ = await async_voice_websocket_turn(
            client,
            chat,
            "My mom's birthday is June 18",
        )
        assert proposed["memory_changes"]["confirmation_required"] == 1
        saved = await async_confirm_voice_proposal(client, chat, proposed)

        assert saved["memory_changes"]["created"] == 1
        assert_mom_birthday_person_entity(memory_service, "June 18")

        ai_service.stream_tokens = ["Your mom's birthday is June 18."]
        recalled, _ = await async_voice_websocket_turn(
            client,
            chat,
            "Do you know my mom's birthday?",
            saved["conversation_id"],
        )

        assert recalled["response_text"] == "Your mom's birthday is June 18."
        assert ai_service.stream_calls == 1


@pytest.mark.parametrize(
    ("question", "memory_content", "answer"),
    [
        (
            "Do you know anything about me?",
            "User's name is Pedro Martins.",
            "Your name is Pedro Martins.",
        ),
        (
            "What are my plans tonight?",
            "User plans to watch Masters of the Universe tonight.",
            "You plan to watch Masters of the Universe tonight.",
        ),
        (
            "Where am I located?",
            "User lives in Somerville, Massachusetts.",
            "You live in Somerville, Massachusetts.",
        ),
    ],
)
@pytest.mark.asyncio
async def test_voice_recall_uses_what_rex_knows_for_profile_plan_and_location(
    question,
    memory_content,
    answer,
):
    async with async_voice_client() as client:
        ai_service = FakeAIService(stream_tokens=[answer])
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

        done, _ = await async_voice_websocket_turn(client, chat, question)

        assert done["response_text"] == answer
        assert ai_service.stream_calls == 1
