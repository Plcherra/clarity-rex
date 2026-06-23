from datetime import datetime
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.chat_service import (
    FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE,
    ChatService,
)
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService
from voice_stream_fakes import (
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
    override_services,
    receive_until,
)


@pytest.fixture
def client():
    app.dependency_overrides.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


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


def _voice_turn(client, chat, transcript, conversation_id=None):
    deepgram = FakeDeepgramStreamingService(transcript=transcript)
    tts = FakeGoogleTTSService()
    override_services(
        deepgram_streaming_service=deepgram,
        chat_service=chat,
        google_tts_service=tts,
    )

    events = []
    start_payload = {"event": "session.start"}
    if conversation_id is not None:
        start_payload["conversation_id"] = conversation_id

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json(start_payload)
        events.append(websocket.receive_json())
        websocket.send_bytes(b"pcm-frame")
        events.append(websocket.receive_json())
        websocket.send_json({"event": "utterance.end"})

        while True:
            event = websocket.receive_json()
            events.append(event)
            if event["event"] == "error":
                raise AssertionError(f"voice turn failed: {event}")
            if event["event"] == "assistant.done":
                return event, events, tts


def _event_text(events):
    return "\n".join(str(event) for event in events)


def test_voice_refuses_finance_answer_without_financial_context(client):
    ai_service = FakeAIService(stream_tokens=["You spent ", "$42."])
    memory_service = FakeMemoryService()
    chat = _chat_service(ai_service, memory_service)

    done, events, tts = _voice_turn(
        client,
        chat,
        "How much did I spend on groceries?",
    )

    assert done["response_text"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 0
    assert " ".join(tts.calls) == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
    assert "without guessing" in _event_text(events)


def test_voice_saves_exact_movie_plan_and_updates_same_memory(client):
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat = _chat_service(ai_service, memory_service)

    planned, planned_events, _ = _voice_turn(
        client,
        chat,
        "They just released Masters of the Universe, and I'm gonna watch it tonight.",
    )
    tickets, _, _ = _voice_turn(
        client,
        chat,
        "I already bought the tickets.",
        planned["conversation_id"],
    )
    canceled, canceled_events, _ = _voice_turn(
        client,
        chat,
        "I gotta cancel that because my money is tight.",
        planned["conversation_id"],
    )

    assert planned["memory_changes"]["created"] == 1
    assert tickets["memory_changes"]["updated"] == 1
    assert canceled["memory_changes"]["updated"] == 1
    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 0
    assert len(memory_service.long_term_memory) == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User canceled the plan to watch Masters of the Universe tonight because money is tight."
    )
    assert memory_service.long_term_memory[0]["metadata"]["topic_fingerprint"] == (
        "event:personal_plan:watch:masters_of_the_universe"
    )
    assert "pending" not in _event_text(planned_events + canceled_events).lower()
    assert "candidate" not in _event_text(planned_events + canceled_events).lower()


def test_voice_updates_location_and_recall_loads_updated_fact(client):
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

    updated, update_events, _ = _voice_turn(
        client,
        chat,
        "Can you fix my location? It's Somerville with one o and one m.",
        "conversation-existing",
    )

    assert updated["memory_changes"]["updated"] == 1
    assert len(memory_service.long_term_memory) == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )
    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 0
    assert "candidate" not in _event_text(update_events).lower()

    ai_service.stream_tokens = ["You live in Somerville, Massachusetts."]
    recalled, _, _ = _voice_turn(
        client,
        chat,
        "Do you know where I'm located?",
        updated["conversation_id"],
    )

    assert recalled["response_text"] == "You live in Somerville, Massachusetts."
    assert ai_service.stream_calls == 1
    prompt_text = "\n".join(str(message["content"]) for message in ai_service.messages)
    assert "Somerville, Massachusetts" in prompt_text


def test_voice_saves_and_recalls_mom_birthday_without_pending_cards(client):
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat = _chat_service(ai_service, memory_service)

    saved, save_events, _ = _voice_turn(
        client,
        chat,
        "My mom's birthday is June 18",
    )

    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["confirmation_required"] == 0
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert "pending" not in _event_text(save_events).lower()
    assert "candidate" not in _event_text(save_events).lower()

    ai_service.stream_tokens = ["Your mom's birthday is June 18."]
    recalled, _, _ = _voice_turn(
        client,
        chat,
        "Do you know my mom's birthday?",
        saved["conversation_id"],
    )

    assert recalled["response_text"] == "Your mom's birthday is June 18."
    assert ai_service.stream_calls == 1
    prompt_text = "\n".join(str(message["content"]) for message in ai_service.messages)
    assert "- saved knowledge/person Mom - mother" in prompt_text
    assert "birthday: June 18" in prompt_text


def test_voice_direct_device_model_save_is_spoken_and_confirmed(client):
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat = _chat_service(ai_service, memory_service)

    done, events, tts = _voice_turn(
        client,
        chat,
        "It's a Omen 45 l.",
    )

    assert done["response_text"] == "Got it, you have an Omen 45L."
    assert done["memory_changes"]["created"] == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User has an Omen 45L."
    )
    assert tts.calls == ["Got it, you have an Omen 45L."]
    assert any(event["event"] == "assistant.audio_chunk" for event in events)
    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 0


def test_voice_unclear_transcript_asks_before_saving_memory(client):
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat = _chat_service(ai_service, memory_service)

    done, events, _ = _voice_turn(
        client,
        chat,
        "Please remember that the transcript is unclear.",
    )

    assert done["memory_changes"]["created"] == 0
    assert done["memory_changes"]["records"][0]["action"] == "clarification_required"
    assert done["response_text"].startswith("I couldn't read that clearly")
    assert memory_service.long_term_memory == []
    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 0
    assert "saved" not in _event_text(events).lower()


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
def test_voice_recall_uses_what_rex_knows_for_profile_plan_and_location(
    client,
    question,
    memory_content,
    answer,
):
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

    done, _, _ = _voice_turn(client, chat, question)

    assert done["response_text"] == answer
    assert ai_service.stream_calls == 1
    prompt_text = "\n".join(str(message["content"]) for message in ai_service.messages)
    assert memory_content in prompt_text
    assert memory_service.relevant_memory_queries[0]["query"] == question
