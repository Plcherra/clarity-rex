from __future__ import annotations

import argparse
import asyncio
import json
import os
from dataclasses import dataclass

from app.services.http_client import shutdown_http_client
from app.services.memory_service import SupabaseMemoryService


DEFAULT_LIMIT = 20


@dataclass(frozen=True)
class QueryCheck:
    kind: str
    query: str
    user_a_count: int
    user_b_count: int
    shared_conversation_ids: list[str]
    user_a_match_types: list[str]
    user_b_match_types: list[str]

    @property
    def passed(self) -> bool:
        if self.kind == "expected_empty":
            return self.user_a_count == 0 and self.user_b_count == 0
        if self.kind == "leakage":
            return (
                self.user_a_count > 0
                and self.user_b_count == 0
                and not self.shared_conversation_ids
            )
        return self.user_a_count > 0 and not self.shared_conversation_ids


def _csv_env(name: str) -> list[str]:
    value = os.getenv(name, "")
    return [item.strip() for item in value.split(",") if item.strip()]


def _redacted_results(results: list[dict]) -> list[dict]:
    redacted = []
    for result in results:
        message = result.get("message")
        redacted.append(
            {
                "conversation_id": result.get("conversation_id"),
                "match_type": result.get("match_type"),
                "matched_terms": result.get("matched_terms") or [],
                "has_message": isinstance(message, dict),
            }
        )
    return redacted


def _match_types(results: list[dict]) -> list[str]:
    return sorted(
        {
            str(result.get("match_type") or "unknown")
            for result in results
        }
    )


async def _search(access_token: str, query: str, *, limit: int) -> list[dict]:
    service = SupabaseMemoryService(access_token=access_token)
    return await service.search_conversations(query, limit=limit)


async def verify_query(
    query: str,
    *,
    kind: str,
    user_a_token: str,
    user_b_token: str,
    limit: int,
) -> tuple[QueryCheck, dict]:
    user_a_results = await _search(user_a_token, query, limit=limit)
    user_b_results = await _search(user_b_token, query, limit=limit)
    user_a_conversation_ids = {
        str(result.get("conversation_id") or "")
        for result in user_a_results
        if str(result.get("conversation_id") or "")
    }
    user_b_conversation_ids = {
        str(result.get("conversation_id") or "")
        for result in user_b_results
        if str(result.get("conversation_id") or "")
    }
    shared_conversation_ids = sorted(
        user_a_conversation_ids.intersection(user_b_conversation_ids)
    )
    check = QueryCheck(
        kind=kind,
        query=query,
        user_a_count=len(user_a_results),
        user_b_count=len(user_b_results),
        shared_conversation_ids=shared_conversation_ids,
        user_a_match_types=_match_types(user_a_results),
        user_b_match_types=_match_types(user_b_results),
    )
    detail = {
        "kind": kind,
        "query": query,
        "user_a_results": _redacted_results(user_a_results),
        "user_b_results": _redacted_results(user_b_results),
        "shared_conversation_ids": shared_conversation_ids,
        "user_a_match_types": check.user_a_match_types,
        "user_b_match_types": check.user_b_match_types,
    }
    return check, detail


async def async_main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Verify live Supabase chat search RPC behavior with two authenticated "
            "users. Requires SUPABASE_URL, SUPABASE_ANON_KEY, "
            "CLARITY_VERIFY_USER_A_TOKEN, and CLARITY_VERIFY_USER_B_TOKEN."
        )
    )
    parser.add_argument(
        "--query",
        action="append",
        dest="queries",
        help=(
            "Seeded query expected to return results for user A. May be repeated. "
            "Defaults to CLARITY_VERIFY_CHAT_QUERIES comma-separated values."
        ),
    )
    parser.add_argument(
        "--leak-query",
        action="append",
        dest="leak_queries",
        help=(
            "Unique user-A query that must return no results for user B. May be "
            "repeated. Defaults to CLARITY_VERIFY_LEAK_QUERIES comma-separated values."
        ),
    )
    parser.add_argument(
        "--empty-query",
        action="append",
        dest="empty_queries",
        help=(
            "Query expected to return no results for either user. May be repeated. "
            "Defaults to CLARITY_VERIFY_EMPTY_QUERIES comma-separated values."
        ),
    )
    parser.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    args = parser.parse_args()

    user_a_token = os.getenv("CLARITY_VERIFY_USER_A_TOKEN", "").strip()
    user_b_token = os.getenv("CLARITY_VERIFY_USER_B_TOKEN", "").strip()
    queries = args.queries or _csv_env("CLARITY_VERIFY_CHAT_QUERIES")
    leak_queries = args.leak_queries or _csv_env("CLARITY_VERIFY_LEAK_QUERIES")
    empty_queries = args.empty_queries or _csv_env("CLARITY_VERIFY_EMPTY_QUERIES")
    planned_checks = [
        *[("expected_hit", query) for query in queries],
        *[("leakage", query) for query in leak_queries],
        *[("expected_empty", query) for query in empty_queries],
    ]
    if not user_a_token or not user_b_token:
        raise SystemExit(
            "Missing CLARITY_VERIFY_USER_A_TOKEN or CLARITY_VERIFY_USER_B_TOKEN."
        )
    if not planned_checks:
        raise SystemExit(
            "Provide --query, --leak-query, --empty-query, or matching env vars."
        )

    checks = []
    details = []
    try:
        for kind, query in planned_checks:
            check, detail = await verify_query(
                query,
                kind=kind,
                user_a_token=user_a_token,
                user_b_token=user_b_token,
                limit=max(1, min(args.limit, 200)),
            )
            checks.append(check)
            details.append(detail)
    finally:
        await shutdown_http_client()

    failures = [check for check in checks if not check.passed]
    summary = {
        "passed": not failures,
        "checks": [
            {
                "kind": check.kind,
                "query": check.query,
                "passed": check.passed,
                "user_a_count": check.user_a_count,
                "user_b_count": check.user_b_count,
                "user_a_match_types": check.user_a_match_types,
                "user_b_match_types": check.user_b_match_types,
                "shared_conversation_ids": check.shared_conversation_ids,
            }
            for check in checks
        ],
        "failure_count": len(failures),
        "details": details,
    }
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary["passed"] else 1


def main() -> None:
    raise SystemExit(asyncio.run(async_main()))


if __name__ == "__main__":
    main()
