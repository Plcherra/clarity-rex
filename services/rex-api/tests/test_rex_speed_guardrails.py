from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.action_truth_policy import ACTION_TRUTH_POLICY_PROMPT
from app.services.prompt_service import (
    FINANCIAL_CONTEXT_PREFIX,
    LONG_TERM_MEMORY_PREFIX,
    MAX_DEFAULT_REX_PROMPT_CHARACTERS,
    PERSONALITY_CONTEXT_PREFIX,
    PromptService,
    REX_PERSONALITY_PROMPT,
    STRUCTURED_MEMORY_PREFIX,
)
from app.services.rex_brain_contracts import RexBrainChannel
from app.services.rex_brain_prompts import (
    MAX_LAYER_PROMPT_CHARACTERS,
    all_rex_prompt_contracts,
)
from chat_service_fakes import FakeAIService, FakeMemoryService
from voice_stream_fakes import (
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
    override_services,
    receive_until,
)

ROOT = Path(__file__).resolve().parents[3]
FORBIDDEN_LEGACY_TERMS = (
    "MemoryCandidate",
    "memory_candidate",
    "pending candidate",
    "review session",
    "confirmation record",
)
FORBIDDEN_SECOND_CALL_TERMS = (
    "memory_post_turn",
    "memory_extraction",
    "extract_memory_after_success",
    "extract_memory_after",
)

BASE_SYSTEM_PROMPT = (
    f"{PERSONALITY_CONTEXT_PREFIX}{REX_PERSONALITY_PROMPT}\n\n"
    f"{ACTION_TRUTH_POLICY_PROMPT}"
)


def _prompt_text(messages):
    return "\n".join(str(message.get("content", "")) for message in messages)


@pytest.fixture
def client():
    app.dependency_overrides.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def _chat_service(ai_service=None, memory_service=None):
    return ChatService(
        ai_service or FakeAIService(),
        FileService(),
        memory_service or FakeMemoryService(),
    )


@pytest.mark.asyncio
async def test_normal_chat_turn_uses_exactly_one_llm_call():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()

    result = await _chat_service(ai_service, memory_service).send_message("Hello Rex")

    assert result["response"] == "Rex response"
    assert ai_service.generate_calls == 1
    assert ai_service.stream_calls == 0
    assert memory_service.relevant_memory_queries == []
    assert memory_service.structured_context_queries == []


@pytest.mark.asyncio
async def test_normal_streaming_chat_turn_uses_exactly_one_llm_call():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()

    events = [
        event
        async for event in _chat_service(ai_service, memory_service).stream_message(
            "Hello Rex"
        )
    ]

    assert events[-1]["event"] == "done"
    assert events[-1]["response"] == "Rex stream"
    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 1
    assert memory_service.relevant_memory_queries == []
    assert memory_service.structured_context_queries == []
    assert len(ai_service.messages) == 2
    base_prompt = ai_service.messages[0]["content"].split("\n\nCurrent time context:")[0]
    assert len(base_prompt) <= MAX_DEFAULT_REX_PROMPT_CHARACTERS

    prompt_text = _prompt_text(ai_service.messages)
    assert LONG_TERM_MEMORY_PREFIX not in prompt_text
    assert STRUCTURED_MEMORY_PREFIX not in prompt_text
    assert FINANCIAL_CONTEXT_PREFIX not in prompt_text


