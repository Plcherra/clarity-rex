import pytest

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_brain_contracts import RexBrainChannel
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService


class FakeUsageTrackingService:
    def __init__(self):
        self.llm_turns = []

    async def record_llm_turn(self, **kwargs):
        self.llm_turns.append(kwargs)
        return True


def _chat_service(ai_service=None, memory_service=None, usage_service=None):
    memory = memory_service or FakeMemoryService()
    memory.user_id = "00000000-0000-0000-0000-000000000001"
    return ChatService(
        ai_service or FakeAIService(response="Sure thing."),
        FileService(),
        memory,
        time_context_service=TimeContextService(timezone_name="America/New_York"),
        usage_tracking_service=usage_service,
    )


@pytest.mark.asyncio
async def test_send_message_records_one_llm_usage_event_for_normal_chat_turn():
    usage = FakeUsageTrackingService()
    chat = _chat_service(usage_service=usage)

    result = await chat.send_message("How is my day?", channel=RexBrainChannel.CHAT)

    assert result["response"] == "Sure thing."
    assert len(usage.llm_turns) == 1
    assert usage.llm_turns[0]["surface"] == "assistant"
    assert usage.llm_turns[0]["channel"] == "chat"
    assert usage.llm_turns[0]["status"] == "success"
    assert "How is my day?" not in str(usage.llm_turns[0])


@pytest.mark.asyncio
async def test_send_message_does_not_record_llm_usage_for_direct_memory_turn():
    usage = FakeUsageTrackingService()
    ai = FakeAIService(response="Should not be called.")
    chat = _chat_service(ai_service=ai, usage_service=usage)

    result = await chat.send_message(
        "My mom's birthday is June 18",
        channel=RexBrainChannel.CHAT,
    )

    assert result["response"] == "Got it, your mom's birthday is June 18."
    assert ai.generate_calls == 0
    assert usage.llm_turns == []


@pytest.mark.asyncio
async def test_stream_message_records_one_llm_usage_event_for_normal_voice_turn():
    usage = FakeUsageTrackingService()
    ai = FakeAIService(stream_tokens=["Voice ", "response."])
    chat = _chat_service(ai_service=ai, usage_service=usage)

    events = [
        event
        async for event in chat.stream_message(
            "Tell me something",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert events[-1]["event"] == "done"
    assert len(usage.llm_turns) == 1
    assert usage.llm_turns[0]["channel"] == "voice"
    assert usage.llm_turns[0]["status"] == "success"
    assert "Tell me something" not in str(usage.llm_turns[0])
