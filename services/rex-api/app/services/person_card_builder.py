from typing import Any, Optional

from app.services.person_card_builder_text import PersonCardBuilderText
from app.services.person_card_constants import (
    PERSON_RELATIONSHIPS,
    SELF_DISPLAY_FALLBACK,
)


class PersonCardBuilder(PersonCardBuilderText):
    """Build and merge Person entity cards from flat memory facts."""

    def person_card_from_memory(self, memory: dict) -> Optional[dict[str, Any]]:
        if str(memory.get("memory_type") or "") != "fact":
            return None
        if int(memory.get("importance") or 0) < 4:
            return None

        metadata = memory.get("metadata")
        if not isinstance(metadata, dict):
            metadata = {}

        self_card = self._self_card_from_memory(memory, metadata)
        if self_card is not None:
            return self_card

        if metadata.get("fact_kind") == "relationship":
            return self._relationship_card_from_memory(memory, metadata)

        if metadata.get("fact_kind") != "birthday":
            return None

        label = self._clean_label(metadata.get("entity_label"))
        entity_owner = self._clean_text(metadata.get("entity_owner"))
        entity_relation = self._clean_text(metadata.get("entity_relation"))
        relation_key = entity_relation or label
        relationship = (
            PERSON_RELATIONSHIPS.get(relation_key)
            or PERSON_RELATIONSHIPS.get(label)
            or entity_relation
            or "person"
        )
        birthday = self._clean_text(metadata.get("normalized_date"))
        memory_id = self._clean_text(memory.get("id"))
        if not label or not birthday:
            return None

        if entity_owner and entity_relation:
            display_name = (
                f"{entity_owner.title()}'s "
                f"{self._display_name(entity_relation)}"
            )
        else:
            raw_label = self._clean_text(metadata.get("entity_label"))
            display_name = self._display_possessive_label(raw_label or label)
        metadata_payload = {
            "person_card_version": 1,
            "attributes": {
                "birthday": birthday,
            },
            "source_memory_ids": [memory_id] if memory_id else [],
            "materialized_from": "long_term_memory",
        }
        return {
            "entity_type": "person",
            "display_name": display_name,
            "normalized_name": self._normalize_name(label),
            "aliases": self._aliases_for(label, relationship, display_name),
            "relationship": relationship,
            "summary": f"Birthday: {birthday}.",
            "source_conversation_id": memory.get("source_conversation_id"),
            "source_message_id": memory.get("source_message_id"),
            "source_memory_id": memory_id,
            "importance": max(3, min(int(memory.get("importance") or 3), 5)),
            "status": "active",
            "active": True,
            "metadata": metadata_payload,
        }

    def merge_person_card(self, existing: dict, card: dict) -> dict[str, Any]:
        return self._merge_person_card(existing, card)

    def _relationship_card_from_memory(
        self,
        memory: dict,
        metadata: dict[str, Any],
    ) -> Optional[dict[str, Any]]:
        label = self._clean_label(metadata.get("entity_label"))
        relationship = self._clean_text(metadata.get("relationship")) or "person"
        memory_id = self._clean_text(memory.get("id"))
        if not label:
            return None

        display_name = self._display_name(label)
        metadata_payload = {
            "person_card_version": 1,
            "attributes": {
                "relationship_to_user": relationship,
            },
            "source_memory_ids": [memory_id] if memory_id else [],
            "materialized_from": "long_term_memory",
        }
        return {
            "entity_type": "person",
            "display_name": display_name,
            "normalized_name": self._normalize_name(label),
            "aliases": self._aliases_for(label, relationship, display_name),
            "relationship": relationship,
            "summary": f"{relationship.title()}: {display_name}.",
            "source_conversation_id": memory.get("source_conversation_id"),
            "source_message_id": memory.get("source_message_id"),
            "source_memory_id": memory_id,
            "importance": max(3, min(int(memory.get("importance") or 3), 5)),
            "status": "active",
            "active": True,
            "metadata": metadata_payload,
        }

    def _self_card_from_memory(
        self,
        memory: dict,
        metadata: dict[str, Any],
    ) -> Optional[dict[str, Any]]:
        attributes = self._self_attributes(memory, metadata)
        if not attributes:
            return None

        memory_id = self._clean_text(memory.get("id"))
        source_memory_ids = [memory_id] if memory_id else []
        attribute_sources = {
            key: source_memory_ids
            for key in attributes
            if source_memory_ids and key != "notes"
        }
        full_name = attributes.get("full_name")
        display_name = full_name or SELF_DISPLAY_FALLBACK
        metadata_payload = {
            "person_card_version": 2,
            "entity_direction": "self",
            "attributes": attributes,
            "attribute_source_memory_ids": attribute_sources,
            "source_memory_ids": source_memory_ids,
            "materialized_from": "long_term_memory",
        }
        return {
            "entity_type": "person",
            "display_name": display_name,
            "normalized_name": self._normalize_name(full_name or "self"),
            "aliases": [],
            "relationship": "self",
            "summary": self._summary_for_attributes(attributes),
            "source_conversation_id": memory.get("source_conversation_id"),
            "source_message_id": memory.get("source_message_id"),
            "source_memory_id": memory_id,
            "importance": max(4, min(int(memory.get("importance") or 4), 5)),
            "status": "active",
            "active": True,
            "metadata": metadata_payload,
        }

    def _self_attributes(
        self,
        memory: dict,
        metadata: dict[str, Any],
    ) -> dict[str, str]:
        content = self._clean_text(memory.get("content"))
        fact_kind = self._clean_label(metadata.get("fact_kind"))
        attributes: dict[str, str] = {}

        full_name = self._extract_full_name(content)
        if not full_name and fact_kind == "name":
            full_name = self._extract_single_name(content)
        if fact_kind == "name" and full_name:
            attributes["full_name"] = full_name
        elif full_name:
            attributes["full_name"] = full_name

        birthday = self._self_birthday_from_memory(content, metadata)
        if birthday:
            attributes["birthday"] = birthday

        location = self._extract_location(content)
        if fact_kind == "location" and location:
            attributes["location"] = location
        elif location:
            attributes["location"] = location

        work = self._extract_work(content, metadata)
        if work.get("job"):
            attributes["job"] = work["job"]
        if work.get("workplace"):
            attributes["workplace"] = work["workplace"]
        if work and not attributes.get("notes"):
            attributes["notes"] = self._work_note(work)

        return attributes

    def _merge_person_card(self, existing: dict, card: dict) -> dict[str, Any]:
        updates: dict[str, Any] = {}
        existing_metadata = existing.get("metadata") if isinstance(existing.get("metadata"), dict) else {}
        incoming_metadata = card.get("metadata") if isinstance(card.get("metadata"), dict) else {}
        is_self_card = incoming_metadata.get("entity_direction") == "self"

        aliases, removed_aliases = self._safe_aliases(
            [*existing.get("aliases", []), *card.get("aliases", [])]
        )
        if aliases != (existing.get("aliases") or []):
            updates["aliases"] = aliases

        if card.get("relationship") and not existing.get("relationship"):
            updates["relationship"] = card["relationship"]
        elif is_self_card and existing.get("relationship") != "self":
            updates["relationship"] = "self"
        elif card.get("relationship") and existing.get("relationship"):
            # Keep relationship label; name changes update the same card.
            pass

        if is_self_card and card.get("display_name") != SELF_DISPLAY_FALLBACK:
            current_display = self._clean_text(existing.get("display_name"))
            if not current_display or current_display in {"User", "Self"}:
                updates["display_name"] = card["display_name"]
                current_normalized = self._normalize_name(existing.get("normalized_name"))
                if current_normalized in {"", "self", "user"}:
                    updates["normalized_name"] = card["normalized_name"]
        elif not is_self_card and card.get("display_name"):
            incoming_display = self._clean_text(card.get("display_name"))
            current_display = self._clean_text(existing.get("display_name"))
            if incoming_display and incoming_display != current_display:
                updates["display_name"] = card["display_name"]
                updates["normalized_name"] = card["normalized_name"]
            if card.get("summary"):
                updates["summary"] = card["summary"]

        metadata = self._merge_metadata(existing.get("metadata"), card.get("metadata"))
        if removed_aliases:
            metadata["removed_unsafe_aliases"] = self._dedupe(
                [*(metadata.get("removed_unsafe_aliases") or []), *removed_aliases]
            )
        if metadata != (existing.get("metadata") or {}):
            updates["metadata"] = metadata

        summary = self._merge_summary(existing.get("summary"), card.get("summary"))
        if summary != (existing.get("summary") or ""):
            updates["summary"] = summary

        if int(card.get("importance") or 0) > int(existing.get("importance") or 0):
            updates["importance"] = card["importance"]

        return updates

    def _merge_metadata(self, existing: object, incoming: object) -> dict[str, Any]:
        existing_dict = existing if isinstance(existing, dict) else {}
        incoming_dict = incoming if isinstance(incoming, dict) else {}
        attributes = {
            **(
                existing_dict.get("attributes")
                if isinstance(existing_dict.get("attributes"), dict)
                else {}
            ),
            **(
                incoming_dict.get("attributes")
                if isinstance(incoming_dict.get("attributes"), dict)
                else {}
            ),
        }
        existing_sources = existing_dict.get("attribute_source_memory_ids")
        incoming_sources = incoming_dict.get("attribute_source_memory_ids")
        attribute_sources: dict[str, list[str]] = {}
        for source_map in (existing_sources, incoming_sources):
            if not isinstance(source_map, dict):
                continue
            for key, values in source_map.items():
                if not isinstance(values, list):
                    continue
                attribute_sources[str(key)] = self._dedupe(
                    [*(attribute_sources.get(str(key)) or []), *values]
                )
        source_memory_ids = self._dedupe(
            [
                *(existing_dict.get("source_memory_ids") or []),
                *(incoming_dict.get("source_memory_ids") or []),
            ]
        )
        return {
            **existing_dict,
            **incoming_dict,
            "attributes": attributes,
            "attribute_source_memory_ids": attribute_sources,
            "source_memory_ids": source_memory_ids,
        }

    def _merge_summary(self, existing: object, incoming: object) -> str:
        existing_text = self._clean_text(existing)
        incoming_text = self._clean_text(incoming)
        if not existing_text:
            return incoming_text or ""
        if not incoming_text:
            return existing_text
        if incoming_text.lower() in existing_text.lower():
            return existing_text
        return f"{existing_text.rstrip()} {incoming_text}"
