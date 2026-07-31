"""Map Grok memory/person action payloads to body intents (parse only)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from app.services.body_display_text import SimpleMemoryIntent
from app.services.memory_delete_resolver import MEMORY_DELETE_SCOPE
from app.services.memory_reference_models import KnowsReferenceMatch
from app.services.person_card_constants import (
    PERSON_CARD_MIN_IMPORTANCE,
    PERSON_RELATIONSHIPS,
)


_MEMORY_TYPES = frozenset({"fact", "preference", "context", "correction"})


@dataclass(frozen=True)
class PersonCardTarget:
    entity_id: str
    display_name: str
    entity: dict[str, Any]


@dataclass(frozen=True)
class PersonStatePayload:
    target: PersonCardTarget
    state: str


@dataclass(frozen=True)
class PersonNotePayload:
    target: PersonCardTarget
    note: str
    replace: bool = False


@dataclass(frozen=True)
class DeleteKnowsPayload:
    match: KnowsReferenceMatch
    resolver_target: str
    scope_tables: tuple[str, ...] = MEMORY_DELETE_SCOPE


def simple_memory_intent_from_payload(
    payload: dict[str, Any],
    *,
    for_person: bool = False,
) -> Optional[SimpleMemoryIntent]:
    content = _first_str(payload, "content", "text", "body", "memory", "summary")
    if for_person:
        display_name = _first_str(
            payload,
            "display_name",
            "person_name",
            "name",
        )
        relationship = _canonical_relationship(
            payload.get("relationship") or payload.get("relation")
        )
        if not content:
            if display_name and relationship:
                content = f"User's {relationship} is {display_name}."
            elif display_name:
                content = f"{display_name} is someone important to the user."
            elif relationship:
                content = f"User has a {relationship}."
        if not content:
            return None
        metadata: dict[str, Any] = {
            "fact_kind": "relationship",
            "memory_category": "People",
        }
        if relationship:
            metadata["relationship"] = relationship
        if display_name:
            metadata["display_name"] = display_name
            metadata["entity_label"] = display_name
        notes = _first_str(payload, "notes", "note")
        if notes:
            metadata["notes"] = notes
        birthday = _first_str(payload, "birthday")
        if birthday:
            metadata["normalized_date"] = birthday
        return SimpleMemoryIntent(
            memory_type="fact",
            content=content,
            importance=max(_importance(payload) or 0, PERSON_CARD_MIN_IMPORTANCE),
            source="brain_save_person",
            metadata=metadata,
        )

    if not content:
        return None
    memory_type = str(payload.get("memory_type") or "fact").strip().lower()
    if memory_type not in _MEMORY_TYPES:
        memory_type = "fact"
    metadata = {}
    category = _first_str(payload, "memory_category", "category")
    if category:
        metadata["memory_category"] = category
    return SimpleMemoryIntent(
        memory_type=memory_type,
        content=content,
        importance=_importance(payload),
        source="brain_save_memory",
        metadata=metadata,
    )


def memory_update_record_id(payload: dict[str, Any]) -> Optional[str]:
    return _first_str(payload, "memory_id", "record_id", "id")


def person_state_text(payload: dict[str, Any]) -> Optional[str]:
    return _first_str(payload, "state", "summary", "status", "content")


def person_note_text(payload: dict[str, Any]) -> Optional[str]:
    return _first_str(payload, "note", "notes", "content", "text")


def person_lookup_keys(payload: dict[str, Any]) -> tuple[Optional[str], Optional[str]]:
    person_id = _first_str(payload, "person_id", "entity_id")
    name = _first_str(
        payload,
        "display_name",
        "person_name",
        "name",
        "title",
    )
    return person_id, name


def delete_reference_from_payload(payload: dict[str, Any]) -> Optional[str]:
    return _first_str(
        payload,
        "title",
        "reference",
        "name",
        "content",
        "query",
        "item_title",
    )


def delete_id_from_payload(payload: dict[str, Any]) -> tuple[Optional[str], Optional[str]]:
    record_id = _first_str(payload, "id", "record_id", "memory_id", "entity_id")
    table = _first_str(payload, "table", "delete_table")
    return record_id, table


def _importance(payload: dict[str, Any]) -> Optional[int]:
    """The importance Grok actually rated, or None when it said nothing."""
    raw = payload.get("importance")
    if raw is None:
        return None
    try:
        return max(1, min(5, int(raw)))
    except (TypeError, ValueError):
        return None


def _canonical_relationship(value: object) -> str:
    text = str(value or "").strip().lower()
    if not text:
        return ""
    return PERSON_RELATIONSHIPS.get(text, text)


def _first_str(payload: dict[str, Any], *keys: str) -> Optional[str]:
    for key in keys:
        text = str(payload.get(key) or "").strip()
        if text:
            return text
    return None
