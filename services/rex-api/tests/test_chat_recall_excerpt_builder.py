import pytest

from app.services.chat_recall_excerpt_constants import (
    CHAT_EXCERPT_CONTEXT_AFTER,
    CHAT_EXCERPT_CONTEXT_BEFORE,
)
from app.services.chat_recall_excerpts import ChatRecallExcerptBuilder


class FakeRecallMemoryService:
    def __init__(self, messages: list[dict]) -> None:
        self.messages = messages

    async def get_conversation_messages(self, conversation_id, limit=500):
        return self.messages[:limit]


@pytest.mark.asyncio
async def test_excerpt_builder_includes_nearby_factual_turns():
    """Failure class: excerpts drop nearby factual details."""
    conversation = [
        {"id": "m1", "role": "user", "content": "Random small talk."},
        {"id": "m2", "role": "assistant", "content": "Sure."},
        {"id": "m3", "role": "user", "content": "My device model is Aurora 9000."},
        {"id": "m4", "role": "assistant", "content": "Got it."},
        {"id": "m5", "role": "user", "content": "It has 32GB RAM."},
        {"id": "m6", "role": "assistant", "content": "Noted."},
    ]
    builder = ChatRecallExcerptBuilder(FakeRecallMemoryService(conversation))
    matched = [conversation[4]]

    excerpts = await builder.conversation_cluster_context(
        "conversation-1",
        matched,
    )

    contents = [message["content"] for message in excerpts]
    assert any("Aurora 9000" in content for content in contents)
    assert any("32GB RAM" in content for content in contents)


@pytest.mark.asyncio
async def test_excerpt_builder_respects_context_window_constants():
    """Nearby turns outside the configured window should not flood excerpts."""
    filler = [
        {
            "id": f"f{i}",
            "role": "user" if i % 2 == 0 else "assistant",
            "content": f"noise turn {i}",
        }
        for i in range(CHAT_EXCERPT_CONTEXT_BEFORE + 2)
    ]
    anchor_index = len(filler)
    conversation = filler + [
        {"id": "anchor", "role": "user", "content": "Anchor fact about payroll."},
        {"id": "near", "role": "assistant", "content": "Payroll is every Friday."},
    ]
    builder = ChatRecallExcerptBuilder(FakeRecallMemoryService(conversation))
    matched = [conversation[anchor_index]]

    excerpts = await builder.conversation_cluster_context(
        "conversation-1",
        matched,
    )

    assert any("Payroll is every Friday." in message["content"] for message in excerpts)
    assert len(excerpts) <= CHAT_EXCERPT_CONTEXT_BEFORE + CHAT_EXCERPT_CONTEXT_AFTER + 3
