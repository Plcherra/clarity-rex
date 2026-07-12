"""Helpers for deriving short conversation titles from message text."""

from __future__ import annotations

CONVERSATION_TITLE_MAX_LENGTH = 48


def derive_conversation_title(
    content: str,
    *,
    max_length: int = CONVERSATION_TITLE_MAX_LENGTH,
) -> str:
    """Build a compact title from the first user message body."""
    return clamp_conversation_title(content, max_length=max_length)


def clamp_conversation_title(
    content: str,
    *,
    max_length: int = CONVERSATION_TITLE_MAX_LENGTH,
    empty_fallback: str = "New conversation",
) -> str:
    """Normalize and hard-cap a conversation title for storage/display."""
    text = " ".join((content or "").split()).strip()
    if not text:
        return empty_fallback
    if len(text) <= max_length:
        return text

    truncated = text[: max_length - 1].rsplit(" ", 1)[0].strip(".,;: ")
    if not truncated:
        truncated = text[: max_length - 1].rstrip()
    return f"{truncated}…"
