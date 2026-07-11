"""Helpers for deriving short conversation titles from message text."""

from __future__ import annotations

_DEFAULT_TITLE_MAX_LENGTH = 60


def derive_conversation_title(
    content: str,
    *,
    max_length: int = _DEFAULT_TITLE_MAX_LENGTH,
) -> str:
    """Build a compact title from the first user message body."""
    text = " ".join((content or "").split()).strip()
    if not text:
        return "New conversation"
    if len(text) <= max_length:
        return text

    truncated = text[: max_length - 1].rsplit(" ", 1)[0].strip(".,;: ")
    if not truncated:
        truncated = text[: max_length - 1].rstrip()
    return f"{truncated}…"
