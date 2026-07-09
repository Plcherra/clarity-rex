"""Consolidate related flat people facts onto a person card after writes."""

from __future__ import annotations

from typing import Any, Optional

from app.services.durable_record_delete import hard_delete_record
from app.services.person_card_builder import PersonCardBuilder
from app.services.person_card_constants import PERSON_RELATIONSHIPS


class PersonMemoryConsolidator:
    """Attach related birthday/people flats onto a person card, then hard-delete them.

    General rule for messy user data: once a person card exists for a
    relationship (mom/dad/...), promote matching flat Events/People facts onto
    that card instead of leaving orphan tiles in Knows.
    """

    def __init__(self, builder: Optional[PersonCardBuilder] = None) -> None:
        self._builder = builder or PersonCardBuilder()

    async def consolidate_for_person(
        self,
        memory_service: Any,
        person: dict[str, Any],
    ) -> dict[str, Any]:
        if not isinstance(person, dict) or not person.get("id"):
            return person
        list_memory = getattr(memory_service, "list_long_term_memory", None)
        update_entity = getattr(memory_service, "update_entity", None)
        if list_memory is None:
            return person

        try:
            memories = await list_memory(limit=250, memory_type="fact", active=True)
        except TypeError:
            try:
                memories = await list_memory(limit=250, active=True)
            except Exception:
                return person
        except Exception:
            return person

        related = [
            memory
            for memory in memories
            if isinstance(memory, dict) and self._flat_matches_person(memory, person)
        ]
        if not related:
            return person

        merged = person
        for memory in related:
            card = self._builder.person_card_from_memory(memory)
            if card is None:
                # Still cover relationship-labelled birthday flats that builder
                # can represent; skip non-person flats.
                continue
            updates = self._builder.merge_person_card(merged, card)
            if updates and update_entity is not None:
                try:
                    updated = await update_entity(str(merged["id"]), **updates)
                except Exception:
                    updated = None
                if isinstance(updated, dict):
                    merged = updated
            await hard_delete_record(
                memory_service,
                table="long_term_memory",
                record_id=str(memory.get("id") or ""),
            )
        return merged

    def _flat_matches_person(self, memory: dict, person: dict) -> bool:
        metadata = memory.get("metadata")
        if not isinstance(metadata, dict):
            return False
        person_rel = self._canonical_relationship(person.get("relationship"))
        attrs = person.get("metadata") if isinstance(person.get("metadata"), dict) else {}
        attr_rel = self._canonical_relationship(
            (attrs.get("attributes") or {}).get("relationship_to_user")
            if isinstance(attrs.get("attributes"), dict)
            else None
        )
        target_rel = person_rel or attr_rel
        if not target_rel or target_rel in {"self", "person"}:
            return False

        fact_kind = str(metadata.get("fact_kind") or "").casefold()
        category = str(metadata.get("memory_category") or "").casefold()
        entity_label = self._canonical_relationship(metadata.get("entity_label"))
        entity_relation = self._canonical_relationship(metadata.get("entity_relation"))
        memory_rel = self._canonical_relationship(metadata.get("relationship"))

        candidates = {entity_label, entity_relation, memory_rel}
        candidates.discard("")
        if target_rel not in candidates and not any(
            self._same_relationship_family(target_rel, value) for value in candidates
        ):
            # Content fallback: "User's mom's birthday..."
            content = self._builder._normalize_name(str(memory.get("content") or ""))
            if target_rel not in content and not any(
                alias in content for alias in self._relationship_aliases(target_rel)
            ):
                return False

        if fact_kind in {"birthday", "relationship"}:
            return True
        if category in {"events", "people"} and (
            "birthday" in str(memory.get("content") or "").casefold()
            or fact_kind == "relationship"
        ):
            return True
        return False

    def _canonical_relationship(self, value: object) -> str:
        text = self._builder._clean_label(value)
        if not text:
            return ""
        return PERSON_RELATIONSHIPS.get(text, text)

    def _same_relationship_family(self, left: str, right: str) -> bool:
        if not left or not right:
            return False
        return self._canonical_relationship(left) == self._canonical_relationship(right)

    def _relationship_aliases(self, relationship: str) -> set[str]:
        canonical = self._canonical_relationship(relationship)
        aliases = {canonical, relationship}
        for key, value in PERSON_RELATIONSHIPS.items():
            if value == canonical:
                aliases.add(key)
        return {alias for alias in aliases if alias}
