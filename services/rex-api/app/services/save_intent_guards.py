"""Shared guards for when a chat turn should not propose durable saves."""

from __future__ import annotations

import re

_EXPLICIT_SAVE_PATTERN = re.compile(
    r"\b(?:"
    r"(?:track|save|add)\s+.+\s+as\s+(?:a\s+)?(?:goal|plan|commitment)|"
    r"my\s+goal\s+is\b|"
    r"(?:remember|remind)\s+me\s+to\b|"
    r"(?:please\s+)?(?:save|track|add)\s+(?:this|that|it)\b"
    r")\b",
    re.IGNORECASE,
)

_ADVICE_QUESTION_PATTERN = re.compile(
    r"\b(?:"
    r"how\s+much|how\s+many|how\s+heavy|what\s+(?:size|weight|kind)|"
    r"do\s+you\s+think|would\s+you\s+recommend|"
    r"should\s+i\s+(?:get|buy)|can\s+you\s+(?:tell|help|advise)"
    r")\b",
    re.IGNORECASE,
)

_LEADING_QUESTION_PATTERN = re.compile(
    r"^\s*(?:how|what|which|when|where|why|who|should|can|could|would|do|did)\b",
    re.IGNORECASE,
)

_REMEMBER_ME_TO_PATTERN = re.compile(
    r"\b(?:remember|remind)\s+me\s+to\s+(?P<action>.+)",
    re.IGNORECASE,
)


def has_explicit_save_intent(message: str) -> bool:
    text = str(message or "").strip()
    if not text:
        return False
    return _EXPLICIT_SAVE_PATTERN.search(text) is not None


def is_advice_seeking_turn(message: str) -> bool:
    """True when the user is asking for guidance, not requesting a save."""
    text = str(message or "").strip()
    if len(text) < 8:
        return False
    if has_explicit_save_intent(text):
        return False
    if "?" in text:
        return True
    if _ADVICE_QUESTION_PATTERN.search(text):
        return True
    return _LEADING_QUESTION_PATTERN.search(text) is not None


def purchase_clause_from_message(message: str) -> str:
    """Extract the actionable purchase/reminder clause from a longer utterance."""
    text = str(message or "").strip()
    match = _REMEMBER_ME_TO_PATTERN.search(text)
    if match is None:
        return text
    action = re.sub(r"\s+", " ", match.group("action")).strip(" .,!?:;")
    return action or text
