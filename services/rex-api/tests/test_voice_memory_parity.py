"""Voice and chat are one pipeline: same brain action, same confirm, same write.

Rex only writes when the brain emits an action, so each turn here scripts the
action and then checks that voice behaves exactly like chat.
"""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.chat_financial_guard import (
    FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE,
)
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService
from durable_write_test_helpers import confirm_durable_write
from scripted_brain_fakes import ScriptedAIService, reply_with_action
from voice_stream_async_client import (
    async_confirm_voice_proposal,
    async_voice_client,
    async_voice_websocket_turn,
)

MOM_BIRTHDAY_MESSAGE = "My mom's birthday is June 18"
MOM_BIRTHDAY_REPLY = "June 18 — good to know."
MOM_BIRTHDAY_FACT = "User's mom's birthday is June 18."

SAVE_BRAIN = {
    "mom's birthday": reply_with_action(
        MOM_BIRTHDAY_REPLY,
        "save_memory",
        {"content": MOM_BIRTHDAY_FACT, "memory_type": "fact"},
    ),
}

MOVIE_PLAN_BRAIN = {
    "masters of the universe": reply_with_action(
        "Masters of the Universe tonight — nice.",
        "save_memory",
        {
            "content": "User plans to watch Masters of the Universe tonight.",
            "memory_type": "fact",
        },
    ),
    "bought the tickets": reply_with_action(
        "Tickets already in hand.",
        "update_memory",
        {
            "record_id": "memory-1",
            "content": "User bought tickets to watch Masters of the Universe tonight.",
            "memory_type": "fact",
        },
    ),
    "cancel that": reply_with_action(
        "Understood — money first.",
        "update_memory",
        {
            "record_id": "memory-1",
            "content": (
                "User canceled the plan to watch Masters of the Universe tonight "
                "because money is tight."
            ),
            "memory_type": "fact",
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


def _proposal_shape(turn: dict) -> dict:
    proposal = turn["memory_changes"]["write_proposals"][0]
    return {key: proposal.get(key) for key in ("write_kind", "action", "title", "body")}


@pytest.mark.asyncio
async def test_voice_refuses_finance_answer_without_financial_context():
    async with async_voice_client() as client:
        ai_service = FakeAIService(
            stream_tokens=[
                "You spent $42. ",
                "```rex_action\n",
                '{"action":"fetch_spend_insight","payload":{"category":"Groceries"}}\n',
                "```",
            ]
        )
        memory_service = FakeMemoryService()
        chat = _chat_service(ai_service, memory_service)

        done, tts = await async_voice_websocket_turn(
            client,
            chat,
            "How much did I spend on groceries?",
        )

        assert done["response_text"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
        # No grounded second pass without reliable Clarity finance data.
        assert ai_service.generate_calls == 0
        assert ai_service.stream_calls == 1
        assert " ".join(tts.calls) == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
        assert "without guessing" in done["response_text"]
        assert "$42" not in done["response_text"]


@pytest.mark.asyncio
async def test_voice_and_chat_propose_and_apply_the_same_save():
    chat_store = FakeMemoryService()
    chat_service = _chat_service(ScriptedAIService(SAVE_BRAIN), chat_store)

    chat_proposed = await chat_service.send_message(MOM_BIRTHDAY_MESSAGE)
    assert chat_proposed["memory_changes"]["confirmation_required"] == 1
    assert chat_store.long_term_memory == []
    chat_saved = await confirm_durable_write(chat_service, chat_proposed)

    async with async_voice_client() as client:
        voice_store = FakeMemoryService()
        voice_service = _chat_service(ScriptedAIService(SAVE_BRAIN), voice_store)

        voice_proposed, tts = await async_voice_websocket_turn(
            client,
            voice_service,
            MOM_BIRTHDAY_MESSAGE,
        )
        assert voice_proposed["memory_changes"]["confirmation_required"] == 1
        assert voice_store.long_term_memory == []
        assert " ".join(tts.calls) == MOM_BIRTHDAY_REPLY

        voice_saved = await async_confirm_voice_proposal(
            client,
            voice_service,
            voice_proposed,
        )

    assert _proposal_shape(voice_proposed) == _proposal_shape(chat_proposed)
    assert voice_proposed["response_text"] == chat_proposed["response"]
    assert voice_saved["memory_changes"]["created"] == (
        chat_saved["memory_changes"]["created"]
    )
    assert [row["content"] for row in voice_store.long_term_memory] == (
        [row["content"] for row in chat_store.long_term_memory]
    )
    assert [row["content"] for row in voice_store.long_term_memory] == [
        MOM_BIRTHDAY_FACT
    ]


@pytest.mark.asyncio
async def test_voice_updates_keep_one_saved_fact_instead_of_duplicates():
    async with async_voice_client() as client:
        ai_service = ScriptedAIService(MOVIE_PLAN_BRAIN)
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
        # Three brain turns; the three confirmations never re-ask the brain.
        assert ai_service.stream_calls == 3
        assert len(memory_service.long_term_memory) == 1
        assert memory_service.long_term_memory[0]["content"] == (
            "User canceled the plan to watch Masters of the Universe tonight "
            "because money is tight."
        )


@pytest.mark.parametrize(
    ("question", "answer"),
    [
        (
            "Do you know anything about me?",
            "Your name is Pedro Martins.",
        ),
        (
            "What are my plans tonight?",
            "You plan to watch Masters of the Universe tonight.",
        ),
        (
            "Where am I located?",
            "You live in Somerville, Massachusetts.",
        ),
    ],
)
@pytest.mark.asyncio
async def test_voice_speaks_the_brain_reply_for_questions(question, answer):
    async with async_voice_client() as client:
        ai_service = ScriptedAIService(stream_tokens=[answer])
        memory_service = FakeMemoryService()
        chat = _chat_service(ai_service, memory_service)

        done, tts = await async_voice_websocket_turn(client, chat, question)

        assert done["response_text"] == answer
        assert " ".join(part.strip() for part in tts.calls) == answer
        assert ai_service.stream_calls == 1
        assert done["memory_changes"] is None
        assert memory_service.long_term_memory == []