@pytest.mark.asyncio
async def test_normal_voice_turn_uses_exactly_one_llm_call():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()

    events = [
        event
        async for event in _chat_service(ai_service, memory_service).stream_message(
            "Hey Rex",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert events[-1]["event"] == "done"
    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 1
    assert memory_service.relevant_memory_queries == []
    assert memory_service.structured_context_queries == []


@pytest.mark.asyncio
async def test_voice_trace_covers_location_recall_fixture():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-location",
            "memory_type": "fact",
            "content": "User lives in Somerville, Massachusetts.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )

    events = [
        event
        async for event in _chat_service(ai_service, memory_service).stream_message(
            "Do you know where I'm located?",
            channel=RexBrainChannel.VOICE,
            include_turn_trace=True,
        )
    ]

    trace = next(event for event in events if event["event"] == "turn.trace")
    assert trace["channel"] == "voice"
    assert trace["loaded_context"]["long_term_memory"] is True
    assert trace["loaded_context"]["profile_memory"] is True
    assert ai_service.stream_calls == 1


@pytest.mark.asyncio
async def test_voice_trace_covers_exact_movie_memory_fixture():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()

    events = [
        event
        async for event in _chat_service(ai_service, memory_service).stream_message(
            "I'm going to watch Masters of the Universe tonight",
            channel=RexBrainChannel.VOICE,
            include_turn_trace=True,
        )
    ]

    memory_changes = events[-1]["memory_changes"]
    assert memory_changes["confirmation_required"] == 1
    assert memory_changes["write_proposals"][0]["title"] == (
        "User plans to watch Masters of the Universe tonight."
    )
    assert memory_service.long_term_memory == []
    assert ai_service.stream_calls == 0


@pytest.mark.asyncio
async def test_voice_trace_covers_location_correction_fixture():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-location",
            "memory_type": "fact",
            "content": "User lives in Summerville, Massachusetts.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )

    events = [
        event
        async for event in _chat_service(ai_service, memory_service).stream_message(
            "fix my location to Somerville with one o and one m.",
            channel=RexBrainChannel.VOICE,
            include_turn_trace=True,
        )
    ]

    trace = next(event for event in events if event["event"] == "turn.trace")
    assert trace["loaded_context"]["long_term_memory"] is True
    memory_changes = events[-1]["memory_changes"]
    assert memory_changes["confirmation_required"] == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User lives in Summerville, Massachusetts."
    )
    assert ai_service.stream_calls == 0


def test_normal_voice_websocket_turn_uses_exactly_one_llm_call(client):
    ai_service = FakeAIService(stream_tokens=["Rex ", "streaming ", "response."])
    memory_service = FakeMemoryService()
    chat = _chat_service(ai_service, memory_service)
    deepgram = FakeDeepgramStreamingService(
        transcript="Hey Rex",
        partial_transcript="Hey",
    )
    tts = FakeGoogleTTSService()
    override_services(deepgram, chat, tts)

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        websocket.receive_json()
        websocket.send_bytes(b"pcm-frame")
        websocket.receive_json()
        websocket.send_json({"event": "utterance.end"})

        done = receive_until(websocket, "assistant.done")
        assert done["response_text"] == "Rex streaming response."
        assert done["timings"]["stt_ms"] >= 0
        assert done["timings"]["turn_ms"] >= 0
        assert done["timings"]["tts_chunk_count"] == 1
        assert done["timings"]["tts_total_ms"] >= 0
        assert done["timings"]["tts_first_audio_ms"] >= 0

    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 1
    assert memory_service.relevant_memory_queries == []
    assert memory_service.structured_context_queries == []
    assert tts.calls == ["Rex streaming response."]


@pytest.mark.asyncio
async def test_memory_recall_voice_turn_is_one_call_with_bounded_context():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-location",
            "memory_type": "fact",
            "content": "User lives in Somerville, Massachusetts.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )

    events = [
        event
        async for event in _chat_service(ai_service, memory_service).stream_message(
            "Do you know where I'm located?",
            channel=RexBrainChannel.VOICE,
            include_turn_trace=True,
        )
    ]

    trace = next(event for event in events if event["event"] == "turn.trace")
    assert trace["loaded_context"]["long_term_memory"] is True
    assert trace["loaded_context"]["structured_memory"] is True
    assert ai_service.generate_calls == 0
    assert ai_service.stream_calls == 1
    assert len(memory_service.relevant_memory_queries) <= 2
    assert len(memory_service.structured_context_queries) == 1
    assert len(_prompt_text(ai_service.messages)) < 4000


def test_prompt_budgets_stay_under_voice_first_limits():
    prompt = PromptService().build_messages(user_message="Hello Rex")[0]["content"]

    assert prompt == BASE_SYSTEM_PROMPT
    assert len(prompt) <= MAX_DEFAULT_REX_PROMPT_CHARACTERS

    for contract in all_rex_prompt_contracts():
        assert len(contract.system_prompt) <= MAX_LAYER_PROMPT_CHARACTERS


def test_legacy_pending_memory_terms_are_not_in_active_product_code():
    active_roots = [
        ROOT / "services" / "rex-api" / "app",
        ROOT / "apps" / "mobile" / "lib",
    ]
    offenders = []

    for root in active_roots:
        for path in root.rglob("*"):
            if path.suffix not in {".dart", ".py"}:
                continue
            content = path.read_text(encoding="utf-8")
            for term in FORBIDDEN_LEGACY_TERMS:
                if term in content:
                    offenders.append(f"{path.relative_to(ROOT)} contains {term!r}")

    assert offenders == []


def test_second_llm_memory_extraction_hooks_are_not_in_active_product_code():
    active_roots = [
        ROOT / "services" / "rex-api" / "app",
        ROOT / "apps" / "mobile" / "lib",
    ]
    offenders = []

    for root in active_roots:
        for path in root.rglob("*"):
            if path.suffix not in {".dart", ".py"}:
                continue
            content = path.read_text(encoding="utf-8")
            for term in FORBIDDEN_SECOND_CALL_TERMS:
                if term in content:
                    offenders.append(f"{path.relative_to(ROOT)} contains {term!r}")

    assert offenders == []
