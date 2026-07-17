"""Topic overlap helpers for open-thread create suppression and updates."""

from __future__ import annotations

import re
from typing import Any, Optional

from app.services.memory_discipline_similarity import token_overlap_score

_CLOCK_TIME_RE = re.compile(r"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b", re.I)


def context_text_fields(record: dict[str, Any]) -> list[str]:
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
            candidates.extend(context_text_fields(record))

    for candidate in candidates:
        if token_overlap_score(message, candidate) >= threshold:
            return True
    return False


def find_overlapping_active_thread(
    message: str,
    active_threads: list[dict[str, Any]],
    *,
    threshold: float = 0.45,
) -> Optional[dict[str, Any]]:
    """Return the best-matching active open thread for this message, if any."""
    best: Optional[dict[str, Any]] = None
    best_score = threshold
    for record in active_threads:
        if not isinstance(record, dict):
            continue
        score = 0.0
        for field in context_text_fields(record):
            score = max(score, token_overlap_score(message, field))
        if score >= best_score:
            best_score = score
            best = record
    return best


def _normalize_clock_token(hour: str, minute: str | None, meridiem: str) -> str:
    minute_part = minute or "00"
    return f"{int(hour)}:{minute_part}{meridiem.lower()}"


def _clock_tokens(text: str) -> set[str]:
    found: set[str] = set()
    for match in _CLOCK_TIME_RE.finditer(text or ""):
        found.add(_normalize_clock_token(match.group(1), match.group(2), match.group(3)))
        found.add(f"{int(match.group(1))}{match.group(3).lower()}")
    return found


def find_thread_for_explicit_update(
    message: str,
    active_threads: list[dict[str, Any]],
) -> Optional[dict[str, Any]]:
    """Resolve a thread for an explicit update command (looser than auto overlap)."""
    overlap = find_overlapping_active_thread(
        message,
        active_threads,
        threshold=0.25,
    )
    if overlap is not None:
        return overlap

    message_times = _clock_tokens(message)
    if message_times:
        timed_matches: list[dict[str, Any]] = []
        for record in active_threads:
            if not isinstance(record, dict):
                continue
            blob = " ".join(context_text_fields(record))
            thread_times = _clock_tokens(blob)
            compact_blob = re.sub(r"\s+", "", blob.casefold())
            if message_times & thread_times:
                timed_matches.append(record)
                continue
            if any(token in compact_blob for token in message_times):
                timed_matches.append(record)
        if len(timed_matches) == 1:
            return timed_matches[0]

    if len(active_threads) == 1 and re.search(
        r"\b(?:my|the|that)\b.{0,40}\bthread\b",
        message,
        flags=re.I,
    ):
        only = active_threads[0]
        return only if isinstance(only, dict) else None
    return None
