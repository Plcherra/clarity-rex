import pytest

from app.services.chat_turn_orchestrator_support import stream_should_buffer_for_action_truth
from app.services.rex_intent_router import RexIntent, RexIntentDecision


def test_stream_buffers_tokens_for_memory_save_intent():
    decision = RexIntentDecision(intent=RexIntent.MEMORY_SAVE, reasons=("memory_save_language",))
    assert stream_should_buffer_for_action_truth(decision) is True


def test_stream_buffers_tokens_for_goal_intent():
    decision = RexIntentDecision(intent=RexIntent.GOAL_OR_COMMITMENT, reasons=("goal_terms",))
    assert stream_should_buffer_for_action_truth(decision) is True


def test_stream_does_not_buffer_casual_intent():
    decision = RexIntentDecision(intent=RexIntent.CASUAL, reasons=("casual_greeting",))
    assert stream_should_buffer_for_action_truth(decision) is False


@pytest.mark.asyncio
async def test_stream_memory_save_does_not_emit_saved_before_backend_confirmation(
    monkeypatch,
):
    from chat_service_fakes import FakeAIService, FakeMemoryService
    from app.services.chat_service import ChatService
    from app.services.file_service import FileService

    ai_service = FakeAIService(
        stream_tokens=["I've ", "Saved ", "that for you."],
    )
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    async def skip_memory_short_circuit(*_args, **_kwargs):
        return None

    monkeypatch.setattr(
        chat_service.memory_turn_service,
        "handle_turn",
        skip_memory_short_circuit,
    )

    events = [
        event
        async for event in chat_service.stream_message(
            "Please remember that I like hiking on weekends",
            file=None,
        )
    ]

    token_text = "".join(
        event["token"] for event in events if event.get("event") == "token"
    )
    done = events[-1]

    assert done["event"] == "done"
    assert "Saved that for you" not in token_text
    assert "don't have a confirmed saved change" in done["response"]
    assert done.get("memory_changes") is None
    assert ai_service.stream_calls == 1
