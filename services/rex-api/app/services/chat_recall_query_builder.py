"""Query construction helpers for past chat recall search."""

from __future__ import annotations

from typing import Callable, Optional

PAST_CHAT_SEARCH_PAGE_LIMIT = 200
PAST_CHAT_SHARED_SEARCH_QUERY_LIMIT = 10


def unique_search_queries(
    queries: list[tuple[str, str]],
) -> list[tuple[str, str]]:
    unique: list[tuple[str, str]] = []
    seen: set[str] = set()
    for search_query, query_mode in queries:
        normalized = " ".join(str(search_query or "").split())
        if not normalized or normalized.lower() in seen:
            continue
        seen.add(normalized.lower())
        unique.append((normalized, query_mode))
    return unique


def combined_past_chat_search_queries(
    query: str,
    *,
    raw_query: Optional[str],
    base_queries_for: Callable[[str], list[tuple[str, str]]],
) -> list[tuple[str, str]]:
    queries: list[tuple[str, str]] = []
    for candidate in (query, raw_query):
        if not str(candidate or "").strip():
            continue
        queries.extend(base_queries_for(str(candidate)))
    return unique_search_queries(queries)


def shared_conversation_search_queries(
    query: str,
    *,
    search_queries: list[tuple[str, str]],
) -> list[tuple[str, str]]:
    queries = unique_search_queries(
        [
            (query, "exact"),
            *search_queries,
        ]
    )
    priority = {
        "exact": 0,
        "subject": 1,
        "expanded_keywords": 2,
        "keyword": 3,
    }
    queries = sorted(
        queries,
        key=lambda item: (
            priority.get(item[1], 9),
            len(item[0]),
            item[0],
        ),
    )
    return queries[:PAST_CHAT_SHARED_SEARCH_QUERY_LIMIT]


def target_match_count(limit: int) -> int:
    return max(limit, min(PAST_CHAT_SEARCH_PAGE_LIMIT, limit * 2))
