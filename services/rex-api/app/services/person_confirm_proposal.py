"""Build person-card confirm payloads for relationship memory proposals."""

from __future__ import annotations

from typing import Any, Optional

from app.services.durable_write_proposal import DurableWriteProposal
from app.services.body_display_text import SimpleMemoryIntent
from app.services.memory_path_policy import direct_save_metadata
from app.services.person_card_constants import PERSON_RELATIONSHIPS

PERSON_EDITABLE_FIELDS = (
    "display_name",
    "relationship",
    "birthday",
    "notes",
)


def person_card_insufficient_fields_message() -> str:
    return (
        "Add at least two person details (for example name and "
        "relationship) before saving."
    )


def person_card_blocks_apply(person_card: Optional[dict[str, Any]]) -> bool:
    if not isinstance(person_card, dict):
        return False
    if person_card.get("insufficient_fields"):
        return True
    return count_person_card_fields(person_card) < 2


def count_person_card_fields(card: dict[str, Any]) -> int:
    return sum(1 for key in PERSON_EDITABLE_FIELDS if str(card.get(key) or "").strip())


def person_card_from_intent(
    intent: SimpleMemoryIntent,
    *,
    related: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    metadata = intent.metadata if isinstance(intent.metadata, dict) else {}
    relationship = _canonical_relationship(metadata.get("relationship"))
    display_name = _display_name_from_intent(intent)
    related = related if isinstance(related, dict) else {}
    birthday = str(related.get("birthday") or metadata.get("normalized_date") or "").strip()
    notes = str(related.get("notes") or "").strip()
    merge_hint = str(related.get("merge_hint") or "").strip()
    related_summary = str(related.get("related_summary") or "").strip()
    card = {
        "display_name": display_name,
        "relationship": relationship,
        "birthday": birthday,
        "notes": notes,
        "filled_field_count": 0,
        "merge_hint": merge_hint or None,
        "related_summary": related_summary or None,
    }
    card["filled_field_count"] = count_person_card_fields(card)
    return card


def proposal_from_relationship_memory(
    intent: SimpleMemoryIntent,
    *,
    related: Optional[dict[str, Any]] = None,
    record_id: Optional[str] = None,
    previous_content: Optional[str] = None,
) -> DurableWriteProposal:
    person_card = person_card_from_intent(intent, related=related)
    metadata = direct_save_metadata(
        {
            **intent.metadata,
            **(
                {
                    "updated_from_memory_id": record_id,
                    "previous_content": previous_content,
                }
                if record_id
                else {}
            ),
            "person_card": {
                key: person_card.get(key)
                for key in PERSON_EDITABLE_FIELDS
                if str(person_card.get(key) or "").strip()
            },
        }
    )
    content = _content_from_person_card(person_card) or intent.content
    title = content.split(".", 1)[0].strip() or "Person"
    snapshot_type = "memory_update" if record_id else "memory"
    payload: dict[str, Any] = {
        "memory_type": intent.memory_type,
        "content": content,
        "importance": intent.importance,
        "metadata": metadata,
    }
    if record_id:
        payload["memory_id"] = record_id
    merge_title = None
    if person_card.get("merge_hint"):
        merge_title = str(person_card.get("display_name") or person_card.get("relationship") or "person")
    return DurableWriteProposal(
        write_kind="memory",
        title=title,
        body=content,
        editable_fields=PERSON_EDITABLE_FIELDS,
        apply_snapshot={"type": snapshot_type, "payload": payload},
        merge_target_title=merge_title,
        person_card=person_card,
        custom_assistant_prompt=_assistant_prompt(person_card),
    )


async def resolve_related_person_context(
    memory_service: Any,
    intent: SimpleMemoryIntent,
) -> dict[str, Any]:
    """Find birthday/people flats or person cards for the same relationship."""
    metadata = intent.metadata if isinstance(intent.metadata, dict) else {}
    relationship = _canonical_relationship(metadata.get("relationship"))
    if not relationship:
        return {}

    birthday = ""
    related_bits: list[str] = []
    list_memory = getattr(memory_service, "list_long_term_memory", None)
    if list_memory is not None:
        try:
            memories = await list_memory(limit=100, memory_type="fact", active=True)
        except TypeError:
            try:
                memories = await list_memory(limit=100, active=True)
            except Exception:
                memories = []
        except Exception:
            memories = []
        for memory in memories:
            if not isinstance(memory, dict):
                continue
            if not _memory_matches_relationship(memory, relationship):
                continue
            mem_meta = memory.get("metadata") if isinstance(memory.get("metadata"), dict) else {}
            if str(mem_meta.get("fact_kind") or "") == "birthday":
                birthday = str(mem_meta.get("normalized_date") or "").strip() or birthday
                related_bits.append(str(memory.get("content") or "birthday").strip())
            elif str(mem_meta.get("fact_kind") or "") == "relationship":
                related_bits.append(str(memory.get("content") or "person fact").strip())

    list_entities = getattr(memory_service, "list_entities", None)
    if list_entities is not None:
        try:
            entities = await list_entities(entity_type="person", active=True, limit=100)
        except Exception:
            entities = []
        for entity in entities:
            if not isinstance(entity, dict):
                continue
            entity_rel = _canonical_relationship(entity.get("relationship"))
            attrs = entity.get("metadata") if isinstance(entity.get("metadata"), dict) else {}
            attr_rel = _canonical_relationship(
                (attrs.get("attributes") or {}).get("relationship_to_user")
                if isinstance(attrs.get("attributes"), dict)
                else None
            )
            if entity_rel != relationship and attr_rel != relationship:
                continue
            entity_attrs = attrs.get("attributes") if isinstance(attrs.get("attributes"), dict) else {}
            if not birthday:
                birthday = str(entity_attrs.get("birthday") or "").strip()
            label = str(entity.get("display_name") or relationship).strip()
            related_bits.append(f"existing person card: {label}")

    if not related_bits and not birthday:
        return {}
    summary = "; ".join(bit for bit in related_bits if bit)[:180]
    return {
        "birthday": birthday,
        "related_summary": summary,
        "merge_hint": (
            f"We already have related info about your {relationship}. "
            "Confirm to merge into one person card."
        ),
    }


def apply_person_card_edits(
    *,
    person_card: dict[str, Any],
    edits: dict[str, Any],
) -> dict[str, Any]:
    updated = dict(person_card)
    for key in PERSON_EDITABLE_FIELDS:
        if key in edits:
            updated[key] = str(edits.get(key) or "").strip()
    updated["filled_field_count"] = count_person_card_fields(updated)
    return updated


def _content_from_person_card(card: dict[str, Any]) -> str:
    relationship = str(card.get("relationship") or "").strip()
    display_name = str(card.get("display_name") or "").strip()
    birthday = str(card.get("birthday") or "").strip()
    notes = str(card.get("notes") or "").strip()
    parts: list[str] = []
    if relationship and display_name:
        parts.append(f"User's {relationship} is {display_name}.")
    elif display_name:
        parts.append(f"Person name is {display_name}.")
    elif relationship:
        parts.append(f"User has a {relationship}.")
    if relationship and birthday:
        parts.append(f"User's {relationship}'s birthday is {birthday}.")
    elif birthday:
        parts.append(f"Birthday is {birthday}.")
    if notes:
        parts.append(notes if notes.endswith(".") else f"{notes}.")
    return " ".join(parts).strip()


def _assistant_prompt(card: dict[str, Any]) -> str:
    name = str(card.get("display_name") or "").strip() or "this person"
    relationship = str(card.get("relationship") or "").strip()
    label = f"your {relationship} ({name})" if relationship else name
    if card.get("merge_hint"):
        return (
            f"I can merge this into one person card for {label}. "
            "Tap confirm to save — nothing is saved until you confirm."
        )
    return (
        f"I can save {label} to Clarity Knows. "
        "Tap confirm to save — nothing is saved until you confirm."
    )


def _display_name_from_intent(intent: SimpleMemoryIntent) -> str:
    metadata = intent.metadata if isinstance(intent.metadata, dict) else {}
    label = str(metadata.get("entity_label") or "").replace("_", " ").strip()
    if label:
        return label.title()
    content = str(intent.content or "")
    # "User's mom is Ariadyna."
    if " is " in content:
        return content.rsplit(" is ", 1)[-1].strip(" .")
    return ""


def _canonical_relationship(value: object) -> str:
    text = str(value or "").strip().lower()
    if not text:
        return ""
    return PERSON_RELATIONSHIPS.get(text, text)


def _memory_matches_relationship(memory: dict, relationship: str) -> bool:
    metadata = memory.get("metadata") if isinstance(memory.get("metadata"), dict) else {}
    candidates = {
        _canonical_relationship(metadata.get("relationship")),
        _canonical_relationship(metadata.get("entity_label")),
        _canonical_relationship(metadata.get("entity_relation")),
    }
    if relationship in candidates:
        return True
    content = str(memory.get("content") or "").casefold()
    aliases = {relationship, *[k for k, v in PERSON_RELATIONSHIPS.items() if v == relationship]}
    return any(alias and alias in content for alias in aliases)
