"""Normalize open-thread habit titles (short labels, not user sentences)."""

from __future__ import annotations

import re
from typing import Optional

from app.services.conversation_pending_action import is_affirmative_confirmation

_CONVERSATIONAL_PREFIXES = (
    "i want",
    "i'd like",
    "i am thinking",
    "im thinking",
    "i'm thinking",
    "can you",
    "could you",
    "please ",
    "update my",
    "change my",
    "i need",
    "lets ",
    "let's ",
    "got it",
)

_WAKE_TIME_PATTERNS = (
    re.compile(
        r"(?:wak(?:e|ing)(?:\s*up)?|wake[- ]?up).{0,48}?"
        r"\b(?:at|to|for|around)\s+"
        r"(\d{1,2}(?::\d{2})?)\s*(a\.?m\.?|p\.?m\.?)?",
        re.I,
    ),
    re.compile(
        r"(?:waking\s+time|wake\s+time|sleep(?:ing)?\s+time).{0,48}?"
        r"\b(?:at|to|for|around)\s+"
        r"(\d{1,2}(?::\d{2})?)\s*(a\.?m\.?|p\.?m\.?)?",
        re.I,
    ),
)


def normalize_open_thread_title(
    raw: str,
    *,
    user_text: str = "",
) -> str:
    """Return a short habit title, or empty if none can be derived."""
    text = str(raw or "").strip()
    if text and not looks_like_conversational_title(text):
        return text
    derived = wake_title_from_text(text) or wake_title_from_text(user_text)
    return derived


def title_from_user_text(user_text: str) -> str:
    """Accept a typed short title, or derive Wake at X from a sentence."""
    text = str(user_text or "").strip()
    if not text or len(text) > 120 or text.endswith("?"):
        return ""
    if is_affirmative_confirmation(text):
        return ""
    lowered = text.lower()
    if lowered in {"no", "nope", "cancel", "never mind", "nevermind", "stop"}:
        return ""
    if looks_like_conversational_title(text):
        return wake_title_from_text(text)
    return text


def looks_like_conversational_title(text: str) -> bool:
    lowered = str(text or "").strip().lower()
    if not lowered:
        return False
    if any(lowered.startswith(prefix) for prefix in _CONVERSATIONAL_PREFIXES):
        return True
    # First-person chat sentences pasted as titles (keep real habit labels).
    if len(lowered) > 42 and (
        lowered.startswith("i ") or " i " in f" {lowered} "
    ):
        return True
    return False


def wake_title_from_text(text: str) -> str:
    cleaned = str(text or "").strip()
    if not cleaned:
        return ""
    for pattern in _WAKE_TIME_PATTERNS:
        match = pattern.search(cleaned)
        if not match:
            continue
        clock = _format_clock(match.group(1), match.group(2))
        if clock:
            return f"Wake at {clock}"
    return ""


def short_summary_as_title(summary: Optional[str]) -> str:
    text = str(summary or "").strip()
    if not text or len(text) > 80:
        return ""
    if looks_like_conversational_title(text):
        return wake_title_from_text(text)
    return text


def _format_clock(hour_min: str, meridiem: Optional[str]) -> str:
    raw = str(hour_min or "").strip()
    if not raw:
        return ""
    if ":" in raw:
        hour_s, minute_s = raw.split(":", 1)
        hour = int(hour_s)
        minute = int(minute_s)
        clock = f"{hour}:{minute:02d}"
    else:
        hour = int(raw)
        clock = str(hour)
    suffix = ""
    if meridiem:
        suffix = "am" if str(meridiem).lower().startswith("a") else "pm"
    elif hour <= 12:
        # Habit wake times without am/pm default to morning.
        suffix = "am"
    return f"{clock}{suffix}"
