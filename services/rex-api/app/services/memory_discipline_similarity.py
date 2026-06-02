import re
from difflib import SequenceMatcher
from typing import Any, Optional

from app.models.memory_discipline import MemoryDisciplineCandidate


def record_similarity(
    candidate: MemoryDisciplineCandidate,
    candidate_text: str,
    table: str,
    record: dict[str, Any],
) -> tuple[float, str]:
    if same_source(candidate, record):
        return 1.0, "same_source"

    record_text = record_text_for_table(table, record)
    if not candidate_text or not record_text:
        return 0.0, "empty_text"

    title_score = title_similarity_score(candidate.payload, record)
    token_score = token_overlap_score(candidate_text, record_text)
    sequence_score = normalized_similarity_score(candidate_text, record_text)
    alias_score = entity_alias_score(candidate_text, record)
    type_score = type_match_score(candidate, record)

    if token_score == 0 and alias_score == 0:
        if title_score >= 0.55:
            return title_score, "title_similarity"
        return 0.0, "no_overlap"

    score = max(
        title_score,
        alias_score,
        (token_score * 0.55) + (sequence_score * 0.35) + (type_score * 0.10),
    )
    reason = "text_similarity"
    if alias_score >= score and alias_score > 0:
        reason = "entity_alias"
    elif title_score >= score and title_score > 0:
        reason = "title_similarity"
    elif type_score > 0:
        reason = "type_and_text_similarity"
    return min(1.0, score), reason


def candidate_record_text(payload: dict[str, Any]) -> str:
    parts: list[str] = []
    for field_name in (
        "title",
        "display_name",
        "normalized_name",
        "content",
        "summary",
        "description",
        "desired_outcome",
        "relationship",
        "rule_text",
        "commitment_text",
        "plan_type",
        "entity_type",
        "rule_type",
        "commitment_type",
    ):
        value = payload.get(field_name)
        if value:
            parts.append(str(value))
    for value in payload.get("aliases") or []:
        parts.append(str(value))
    for value in payload.get("trigger_keywords") or []:
        parts.append(str(value))
    return normalize_text(" ".join(parts))


def record_text_for_table(table: str, record: dict[str, Any]) -> str:
    return candidate_record_text(record)


def title_similarity_score(candidate_payload: dict[str, Any], record: dict[str, Any]) -> float:
    candidate_title = normalize_text(
        candidate_payload.get("title")
        or candidate_payload.get("display_name")
        or candidate_payload.get("content")
        or ""
    )
    record_title_text = normalize_text(
        record.get("title") or record.get("display_name") or record.get("content") or ""
    )
    if not candidate_title or not record_title_text:
        return 0.0
    return normalized_similarity_score(candidate_title, record_title_text)


def token_overlap_score(left: str, right: str) -> float:
    left_tokens = meaningful_tokens(left)
    right_tokens = meaningful_tokens(right)
    if not left_tokens or not right_tokens:
        return 0.0
    overlap = len(left_tokens & right_tokens)
    return overlap / min(len(left_tokens), len(right_tokens))


def normalized_similarity_score(left: str, right: str) -> float:
    left = normalize_text(left)
    right = normalize_text(right)
    if not left or not right:
        return 0.0
    return SequenceMatcher(None, left, right).ratio()


def entity_alias_score(candidate_text: str, record: dict[str, Any]) -> float:
    aliases = [
        normalize_text(alias)
        for alias in record.get("aliases") or []
        if normalize_text(alias)
    ]
    normalized_candidate = normalize_text(candidate_text)
    if not aliases or not normalized_candidate:
        return 0.0
    candidate_tokens = meaningful_tokens(normalized_candidate)
    for alias in aliases:
        if alias == normalized_candidate:
            return 1.0
        if alias in normalized_candidate:
            return 0.92
        alias_tokens = meaningful_tokens(alias)
        if alias_tokens and alias_tokens <= candidate_tokens:
            return 0.88
    return 0.0


def type_match_score(candidate: MemoryDisciplineCandidate, record: dict[str, Any]) -> float:
    for field_name in (
        "entity_type",
        "plan_type",
        "rule_type",
        "commitment_type",
        "milestone_type",
        "memory_type",
    ):
        candidate_value = candidate.payload.get(field_name)
        record_value = record.get(field_name)
        if candidate_value and record_value and candidate_value == record_value:
            return 1.0
    return 0.0


def normalize_text(value: Any) -> str:
    text = re.sub(r"[^a-z0-9$]+", " ", str(value or "").casefold())
    return re.sub(r"\s+", " ", text).strip()


def meaningful_tokens(value: Any) -> set[str]:
    tokens = set(normalize_text(value).split())
    return {
        token
        for token in tokens
        if len(token) > 1
        and token
        not in {
            "a",
            "an",
            "and",
            "for",
            "in",
            "of",
            "on",
            "or",
            "the",
            "to",
            "with",
        }
    }


def record_title(record: dict[str, Any]) -> Optional[str]:
    for field_name in ("title", "display_name", "content", "rule_text"):
        value = record.get(field_name)
        if value:
            return str(value)
    return None


def same_source(candidate: MemoryDisciplineCandidate, record: dict[str, Any]) -> bool:
    for field_name in (
        "source_memory_id",
        "source_message_id",
        "source_conversation_id",
    ):
        candidate_value = getattr(candidate, field_name)
        record_value = record.get(field_name)
        if candidate_value and record_value and str(candidate_value) == str(record_value):
            return True
    return False
