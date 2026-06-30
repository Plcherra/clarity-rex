from typing import Any

from app.services.memory_reference_models import KnowsReferenceMatch
from app.services.memory_text_normalization import clean_text, normalized_text

GENERIC_REFERENCE_TERMS = {
    "a",
    "an",
    "card",
    "delete",
    "inside",
    "item",
    "memory",
    "note",
    "record",
    "saved",
    "that",
    "the",
    "this",
}


def reference_matches_visible_item(
    reference_key: str,
    item: KnowsReferenceMatch,
) -> bool:
    searchable_values = [
        item.title,
        *_record_kind_labels(item.table, item.record),
        *_record_visible_text_fields(item.table, item.record),
    ]
    if item.attribute_key and item.attribute_value:
        searchable_values.extend(
            [
                item.attribute_key,
                item.attribute_value,
                f"{display_attribute_label(item.attribute_key)} {item.attribute_value}",
            ]
        )
    haystack = normalized_text(searchable_values)
    if not haystack:
        return False
    if reference_key in haystack:
        return True
    terms = [term for term in reference_key.split() if term not in GENERIC_REFERENCE_TERMS]
    return bool(terms) and all(term in haystack for term in terms)


def dedupe_knows_matches(
    matches: list[KnowsReferenceMatch],
) -> list[KnowsReferenceMatch]:
    deduped: list[KnowsReferenceMatch] = []
    seen: set[tuple[str, str, str, str]] = set()
    for match in matches:
        key = (
            match.table,
            match.id,
            match.action,
            match.attribute_key or "",
        )
        if key in seen:
            continue
        seen.add(key)
        deduped.append(match)
    return deduped


def display_attribute_label(attribute_key: str) -> str:
    return attribute_key.replace("_", " ").title()


def _record_kind_labels(table: str, record: dict[str, Any]) -> list[str]:
    labels: list[str] = []
    if table == "long_term_memory":
        labels.extend(
            _memory_kind_labels(
                record.get("memory_type"),
                record.get("metadata"),
            )
        )
    elif table == "entity_events":
        labels.extend(["event", "events", "entity event"])
        labels.append(clean_text(record.get("event_type")))
    elif table == "entities":
        entity_type = clean_text(record.get("entity_type"))
        if entity_type:
            labels.extend([entity_type, f"{entity_type} card"])
            if entity_type == "person":
                labels.append("people")
        labels.append(clean_text(record.get("relationship")))
    elif table == "plans":
        labels.extend(["plan", "plans", "goal", "goals"])
        labels.append(clean_text(record.get("plan_type")))
    elif table == "commitments":
        labels.extend(["commitment", "commitments", "goal", "goals", "task"])
        labels.append(clean_text(record.get("commitment_type")))
    return [label for label in labels if label]


def _memory_kind_labels(memory_type: object, metadata: object) -> list[str]:
    labels = [clean_text(memory_type)]
    if isinstance(metadata, dict):
        labels.append(clean_text(metadata.get("memory_category")))
        labels.append(clean_text(metadata.get("category")))
        labels.append(clean_text(metadata.get("fact_kind")))
    normalized = {normalized_text(label) for label in labels if label}
    if normalized & {"event", "events", "personal plan"}:
        labels.extend(["event", "events"])
    if normalized & {"fact", "facts"}:
        labels.extend(["fact", "facts"])
    if normalized & {"preference", "preferences"}:
        labels.extend(["preference", "preferences"])
    if normalized & {"people", "person"}:
        labels.extend(["person", "people"])
    return [label for label in labels if label]


def _record_visible_text_fields(table: str, record: dict[str, Any]) -> list[str]:
    if table == "long_term_memory":
        return [clean_text(record.get("content"))]
    if table == "entity_events":
        return [
            clean_text(record.get("title")),
            clean_text(record.get("content")),
        ]
    if table == "entities":
        return [
            clean_text(record.get("display_name")),
            clean_text(record.get("normalized_name")),
            clean_text(record.get("relationship")),
            clean_text(record.get("summary")),
            *[
                clean_text(alias)
                for alias in record.get("aliases") or []
            ],
        ]
    if table == "plans":
        return [
            clean_text(record.get("title")),
            clean_text(record.get("description")),
            clean_text(record.get("desired_outcome")),
        ]
    if table == "commitments":
        return [
            clean_text(record.get("title")),
            clean_text(record.get("commitment_text")),
        ]
    return []
