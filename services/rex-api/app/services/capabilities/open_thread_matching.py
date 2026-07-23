"""Resolve open-thread create/update intents against active threads."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Optional

from app.services.capabilities.open_thread_title import (
    normalize_open_thread_title,
    short_summary_as_title,
    title_from_user_text,
)
from app.services.memory_discipline_similarity import (
    meaningful_tokens,
    normalize_text,
    normalized_similarity_score,
    token_overlap_score,
)

_TITLE_KEYS = (
    "title",
    "name",
    "new_title",
    "newTitle",
    "target_title",
    "targetTitle",
    "updated_title",
    "updatedTitle",
)
_SUMMARY_KEYS = (
    "summary",
    "reason",
    "why",
    "description",
    "details",
    "body",
    "note",
    "reminder",
)
_THREAD_ID_KEYS = ("thread_id", "threadId", "id")
_UPDATE_COMMAND_HINTS = (
    "update",
    "change",
    "edit",
    "rename",
    "set",
    "move",
    "switch",
    "adjust",
)
_EXISTING_THREAD_HINTS = (
    "existing",
    "current",
    "that thread",
    "this thread",
    "the thread",
    "thread we have",
    "open thread",
    "habit we have",
)
_GENERIC_MATCH_TOKENS = {
    "thread",
    "threads",
    "open",
    "habit",
    "habits",
    "update",
    "change",
    "edit",
    "rename",
    "remind",
    "reminder",
    "track",
    "goal",
    "goals",
    "existing",
    "current",
    "that",
    "this",
    "have",
    "everyday",
    "daily",
}
_CLOCK_PATTERN = re.compile(
    r"\b(\d{1,2}(?::\d{2})?)\s*(a\.?m\.?|p\.?m\.?)?\b",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ResolvedOpenThreadSuggestion:
    mode: str
    thread_id: Optional[str]
    title: str
    summary: Optional[str]
    existing_title: Optional[str]
    existing_summary: Optional[str]


def resolve_open_thread_suggestion(
    *,
    action_name: str,
    payload: dict[str, Any],
    threads: list[dict[str, Any]],
    user_text: str = "",
) -> Optional[ResolvedOpenThreadSuggestion]:
    """Return the best open-thread create/update action for the body."""
    summary = _summary_from_payload(payload)
    matched = match_existing_open_thread(
        payload=payload,
        threads=threads,
        user_text=user_text,
    )
    raw_title = _title_from_payload(payload) or title_from_user_text(user_text)

    if matched is not None:
        title = normalize_open_thread_title(raw_title or matched["title"], user_text=user_text)
        if not title:
            title = str(matched.get("title") or "").strip()
        return ResolvedOpenThreadSuggestion(
            mode="update",
            thread_id=str(matched.get("id") or "").strip() or None,
            title=title,
            summary=summary if summary is not None else _optional_str(matched.get("summary")),
            existing_title=_optional_str(matched.get("title")),
            existing_summary=_optional_str(matched.get("summary")),
        )

    title = normalize_open_thread_title(raw_title, user_text=user_text)

    if action_name == "update_open_thread":
        if len(threads) == 1:
            sole = threads[0]
            return ResolvedOpenThreadSuggestion(
                mode="update",
                thread_id=_optional_str(sole.get("id")),
                title=title or _optional_str(sole.get("title")) or "",
                summary=summary if summary is not None else _optional_str(sole.get("summary")),
                existing_title=_optional_str(sole.get("title")),
                existing_summary=_optional_str(sole.get("summary")),
            )
        if len(threads) > 1:
            return ResolvedOpenThreadSuggestion(
                mode="ask_which",
                thread_id=None,
                title=title or "this habit",
                summary=summary,
                existing_title=None,
                existing_summary=None,
            )
        return ResolvedOpenThreadSuggestion(
            mode="no_target",
            thread_id=None,
            title=title or "this habit",
            summary=summary,
            existing_title=None,
            existing_summary=None,
        )

    if len(threads) == 1:
        sole = threads[0]
        if looks_like_open_thread_update_request(user_text, payload=payload):
            return ResolvedOpenThreadSuggestion(
                mode="update",
                thread_id=_optional_str(sole.get("id")),
                title=title or _optional_str(sole.get("title")) or "",
                summary=summary if summary is not None else _optional_str(sole.get("summary")),
                existing_title=_optional_str(sole.get("title")),
                existing_summary=_optional_str(sole.get("summary")),
            )

    if not title:
        title = short_summary_as_title(summary)
    if not title:
        return None

    if len(threads) > 1 and looks_like_open_thread_update_request(user_text, payload=payload):
        return ResolvedOpenThreadSuggestion(
            mode="ask_which",
            thread_id=None,
            title=title,
            summary=summary,
            existing_title=None,
            existing_summary=None,
        )

    return ResolvedOpenThreadSuggestion(
        mode="create",
        thread_id=None,
        title=title,
        summary=summary,
        existing_title=None,
        existing_summary=None,
    )


def match_existing_open_thread(
    *,
    payload: dict[str, Any],
    threads: list[dict[str, Any]],
    user_text: str,
) -> Optional[dict[str, Any]]:
    """Best-effort match to an existing thread by id, title, time, or summary."""
    if not threads:
        return None

    thread_id = _thread_id_from_payload(payload) or _thread_id_from_text(user_text, threads)
    if thread_id:
        for thread in threads:
            if str(thread.get("id") or "").strip() == thread_id:
                return thread

    candidate_texts = _candidate_texts(payload=payload, user_text=user_text)
    if not candidate_texts:
        return None

    scored: list[tuple[float, dict[str, Any]]] = []
    for thread in threads:
        score = _score_thread(thread, candidate_texts)
        if score > 0:
            scored.append((score, thread))
    if not scored:
        return None

    scored.sort(key=lambda item: item[0], reverse=True)
    best_score, best_thread = scored[0]
    second_score = scored[1][0] if len(scored) > 1 else 0.0
    if best_score < 0.68:
        return None
    if second_score >= 0.68 and best_score - second_score < 0.08:
        return None
    return best_thread


def looks_like_open_thread_update_request(
    user_text: str,
    *,
    payload: Optional[dict[str, Any]] = None,
) -> bool:
    """Guard against creating duplicate threads when the user asked to edit one."""
    lowered = str(user_text or "").strip().casefold()
    if any(hint in lowered for hint in (*_UPDATE_COMMAND_HINTS, *_EXISTING_THREAD_HINTS)):
        return True
    if payload is not None and _thread_id_from_payload(payload):
        return True
    return False


def _score_thread(thread: dict[str, Any], candidate_texts: list[str]) -> float:
    title = str(thread.get("title") or "").strip()
    summary = str(thread.get("summary") or "").strip()
    title_norm = normalize_text(title)
    haystack = normalize_text(f"{title} {summary}")
    thread_clock = _clock_from_text(f"{title} {summary}")
    best = 0.0

    for candidate in candidate_texts:
        normalized = normalize_text(candidate)
        if not normalized:
            continue
        if normalized == title_norm:
            return 1.0
        if title_norm and normalized and (normalized in title_norm or title_norm in normalized):
            best = max(best, 0.9)
        overlap = token_overlap_score(candidate, haystack)
        similarity = normalized_similarity_score(candidate, title or summary)
        candidate_tokens = meaningful_tokens(candidate) - _GENERIC_MATCH_TOKENS
        thread_tokens = meaningful_tokens(haystack) - _GENERIC_MATCH_TOKENS
        if candidate_tokens and thread_tokens and candidate_tokens <= thread_tokens:
            best = max(best, 0.84)
        best = max(best, (overlap * 0.6) + (similarity * 0.4))
        candidate_clock = _clock_from_text(candidate)
        if candidate_clock and thread_clock and candidate_clock == thread_clock:
            best = max(best, 0.92)
    return min(best, 1.0)


def _candidate_texts(*, payload: dict[str, Any], user_text: str) -> list[str]:
    values: list[str] = []
    for key in (*_TITLE_KEYS, *_SUMMARY_KEYS, "existing_title", "existingTitle"):
        value = _optional_str(payload.get(key))
        if value:
            values.append(value)
    if user_text.strip():
        values.append(user_text.strip())
    deduped: list[str] = []
    seen: set[str] = set()
    for value in values:
        key = normalize_text(value)
        if not key or key in seen:
            continue
        seen.add(key)
        deduped.append(value)
    return deduped


def _title_from_payload(payload: dict[str, Any]) -> str:
    for key in _TITLE_KEYS:
        value = _optional_str(payload.get(key))
        if value:
            return value
    return ""


def _summary_from_payload(payload: dict[str, Any]) -> Optional[str]:
    for key in _SUMMARY_KEYS:
        if key not in payload:
            continue
        return _optional_str(payload.get(key))
    return None


def _thread_id_from_payload(payload: dict[str, Any]) -> Optional[str]:
    for key in _THREAD_ID_KEYS:
        value = _optional_str(payload.get(key))
        if value:
            return value
    return None


def _thread_id_from_text(user_text: str, threads: list[dict[str, Any]]) -> Optional[str]:
    lowered = str(user_text or "").casefold()
    for thread in threads:
        thread_id = str(thread.get("id") or "").strip()
        if thread_id and thread_id.casefold() in lowered:
            return thread_id
    return None


def _clock_from_text(text: str) -> Optional[str]:
    for match in _CLOCK_PATTERN.finditer(str(text or "")):
        clock = str(match.group(1) or "").strip()
        meridiem = str(match.group(2) or "").strip().casefold().replace(".", "")
        if not clock:
            continue
        suffix = meridiem[:2] if meridiem in {"am", "pm"} else ""
        return f"{clock}{suffix}"
    return None


def _optional_str(value: Any) -> Optional[str]:
    text = str(value or "").strip()
    return text or None
