from __future__ import annotations

import re
from difflib import SequenceMatcher
from typing import Any

from app.services.plan_intelligence_models import PLAN_INTELLIGENCE_VERSION


def append_unique_detail(existing: str, detail: str) -> str:
    existing = clean(existing)
    detail = clean(detail)
    if not detail:
        return existing
    if not existing:
        return detail
    if normalize_title(detail) in normalize_title(existing):
        return existing
    return f"{existing} Additional context: {detail}"


def similarity(left: str, right: str) -> float:
    left_tokens = tokens(left)
    right_tokens = tokens(right)
    if not left_tokens or not right_tokens:
        return 0.0
    overlap = len(left_tokens & right_tokens) / len(left_tokens | right_tokens)
    sequence = SequenceMatcher(None, left, right).ratio()
    return (overlap * 0.68) + (sequence * 0.32)


def candidate_text(candidate: dict[str, Any]) -> str:
    return join_parts(
        candidate.get("plan_type"),
        candidate.get("title"),
        candidate.get("description"),
        candidate.get("desired_outcome"),
        candidate.get("entity_name"),
    ).lower()


def record_text(record: dict[str, Any]) -> str:
    return join_parts(
        record.get("plan_type"),
        record.get("title"),
        record.get("description"),
        record.get("desired_outcome"),
        record.get("relationship"),
        record.get("summary"),
    ).lower()


def tokens(value: str) -> set[str]:
    return {
        token
        for token in re.findall(r"[a-z0-9]+", str(value).lower())
        if len(token) > 2 and token not in STOP_WORDS
    }


def context_records(context: Any, field: str) -> list[dict[str, Any]]:
    if isinstance(context, dict):
        return list(context.get(field) or [])
    return list(getattr(context, field, []) or [])


def records_from_related(context: Any, field: str) -> list[dict[str, Any]]:
    related = context_records(context, field)
    records = []
    for item in related:
        if isinstance(item, dict):
            records.append(item.get("record") or item)
        else:
            records.append(getattr(item, "record", {}) or {})
    return records


def route_metadata(reason: str, score: float) -> dict[str, Any]:
    return {
        "plan_intelligence_version": PLAN_INTELLIGENCE_VERSION,
        "plan_intelligence_reason": reason,
        "parent_plan_score": round(score, 4),
    }


def join_parts(*parts: Any) -> str:
    return " ".join(clean(part) for part in parts if clean(part))


def clean(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return " ".join(clean(item) for item in value)
    return re.sub(r"\s+", " ", str(value)).strip()


def drop_none(payload: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in payload.items() if value is not None}


def normalize_title(value: str) -> str:
    return " ".join(
        token
        for token in re.findall(r"[a-z0-9]+", value.lower())
        if token not in STOP_WORDS
    )


STOP_WORDS = {
    "about",
    "after",
    "again",
    "also",
    "and",
    "are",
    "for",
    "from",
    "have",
    "into",
    "next",
    "not",
    "out",
    "that",
    "the",
    "this",
    "user",
    "with",
    "year",
}
