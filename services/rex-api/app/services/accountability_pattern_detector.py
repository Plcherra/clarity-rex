from datetime import datetime, timezone

from app.models.accountability import AccountabilitySignal, AccountabilitySourceRef
from app.services.accountability_shared import (
    PATTERN_CATEGORIES,
    PATTERN_LOOKBACK_DAYS,
    PATTERN_MIN_OCCURRENCES,
    contains_term,
    is_recent_pattern_record,
    normalize_text,
    pattern_record_time,
)
from app.services.entity_service import (
    entity_event_accountability_text,
    is_active_entity_event,
)
from app.services.memory_service import is_active_memory, memory_accountability_text


def detect_repeated_patterns(
    *,
    message: str,
    entity_events: list[dict],
    relevant_memories: list[dict],
    current_time: datetime,
) -> list[AccountabilitySignal]:
    normalized_message = normalize_text(message)
    matched_categories = matched_pattern_categories(normalized_message)
    if not matched_categories:
        return []

    signals = []
    for category in matched_categories:
        related_records = related_pattern_records(
            category=category,
            entity_events=entity_events,
            relevant_memories=relevant_memories,
            current_time=current_time,
        )
        total_occurrences = len(related_records) + 1
        if total_occurrences < PATTERN_MIN_OCCURRENCES:
            continue

        signals.append(
            repeated_pattern_signal(
                category=category,
                related_records=related_records,
                total_occurrences=total_occurrences,
            )
        )
    return signals


def matched_pattern_categories(normalized_message: str) -> list[str]:
    categories = []
    for category, config in PATTERN_CATEGORIES.items():
        terms = set(config["terms"])
        if matched_pattern_terms(normalized_message, terms):
            categories.append(category)
    return categories


def related_pattern_records(
    *,
    category: str,
    entity_events: list[dict],
    relevant_memories: list[dict],
    current_time: datetime,
) -> list[dict]:
    terms = set(PATTERN_CATEGORIES[category]["terms"])
    records = []

    for memory in relevant_memories:
        if not is_active_memory(memory):
            continue
        if not is_recent_pattern_record(memory, current_time):
            continue
        text = normalize_text(memory_accountability_text(memory))
        matched_terms = matched_pattern_terms(text, terms)
        if matched_terms:
            records.append(
                {
                    "source_type": "long_term_memory",
                    "source": memory,
                    "matched_terms": matched_terms,
                    "timestamp": pattern_record_time(memory),
                }
            )

    for event in entity_events:
        if not is_active_entity_event(event):
            continue
        if not is_recent_pattern_record(event, current_time):
            continue
        text = normalize_text(entity_event_accountability_text(event))
        matched_terms = matched_pattern_terms(text, terms)
        if matched_terms:
            records.append(
                {
                    "source_type": "entity_event",
                    "source": event,
                    "matched_terms": matched_terms,
                    "timestamp": pattern_record_time(event),
                }
            )

    records.sort(
        key=lambda record: record["timestamp"]
        or datetime.min.replace(tzinfo=timezone.utc),
        reverse=True,
    )
    return records


def matched_pattern_terms(normalized_text: str, terms: set[str]) -> list[str]:
    return sorted(term for term in terms if contains_term(normalized_text, term))


def repeated_pattern_signal(
    *,
    category: str,
    related_records: list[dict],
    total_occurrences: int,
) -> AccountabilitySignal:
    config = PATTERN_CATEGORIES[category]
    label = str(config["label"])
    matched_terms = sorted(
        {term for record in related_records for term in record["matched_terms"]}
    )
    source_counts = {
        "long_term_memory": sum(
            1
            for record in related_records
            if record["source_type"] == "long_term_memory"
        ),
        "entity_event": sum(
            1 for record in related_records if record["source_type"] == "entity_event"
        ),
    }

    return AccountabilitySignal(
        signal_type="repeated_pattern",
        title=f"Repeated pattern: {label}",
        summary=f"This looks like the latest instance of a recurring {label} pattern.",
        reason=(
            f"Found {len(related_records)} recent related record(s), plus the "
            "current message, inside the lookback window."
        ),
        severity="high" if total_occurrences >= 5 else "medium",
        confidence=min(0.92, 0.58 + (0.08 * total_occurrences)),
        source_refs=[pattern_source_ref(record) for record in related_records[:3]],
        suggested_prompt=f"This is not isolated. It matches a recent {label} pattern.",
        recommended_action=(
            "Name the pattern directly, then ask what changed this time and "
            "what concrete adjustment prevents the next repeat."
        ),
        metadata={
            "category": category,
            "label": label,
            "matched_terms": matched_terms,
            "historical_occurrence_count": len(related_records),
            "occurrence_count": total_occurrences,
            "lookback_days": PATTERN_LOOKBACK_DAYS,
            "source_counts": source_counts,
        },
    )


def pattern_source_ref(record: dict) -> AccountabilitySourceRef:
    source = record["source"]
    source_type = record["source_type"]
    if source_type == "long_term_memory":
        return AccountabilitySourceRef(
            source_type="long_term_memory",
            source_id=str(source.get("id")) if source.get("id") else None,
            title=str(source.get("memory_type") or "Memory"),
            excerpt=str(source.get("content") or "") or None,
            metadata={"matched_terms": record["matched_terms"]},
        )

    return AccountabilitySourceRef(
        source_type="entity_event",
        source_id=str(source.get("id")) if source.get("id") else None,
        title=str(source.get("title") or source.get("event_type") or "Event"),
        excerpt=str(source.get("content") or "") or None,
        metadata={"matched_terms": record["matched_terms"]},
    )
