"""Body-side open-thread user phrasing for Auto Suggestions Off (not a Grok brain)."""

from __future__ import annotations

import re
from typing import Literal

OpenThreadUserIntent = Literal["soft", "ask", "command"]

_SOFT_DESIRE = re.compile(
    r"\b(?:i want|i'd like|i would like|i wanna|wanna|i wish|hoping to|"
    r"trying to|i need to)\b",
    re.I,
)
_UPDATE_VERB = re.compile(
    r"\b(?:update|change|switch|rename|set|adjust|move)\b",
    re.I,
)
_POLITE_ASK = re.compile(
    r"\b(?:can you|could you|would you|will you|please)\b",
    re.I,
)
_IMPERATIVE_COMMAND = re.compile(
    r"^\s*(?:please\s+)?"
    r"(?:update|change|switch|rename|set|adjust)\b"
    r".{0,80}\b(?:thread|wake|sleep|schedule|\d+\s*(?:am|pm))\b",
    re.I,
)
_UPDATE_MY_THREAD = re.compile(
    r"\b(?:update|change|switch|set|adjust)\s+my\b"
    r".{0,60}\b(?:thread|wake|sleep|schedule|\d+\s*(?:am|pm))\b",
    re.I,
)


def classify_open_thread_user_intent(message: str) -> OpenThreadUserIntent:
    """Classify user phrasing for Off-mode open-thread gating.

    soft — desire only ("I want to wake at 6am") → coach, no propose
    ask — polite update request → text yes/no at most
    command — imperative update → apply when Off
    """
    text = str(message or "").strip()
    if not text:
        return "soft"
    if _IMPERATIVE_COMMAND.search(text) or (
        _UPDATE_MY_THREAD.search(text) and not _POLITE_ASK.search(text)
    ):
        return "command"
    if _UPDATE_VERB.search(text) and (
        _POLITE_ASK.search(text) or _SOFT_DESIRE.search(text)
    ):
        return "ask"
    if _UPDATE_VERB.search(text) and not _SOFT_DESIRE.search(text):
        return "command"
    if _SOFT_DESIRE.search(text):
        return "soft"
    return "soft"
