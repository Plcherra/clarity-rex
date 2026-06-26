"""Match scoring helpers for past chat recall search."""

from __future__ import annotations

import re

from app.services.chat_recall_filters import (
    is_chat_search_no_result_message,
    is_chat_search_user_content_message,
)

SHARED_SEARCH_STRONG_MATCH_SCORE = 6.0
SHARED_SEARCH_MIN_FACTUAL_MATCHES = 3


def add_best_message(messages_by_id: dict[str, dict], message: dict) -> None:
    message_id = str(message.get("id") or "")
    if not message_id:
        return
    existing = messages_by_id.get(message_id)
    if existing is None or (
        message.get("_chat_search_score", 0)
        > existing.get("_chat_search_score", 0)
    ):
        messages_by_id[message_id] = message


def is_viable_chat_match(message: dict) -> bool:
    if is_chat_search_no_result_message(message):
        return False
    if float(message.get("_chat_search_score") or 0) > 0:
        return True
    return bool(str(message.get("content") or "").strip())


def viable_match_count(messages_by_id: dict[str, dict]) -> int:
    return sum(
        1 for message in messages_by_id.values() if is_viable_chat_match(message)
    )


def factual_user_match_count(messages_by_id: dict[str, dict]) -> int:
    return sum(
        1
        for message in messages_by_id.values()
        if is_chat_search_user_content_message(message)
    )


def detail_rich_match_count(messages_by_id: dict[str, dict]) -> int:
    return sum(
        1
        for message in messages_by_id.values()
        if is_chat_search_user_content_message(message)
        and message_has_recall_detail(message)
    )


def best_match_score(messages_by_id: dict[str, dict]) -> float:
    return max(
        (
            float(message.get("_chat_search_score") or 0)
            for message in messages_by_id.values()
            if is_viable_chat_match(message)
        ),
        default=0.0,
    )


def query_needs_detail(query: str) -> bool:
    text = str(query or "").lower()
    return bool(
        re.search(
            r"\b(?:amount|birthday|date|for what|how much|june|when|why|\d{1,2})\b",
            text,
        )
    )


def message_has_recall_detail(message: dict) -> bool:
    text = str(message.get("content") or "").lower()
    if not text:
        return False
    return bool(
        re.search(
            r"\$\s*\d|\b\d+(?:\.\d{2})?\b|\b(?:birthday|june|model|for\s+her|"
            r"for\s+his|for\s+their|bought|purchased|downloaded|gog|steam)\b",
            text,
        )
    )


def has_strong_shared_search_signal(
    query: str,
    messages_by_id: dict[str, dict],
    *,
    target_match_count: int,
) -> bool:
    factual_count = factual_user_match_count(messages_by_id)
    detail_count = detail_rich_match_count(messages_by_id)
    if query_needs_detail(query):
        return detail_count >= min(
            SHARED_SEARCH_MIN_FACTUAL_MATCHES,
            target_match_count,
        )
    if detail_count >= min(SHARED_SEARCH_MIN_FACTUAL_MATCHES, target_match_count):
        return True
    if factual_count >= min(SHARED_SEARCH_MIN_FACTUAL_MATCHES, target_match_count):
        return detail_count >= 1
    return (
        factual_count >= 2
        and detail_count >= 1
        and best_match_score(messages_by_id) >= SHARED_SEARCH_STRONG_MATCH_SCORE
    )
