"""Truth guard for false open-thread / goal mutation claims without a write."""

from __future__ import annotations

import re

from app.services.action_truth_policy import response_claims_unconfirmed_success

UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK = (
    "I can help with that, but I don't have a confirmed save or update from this "
    "turn. Tell me exactly what to change in Goals and I'll confirm before applying it."
)

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
_HARD_MUTATION_CLAIM_PATTERNS = (
    # Future commitment claims: "I'll update the sleep thread to 6am"
    re.compile(
        r"\b(?:i(?:'|’)?ll|i will|i am going to|i'm going to)\s+"
        r"(?:update|change|switch|adjust|set|move)\b"
        r".{0,80}\b(?:sleep|wake|thread|goal|target|schedule)\b",
        re.I,
    ),
    # Past / progressive: "I've updated…", "updating your sleep…"
    re.compile(
        r"\b(?:got it[, ]+)?(?:updating|updated|switching|switched|"
        r"changing|changed|adjusting|adjusted)\b"
        r".{0,60}\b(?:sleep|wake|thread|goal|target|schedule)\b",
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
    return response_claims_unconfirmed_success(cleaned) and bool(
        re.search(r"\b(?:goal|thread|wake|sleep schedule|target)\b", lowered)
    )


def safe_unexecuted_thread_or_goal_mutation_response(response: str) -> str:
    cleaned = response.strip()
    if not response_claims_thread_or_goal_mutation_success(cleaned):
        return cleaned
    return UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK
