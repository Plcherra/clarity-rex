import json
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator

# Authenticated abuse / cost caps (chars / serialized JSON size).
CHAT_MESSAGE_MAX_LENGTH = 16_000
FINANCIAL_CONTEXT_MAX_CHARS = 32_000
WRITE_CONFIRMATION_MAX_CHARS = 8_000


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=CHAT_MESSAGE_MAX_LENGTH)
    conversation_id: Optional[str] = None
    file: Optional[str] = None
    stream: bool = False
    financial_context: Optional[dict[str, Any]] = None
    deep_think: bool = False
    locale: Optional[str] = None
    write_confirmation: Optional[dict[str, Any]] = None

    @field_validator("financial_context")
    @classmethod
    def _cap_financial_context(cls, value: Optional[dict[str, Any]]):
        return _reject_oversized_mapping(
            value,
            limit=FINANCIAL_CONTEXT_MAX_CHARS,
            label="financial_context",
        )

    @field_validator("write_confirmation")
    @classmethod
    def _cap_write_confirmation(cls, value: Optional[dict[str, Any]]):
        return _reject_oversized_mapping(
            value,
            limit=WRITE_CONFIRMATION_MAX_CHARS,
            label="write_confirmation",
        )


class ChatResponse(BaseModel):
    conversation_id: str
    response: str
    messages: list[dict]
    memory_correction: Optional[dict] = None
    memory_changes: Optional[dict] = None


def serialized_payload_length(value: Any) -> int:
    """Measure a payload the way the client does, so caps agree on both sides.

    The app trims its finance pack against `jsonEncode` length. Measuring a
    Python repr here instead would reject packs the app had already sized to
    fit, and the turn would silently lose its finance data.
    """
    try:
        return len(json.dumps(value, separators=(",", ":"), default=str))
    except (TypeError, ValueError):
        return len(str(value))


def _reject_oversized_mapping(
    value: Optional[dict[str, Any]],
    *,
    limit: int,
    label: str,
) -> Optional[dict[str, Any]]:
    if value is None:
        return None
    if serialized_payload_length(value) > limit:
        raise ValueError(f"{label} exceeds maximum size of {limit} characters.")
    return value
