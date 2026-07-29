"""Shared helpers for memory capability handlers."""

from __future__ import annotations

from typing import Any, Optional

from app.services.body_display_text import clarification_turn_result
from app.services.capabilities.memory_action_payload import (
    PersonCardTarget,
    person_lookup_keys,
)
from app.services.durable_write_results import (
    applied_memory_changes,
    failed_memory_changes,
)
from app.services.grok_continuing_reply import continuing_reply_for_knows_apply
from app.services.memory_reference_resolver import MemoryReferenceResolver

BAD_MEMORY_REPLY = (
    "I need a clear fact or preference to save. "
    "Tell me what to remember and I'll confirm before saving."
)
BAD_PERSON_REPLY = (
    "I need a person name (and ideally relationship) before I can save a person card."
)
BAD_STATE_REPLY = (
    "I need which person to update and a short state to save on their card."
)
BAD_NOTE_REPLY = (
    "I need which person to update and the note to add on their card."
)
PERSON_NOT_FOUND_REPLY = (
    "I couldn't find that person in Knows yet. "
    "Save them as a person card first, then I can update state or notes."
)
BAD_DELETE_REPLY = (
    "I need to know which Knows item to delete (a title or id). "
    "Nothing will be deleted until you confirm."
)
DELETE_AMBIGUOUS_REPLY = (
    "I found more than one matching Knows item. "
    "Tell me the exact title (or id) and I'll confirm before deleting."
)
DELETE_NOT_FOUND_REPLY = (
    "I couldn't find that item in Knows. "
    "Check Knows and tell me the exact title if you still want it deleted."
)


def with_assistant_reply(assistant_reply: str, fallback: str) -> str:
    base = str(assistant_reply or "").strip()
    if base and fallback.lower() in base.lower():
        return base
    if base:
        return f"{base}\n\n{fallback}"
    return fallback


def entity_notes(entity: dict[str, Any]) -> str:
    metadata = entity.get("metadata")
    if not isinstance(metadata, dict):
        return ""
    attributes = metadata.get("attributes")
    if not isinstance(attributes, dict):
        return ""
    return str(attributes.get("notes") or "").strip()


async def resolve_person_target(
    memory_service: Any,
    payload: dict[str, Any],
) -> Optional[PersonCardTarget]:
    person_id, name = person_lookup_keys(payload)
    resolver = MemoryReferenceResolver(memory_service)
    entity: Optional[dict[str, Any]] = None
    if person_id:
        list_entities = getattr(memory_service, "list_entities", None)
        if callable(list_entities):
            try:
                rows = await list_entities(active=True, limit=100)
            except Exception:
                rows = []
            for row in rows or []:
                if str(row.get("id") or "") == person_id:
                    entity = row
                    break
    if entity is None and name:
        entity = await resolver.find_existing_entity(name)
    if entity is None:
        return None
    if str(entity.get("entity_type") or "") != "person":
        return None
    display = str(entity.get("display_name") or name or "this person").strip()
    return PersonCardTarget(
        entity_id=str(entity.get("id") or ""),
        display_name=display or "this person",
        entity=entity,
    )


async def apply_memory_proposal(
    proposal,
    *,
    durable_write_service,
    conversation_id: str,
    user_message: dict,
    assistant_reply: str,
) -> dict:
    result = await durable_write_service.applier.apply_proposal(
        proposal,
        conversation_id=conversation_id,
        source_message_id=str(user_message.get("id") or "") or None,
    )
    if not result.get("applied"):
        reason = str(result.get("reason") or "").strip() or None
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=(
                f"I understood what you wanted about {proposal.title}, "
                "but I couldn't save it just now. Please try again in a moment."
            ),
            memory_changes=failed_memory_changes(proposal=proposal, reason=reason),
        )
    record = result.get("record") or {}
    records = result.get("records") or ([record] if record else [])
    return await clarification_turn_result(
        durable_write_service.memory_service,
        conversation_id=conversation_id,
        user_message=user_message,
        response=continuing_reply_for_knows_apply(
            assistant_reply,
            title=proposal.title,
        ),
        memory_changes=applied_memory_changes(
            proposal=proposal,
            record=record,
            merged=bool(result.get("merged")),
            records=records,
            updated_count=result.get("updated_count"),
        ),
    )
