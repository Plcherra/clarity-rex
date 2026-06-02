from __future__ import annotations

import re
from typing import Any, Optional

from app.services.memory_correction_intent_parser import trim_text
from app.services.memory_correction_types import (
    CORRECTION_VERSION,
    TABLE_SPECS,
    CorrectionIntent,
    CorrectionIntentType,
    TableSpec,
)


def replacement_updates(
    record: dict[str, Any],
    spec: TableSpec,
    old_value: str,
    new_value: str,
) -> dict[str, Any]:
    updates: dict[str, Any] = {}
    for field_name in spec.text_fields:
        value = record.get(field_name)
        replaced = replace_value(value, old_value, new_value)
        if replaced != value:
            updates[field_name] = replaced
    if updates:
        metadata = dict(record.get("metadata") or {})
        metadata.update(
            {
                "correction_version": CORRECTION_VERSION,
                "correction_action": "replace_value",
                "old_value": old_value,
                "new_value": new_value,
            }
        )
        updates["metadata"] = metadata
    return updates


def person_fact_entity_updates(record: dict[str, Any], text: str) -> dict[str, Any]:
    names = [
        record.get("display_name"),
        record.get("normalized_name"),
        *(record.get("aliases") or []),
    ]
    summary_parts: list[str] = []
    relationship = None
    for name in names:
        if not isinstance(name, str) or not name.strip():
            continue
        pattern = re.compile(
            rf"\b{re.escape(name.strip())}\s+(?:is|was)\s+(.+)$",
            flags=re.IGNORECASE,
        )
        for sentence in sentences(text):
            match = pattern.search(sentence)
            if match:
                fact = trim_text(match.group(1))
                if fact:
                    summary_parts.append(capitalize_sentence(fact))
                    relationship = relationship or short_relationship(fact)

        quit_pattern = re.compile(
            rf"\b{re.escape(name.strip())}\s+quit\s+([^.!?]+)",
            flags=re.IGNORECASE,
        )
        for sentence in sentences(text):
            match = quit_pattern.search(sentence)
            if match:
                summary_parts.append(
                    capitalize_sentence(f"{name.strip()} quit {trim_text(match.group(1))}")
                )

    if not summary_parts:
        return {}

    updates: dict[str, Any] = {
        "summary": join_unique_sentences(summary_parts),
        "metadata": {
            **(record.get("metadata") or {}),
            "correction_version": CORRECTION_VERSION,
            "correction_action": "person_fact_update",
        },
    }
    if relationship:
        updates["relationship"] = relationship
    return updates


def negative_fired_fact(text: str) -> Optional[dict[str, str]]:
    for sentence in sentences(text):
        negative = re.search(
            r"\b([A-Z][a-z]+)\s+(?:was\s+)?not\s+fired\b",
            sentence,
        )
        if not negative:
            continue
        name = negative.group(1)
        replacement = quit_fact_for_person(text, name)
        if replacement:
            return {"name": name, "replacement": replacement}
    return None


def quit_fact_for_person(text: str, name: str) -> str | None:
    pattern = re.compile(
        rf"\b{re.escape(name)}\s+quit\s+([^.!?]+)",
        flags=re.IGNORECASE,
    )
    match = pattern.search(text)
    if not match:
        return None
    return f"{name} quit {trim_text(match.group(1))}"


def replace_fired_fact_updates(
    record: dict[str, Any],
    spec: TableSpec,
    replacement: str,
) -> dict[str, Any]:
    updates: dict[str, Any] = {}
    for field_name in spec.text_fields:
        value = record.get(field_name)
        replaced = replace_fired_fact(value, replacement)
        if replaced != value:
            updates[field_name] = replaced
    if updates:
        updates["metadata"] = {
            **(record.get("metadata") or {}),
            "correction_version": CORRECTION_VERSION,
            "correction_action": "person_negative_fact_replace",
            "new_value": replacement,
        }
    return updates


def replace_fired_fact(value: Any, replacement: str) -> Any:
    if isinstance(value, list):
        return [replace_fired_fact(item, replacement) for item in value]
    if not isinstance(value, str):
        return value
    if "fired" not in value.casefold():
        return value
    patterns = [
        r"\bgot\s+fired(?:\s+(?:at|in|on)\s+the\s+beginning\s+of\s+this\s+year)?",
        r"\bwas\s+fired(?:\s+(?:at|in|on)\s+the\s+beginning\s+of\s+this\s+year)?",
    ]
    replaced = value
    for pattern in patterns:
        replaced = re.sub(pattern, replacement, replaced, flags=re.IGNORECASE)
    return replaced


def person_fact_stale_terms(text: str) -> list[str]:
    negative = negative_fired_fact(text)
    if not negative:
        return []
    return [f"{negative['name']} got fired", f"{negative['name']} was fired"]


def sentences(text: str) -> list[str]:
    return [
        sentence.strip()
        for sentence in re.split(r"[.!?]+", text)
        if sentence.strip()
    ]


def capitalize_sentence(text: str) -> str:
    text = trim_text(text)
    return text[:1].upper() + text[1:] if text else text


def short_relationship(fact: str) -> str:
    lowered = fact.casefold()
    if "friend" in lowered:
        return "friend"
    if "supervisor" in lowered:
        return "kitchen supervisor" if "kitchen" in lowered else "supervisor"
    return fact.split(",", 1)[0][:120]


def join_unique_sentences(parts: list[str]) -> str:
    seen: set[str] = set()
    result: list[str] = []
    for part in parts:
        key = normalize_key(part)
        if not key or key in seen:
            continue
        seen.add(key)
        result.append(part)
    return ". ".join(result)


def replace_value(value: Any, old_value: str, new_value: str) -> Any:
    if isinstance(value, list):
        return [replace_value(item, old_value, new_value) for item in value]
    if not isinstance(value, str):
        return value
    pattern = re.compile(re.escape(old_value), re.IGNORECASE)
    return pattern.sub(new_value, value)


def record_contains(record: dict[str, Any], spec: TableSpec, value: str) -> bool:
    value_key = normalize_key(value)
    if not value_key:
        return False
    for field_name in spec.text_fields:
        if value_key in normalize_key(record.get(field_name)):
            return True
    return False


def correction_type_for_table(table: str, intent: CorrectionIntent) -> str:
    if intent.intent_type == CorrectionIntentType.REPLACE_VALUE and table == "entities":
        return "entity_name"
    return spec_for_table(table).correction_type


def spec_for_table(table: str) -> TableSpec:
    for spec in TABLE_SPECS:
        if spec.table == table:
            return spec
    raise KeyError(table)


def dedupe_affected(records):
    seen: set[tuple[str, str, str]] = set()
    deduped = []
    for record in records:
        key = (record.table, record.id, record.action)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(record)
    return deduped


def confirmation_payload(intent: CorrectionIntent) -> dict[str, Any]:
    return {
        "intent_type": intent.intent_type.value,
        "old_value": intent.old_value,
        "new_value": intent.new_value,
        "target_hint": intent.target_hint,
        "reason": "Correction is ambiguous or may archive multiple active records.",
    }


def record_title(record: dict[str, Any]) -> Optional[str]:
    return (
        record.get("title")
        or record.get("display_name")
        or record.get("content")
        or record.get("commitment_text")
    )


def normalize_key(value: Any) -> str:
    if isinstance(value, list):
        value = " ".join(str(item) for item in value)
    return re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()
