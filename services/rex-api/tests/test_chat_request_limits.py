"""Input size caps for chat payloads."""

import pytest
from pydantic import ValidationError

from app.models.chat import CHAT_MESSAGE_MAX_LENGTH, ChatRequest


def test_chat_message_rejects_oversized_payload():
    with pytest.raises(ValidationError):
        ChatRequest(message="x" * (CHAT_MESSAGE_MAX_LENGTH + 1))


def test_financial_context_rejects_oversized_payload():
    with pytest.raises(ValidationError):
        ChatRequest(
            message="hello",
            financial_context={"blob": "y" * 40_000},
        )


def test_chat_message_accepts_normal_payload():
    request = ChatRequest(message="hello", financial_context={"ok": True})
    assert request.message == "hello"
