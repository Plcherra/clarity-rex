"""Detects a reply claiming a goal or thread change that has not happened yet.

Used only where a write is genuinely still pending — a confirm card is on
screen and "I've updated your goal" would be false. Turns with no write of any
kind keep Grok's own words; canned Goals copy used to swallow real answers.
"""

from __future__ import annotations

import re

from app.services.action_truth_policy import response_claims_unconfirmed_success

_CONFIRMATION_HINTS = (
    "confirm",
    "approve",
    "should i",
    "want me to",
    "before i",
    "pending",
    "proposal",
    "would you like me to",
)

# Always blocked — even when soft confirm language is also present.
# Avoid bare "Updating…" coaching (no first person / no "got it" claim).
_HARD_MUTATION_CLAIM_PATTERNS = (
    # Future commitment claims: "I'll update the sleep thread to 6am"
    re.compile(
        r"\b(?:i(?:'|’)?ll|i will|i am going to|i'm going to)\s+"
        r"(?:update|change|switch|adjust|set|move)\b"
        r".{0,80}\b(?:sleep|wake|thread|goal|target|schedule)\b",
        re.I,
    ),
    # First-person past / progressive: "I've updated…", "I'm updating…"
    re.compile(
        r"\b(?:i(?:'|’)?ve|i have|i(?:'|’)?m|i am)\s+"
        r"(?:updating|updated|switching|switched|changing|changed|"
        r"adjusting|adjusted)\b"
        r".{0,60}\b(?:sleep|wake|thread|goal|target|schedule)\b",
        re.I,
    ),
    # "Got it—updating your sleep…" false in-progress claim
    re.compile(
        r"\bgot it\b.{0,24}\b(?:updating|updated|switching|switched|"
        r"changing|changed|adjusting|adjusted)\b"
        r".{0,60}\b(?:sleep|wake|thread|goal|target|schedule)\b",
        re.I,
    ),
    # "updated your sleep thread" without a pending confirm framing
    re.compile(
        r"\b(?:updated|changed|switched|adjusted)\s+(?:your|the)\b"
        r".{0,40}\b(?:sleep|wake|thread|goal|target|schedule)\b",
        re.I,
    ),
    re.compile(
        r"\b(?:now tracking|started tracking|i(?:'| a)?m tracking)\b",
        re.I,
    ),
    re.compile(
        r"\b(?:your|the)\s+(?:sleep\s+)?(?:goal|thread|target|wake[- ]?up)"
        r".{0,40}\b(?:is now|to|updated|changed)\b",
        re.I,
    ),
    re.compile(
        r"\b(?:shifts?|shifted|moved)\s+from\s+the\s+prior\b",
        re.I,
    ),
)

# Bare "update … thread" — allow when asking permission ("Want me to update…?").
_SOFT_UPDATE_CLAIM_PATTERN = re.compile(
    r"\b(?:got it[, ]+)?update\b"
    r".{0,60}\b(?:sleep|wake|thread|goal|target|schedule)\b",
    re.I,
)


def response_claims_thread_or_goal_mutation_success(response: str) -> bool:
    cleaned = response.strip()
    if not cleaned:
        return False
    if any(pattern.search(cleaned) for pattern in _HARD_MUTATION_CLAIM_PATTERNS):
        return True
    lowered = f" {cleaned.lower()} "
    if any(hint in lowered for hint in _CONFIRMATION_HINTS):
        return False
    if _SOFT_UPDATE_CLAIM_PATTERN.search(cleaned):
        return True
    # Require goal/thread wording — bare "wake" matches coaching too often.
    return response_claims_unconfirmed_success(cleaned) and bool(
        re.search(r"\b(?:goal|thread|sleep schedule)\b", lowered)
    )
