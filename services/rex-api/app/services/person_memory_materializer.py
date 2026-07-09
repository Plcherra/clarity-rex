from typing import Any, Optional

from app.services.person_card_builder import PersonCardBuilder
from app.services.person_card_constants import PERSON_RELATIONSHIPS
from app.services.person_memory_archival import PersonMemoryArchival
from app.services.person_memory_consolidator import PersonMemoryConsolidator


class PersonMemoryMaterializer:
    """Best-effort bridge from high-confidence flat facts to Person entities."""

    def __init__(self) -> None:
        self._builder = PersonCardBuilder()
        self._archival = PersonMemoryArchival(self._builder)
        self._consolidator = PersonMemoryConsolidator(self._builder)

    async def materialize_from_active_memories(
        self,
        memory_service,
        *,
        limit: int = 250,
    ) -> None:
        list_memory = getattr(memory_service, "list_long_term_memory", None)
        if list_memory is None:
            return

        try:
            memories = await list_memory(limit=limit, memory_type="fact", active=True)
        except TypeError:
            memories = await list_memory(limit=limit, active=True)
        except Exception:
            return

        for memory in memories:
            if isinstance(memory, dict):
                await self.materialize_from_memory(memory_service, memory)

    async def materialize_from_memory(self, memory_service, memory: dict) -> None:
        card = self.person_card_from_memory(memory)
        if card is None:
            return

        list_entities = getattr(memory_service, "list_entities", None)
        create_entity = getattr(memory_service, "create_entity", None)
        update_entity = getattr(memory_service, "update_entity", None)
        if list_entities is None or create_entity is None:
            return

        existing = await self._find_existing_person(
            list_entities,
            normalized_name=card["normalized_name"],
            relationship=card.get("relationship"),
        )
        person = existing
        if existing is None:
            person = await create_entity(card)
        elif update_entity is not None:
            updates = self._builder.merge_person_card(existing, card)
            if updates:
                person = await update_entity(str(existing["id"]), **updates) or existing
            else:
                person = existing
        if not isinstance(person, dict):
            return

        # Cover the just-written flat, then pull related birthday/people flats
        # onto the same card (e.g. mom birthday Event + new mom name).
        await self._archival.archive_covered_person_source_memories(
            memory_service, [memory]
        )
        await self._consolidator.consolidate_for_person(memory_service, person)

    def person_card_from_memory(self, memory: dict) -> Optional[dict[str, Any]]:
        return self._builder.person_card_from_memory(memory)

    async def archive_source_memories_for_entity(
        self,
        memory_service,
        entity: dict,
        *,
        reason: str = "entity_archived",
    ) -> None:
        await self._archival.archive_source_memories_for_entity(
            memory_service,
            entity,
            reason=reason,
        )

    async def _find_existing_person(
        self,
        list_entities,
        *,
        normalized_name: str,
        relationship: object = None,
    ) -> Optional[dict]:
        entities = await list_entities(
            entity_type="person",
            active=True,
            limit=100,
        )
        if self._builder._clean_label(relationship) == "self" or normalized_name in {
            "self",
            "user",
        }:
            for entity in entities:
                if self._builder._is_self_entity(entity):
                    return entity
        # Prefer matching an existing relationship card (e.g. mom) so a name
        # change updates the same person instead of creating a parallel card.
        clean_relationship = self._canonical_relationship(relationship)
        if clean_relationship and clean_relationship not in {"person", "self", "user"}:
            for entity in entities:
                entity_relationship = self._canonical_relationship(
                    entity.get("relationship")
                )
                attrs = entity.get("metadata") if isinstance(entity.get("metadata"), dict) else {}
                attr_rel = self._canonical_relationship(
                    (attrs.get("attributes") or {}).get("relationship_to_user")
                    if isinstance(attrs.get("attributes"), dict)
                    else None
                )
                if entity_relationship == clean_relationship or attr_rel == clean_relationship:
                    return entity
        for entity in entities:
            if self._builder._normalize_name(entity.get("normalized_name")) == normalized_name:
                return entity
            if self._builder._normalize_name(entity.get("display_name")) == normalized_name:
                return entity
            for alias in entity.get("aliases") or []:
                if self._builder._normalize_name(alias) == normalized_name:
                    return entity
        return None

    def _canonical_relationship(self, value: object) -> str:
        text = self._builder._clean_label(value)
        if not text:
            return ""
        return PERSON_RELATIONSHIPS.get(text, text)
