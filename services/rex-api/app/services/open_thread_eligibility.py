"""Generic eligibility signals for open thread tracking offers."""

from __future__ import annotations

import re
from typing import Any, Optional

from app.services.memory_discipline_similarity import token_overlap_score

CASUAL_ONLY_PATTERNS = (
    re.compile(r"^\s*(hey|hi|hello|thanks|thank you|ok|okay|lol|haha|yep|nope)\s*[!.?]*\s*$", re.I),
)

RECALL_PATTERNS = (
    re.compile(r"\bdo you remember\b", re.I),
    re.compile(r"\bwhat did i say about\b", re.I),
    re.compile(r"\bsearch chats?\b", re.I),
    re.compile(r"\bwhat do you know about\b", re.I),
)

ONGOING_SIGNAL_PATTERNS = (
    re.compile(r"\bi(?:'m| am)\s+(?:trying|working|figuring|dealing|going)\b", re.I),
    re.compile(r"\bi(?:'ve| have)\s+been\b", re.I),
    re.compile(r"\bi want to\b", re.I),
    re.compile(r"\bi need to\b", re.I),
    re.compile(r"\bi plan to\b", re.I),
    re.compile(r"\bkeep(?:ing)?\s+(?:working|going|at it)\b", re.I),
    re.compile(r"\bstill\b.+\b(?:working|figuring|dealing|processing)\b", re.I),
    re.compile(r"\bongoing\b", re.I),
    re.compile(r"\bstruggling with\b", re.I),
)

EXPLICIT_TRACK_CONSENT_PATTERNS = (
    re.compile(r"\b(?:yes|yeah|yep|sure|ok(?:ay)?)\b.*\b(?:track|follow up|check in)\b", re.I),
    re.compile(r"\b(?:track|follow up on|keep track of)\b.+\b(?:this|that|it)\b", re.I),
    re.compile(r"\bkeep track of this\b", re.I),
    re.compile(r"\bcheck in (?:on|about) (?:this|that|it)\b", re.I),
)

EXPLICIT_TRACK_DECLINE_PATTERNS = (
    re.compile(r"\b(?:no|nope|don't|do not)\b.*\b(?:track|follow up|check in)\b", re.I),
    re.compile(r"\bnot now\b", re.I),
    re.compile(r"\bno thanks\b", re.I),
)

ONE_OFF_QUESTION_PATTERNS = (
    re.compile(r"^\s*(?:what|when|where|who|how much|how many)\b.+\?\s*$", re.I),
)


def is_casual_only_message(message: str) -> bool:
    return any(pattern.match(message) for pattern in CASUAL_ONLY_PATTERNS)


def is_recall_message(message: str) -> bool:
    return any(pattern.search(message) for pattern in RECALL_PATTERNS)


def is_one_off_factual_question(message: str) -> bool:
    if not message.strip().endswith("?"):
        return False
    return any(pattern.match(message) for pattern in ONE_OFF_QUESTION_PATTERNS)


def has_ongoing_personal_signal(message: str) -> bool:
    if len(message.strip()) < 20:
        return False
    return any(pattern.search(message) for pattern in ONGOING_SIGNAL_PATTERNS)


def is_explicit_track_consent(message: str) -> bool:
    return any(pattern.search(message) for pattern in EXPLICIT_TRACK_CONSENT_PATTERNS)


def is_explicit_track_decline(message: str) -> bool:
    return any(pattern.search(message) for pattern in EXPLICIT_TRACK_DECLINE_PATTERNS)


def is_bare_pending_offer_decline(message: str) -> bool:
    normalized = re.sub(r"[^a-z0-9']+", " ", message.strip().lower())
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized in {"no", "nope", "nah"}


def thread_offer_message_eligible(
    message: str,
    *,
    already_offered: bool,
    already_declined: bool,
    active_threads: Optional[list[dict[str, Any]]] = None,
    active_plans: Optional[list[dict[str, Any]]] = None,
    saved_memories: Optional[list[dict[str, Any]]] = None,
    active_entities: Optional[list[dict[str, Any]]] = None,
) -> bool:
    if already_offered or already_declined:
        return False
    if is_casual_only_message(message):
        return False
    if is_recall_message(message):
        return False
    if is_one_off_factual_question(message):
        return False
    if not has_ongoing_personal_signal(message):
        return False
    if active_threads is not None and topic_overlaps_existing_context(
        message,
        active_threads=active_threads,
        active_plans=active_plans or [],
        saved_memories=saved_memories or [],
        active_entities=active_entities or [],
    ):
        return False
    return True


def thread_offer_eligible(
    message: str,
    *,
    already_offered: bool,
    already_declined: bool,
    active_thread_count: int,
    max_active: int = 5,
    active_threads: Optional[list[dict[str, Any]]] = None,
    active_plans: Optional[list[dict[str, Any]]] = None,
    saved_memories: Optional[list[dict[str, Any]]] = None,
    active_entities: Optional[list[dict[str, Any]]] = None,
) -> bool:
    if active_thread_count >= max_active:
        return False
    return thread_offer_message_eligible(
        message,
        already_offered=already_offered,
        already_declined=already_declined,
        active_threads=active_threads,
        active_plans=active_plans,
        saved_memories=saved_memories,
        active_entities=active_entities,
    )


def infer_thread_title(message: str, *, max_length: int = 80) -> str:
    cleaned = re.sub(r"\s+", " ", message.strip())
    if len(cleaned) <= max_length:
        return cleaned
    truncated = cleaned[: max_length - 3].rstrip()
    last_space = truncated.rfind(" ")
    if last_space > 40:
        truncated = truncated[:last_space]
    return f"{truncated}..."


def thread_summary_from_message(message: str, *, max_length: int = 200) -> Optional[str]:
    cleaned = re.sub(r"\s+", " ", message.strip())
    if not cleaned:
        return None
    if len(cleaned) <= max_length:
        return cleaned
    return f"{cleaned[: max_length - 3].rstrip()}..."


def _context_text_fields(record: dict[str, Any]) -> list[str]:
    fields: list[str] = []
    for key in ("title", "summary", "description", "content", "display_name"):
        value = record.get(key)
        if isinstance(value, str) and value.strip():
            fields.append(value.strip())
    return fields


def topic_overlaps_existing_context(
    message: str,
    *,
    active_threads: list[dict[str, Any]],
    active_plans: list[dict[str, Any]],
    saved_memories: list[dict[str, Any]],
    active_entities: list[dict[str, Any]],
    threshold: float = 0.45,
) -> bool:
    candidates: list[str] = []
    for collection in (
        active_threads,
        active_plans,
        saved_memories,
        active_entities,
    ):
        for record in collection:
            if not isinstance(record, dict):
                continue
            candidates.extend(_context_text_fields(record))

    for candidate in candidates:
        if token_overlap_score(message, candidate) >= threshold:
            return True
    return False
