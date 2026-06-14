import pytest

from app.config import Settings
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_brain_contracts import RexBrainChannel
from app.services.rex_model_router import RexModelRouter
from app.services.voice_stream_session import (
    VOICE_DEEP_RESPONSE_MAX_TOKENS,
    VOICE_RESPONSE_MAX_TOKENS,
)


class FakeAIService:
    def __init__(self, response="Rex response", stream_tokens=None):
        self.response = response
        self.stream_tokens = stream_tokens or ["Rex ", "voice"]
        self.messages = []
        self.kwargs = {}

    async def generate_response(self, messages, **kwargs):
        self.messages = messages
        self.kwargs = kwargs
        return self.response

    async def stream_response(self, messages, **kwargs):
        self.messages = messages
        self.kwargs = kwargs
        for token in self.stream_tokens:
            yield token


class FakeMemoryService:
    def __init__(self):
        self.conversations = {"conversation-voice"}
        self.messages = []
        self.next_message_id = 1

    async def create_conversation(self):
        self.conversations.add("conversation-voice")
        return "conversation-voice"

    async def conversation_exists(self, conversation_id):
        return conversation_id in self.conversations

    async def save_message(self, conversation_id, role, content):
        message = {
            "id": f"message-{self.next_message_id}",
            "conversation_id": conversation_id,
            "role": role,
            "content": content,
            "timestamp": "2026-05-28T00:00:00Z",
        }
        self.next_message_id += 1
        self.messages.append(message)
        return message

    async def get_recent_messages(self, conversation_id, limit=20):
        return [
            message
            for message in self.messages
            if message["conversation_id"] == conversation_id
        ][-limit:]

    async def get_relevant_memories(self, query, limit=8):
        return []

    async def get_structured_memory_context(self, query):
        return {}

    async def save_long_term_memory(self, *args, **kwargs):
        return {}

    async def save_voice_turn(self, **kwargs):
        return {"id": "voice-turn", **kwargs}


def _voice_chat_service(ai_service, *, settings):
    return ChatService(
        ai_service,
        FileService(),
        FakeMemoryService(),
        rex_model_router=RexModelRouter(settings),
    )


@pytest.mark.asyncio
async def test_voice_channel_uses_standard_model_for_normal_financial_question():
    ai_service = FakeAIService(stream_tokens=["ok"])
    chat_service = _voice_chat_service(
        ai_service,
        settings=Settings(
            grok_api_key="key",
            grok_model="grok-default",
            grok_standard_model="grok-standard",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="deep_think_ui",
        ),
    )

    events = [
        event
        async for event in chat_service.stream_message(
            "How much did I spend on restaurants?",
            conversation_id="conversation-voice",
            financial_context={"cash_flow": {"spending": 100}},
            max_response_tokens=VOICE_RESPONSE_MAX_TOKENS,
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert ai_service.kwargs == {"max_tokens": VOICE_RESPONSE_MAX_TOKENS}
    assert "Rex Brain routing contract" not in ai_service.messages[0]["content"]
    assert "Layer 2 Analytical" not in ai_service.messages[0]["content"]
    assert any(event.get("event") == "done" for event in events)


@pytest.mark.asyncio
async def test_voice_channel_can_escalate_explicit_deep_thinking_to_reasoning():
    ai_service = FakeAIService(response="deep voice response")
    chat_service = _voice_chat_service(
        ai_service,
        settings=Settings(
            grok_api_key="key",
            grok_model="grok-default",
            grok_standard_model="grok-standard",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="deep_think_ui",
        ),
    )

    await chat_service.send_message(
        "Deep think and analyze thoroughly why my spending is up",
        conversation_id="conversation-voice",
        financial_context={"cash_flow": {"spending": 1200}},
        max_response_tokens=VOICE_DEEP_RESPONSE_MAX_TOKENS,
        channel=RexBrainChannel.VOICE,
    )

    assert ai_service.kwargs == {"max_tokens": VOICE_DEEP_RESPONSE_MAX_TOKENS}
    assert "Rex Brain routing contract" not in ai_service.messages[0]["content"]
    assert "Layer 2 Analytical" not in ai_service.messages[0]["content"]
