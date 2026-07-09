from typing import Any, Optional

from app.services.durable_record_delete import hard_delete_record
from app.services.person_card_builder import PersonCardBuilder


class PersonMemoryArchival:
    """Remove flat source memories covered by Person entity cards."""

    def __init__(self, builder: PersonCardBuilder) -> None:
        self._builder = builder

    async def archive_covered_person_source_memories(
        self,
        memory_service,
        memories: list[dict],
    ) -> None:
        """Hard-delete covered flat duplicates after a person card exists.

        Soft-archive hid orphans and made integrity bugs hard to catch. Covered
        flats are deleted once the person card is confirmed.
        """
        list_entities = getattr(memory_service, "list_entities", None)
        if list_entities is None:
            return
        try:
            entities = await list_entities(entity_type="person", active=True, limit=100)
        except Exception:
            return

        for memory in memories:
            if not isinstance(memory, dict) or memory.get("active", True) is not True:
                continue
            memory_id = self._builder._clean_text(memory.get("id"))
            if not memory_id:
                continue
            memory_metadata = memory.get("metadata")
            if not isinstance(memory_metadata, dict):
                memory_metadata = {}
            matched = self._person_entity_covering_memory(
                entities,
                memory_id=memory_id,
                memory=memory,
                memory_metadata=memory_metadata,
            )
            if matched is None:
                continue
            await hard_delete_record(
                memory_service,
                table="long_term_memory",
                record_id=memory_id,
            )

    async def archive_source_memories_for_entity(
        self,
        memory_service,
        entity: dict,
        *,
        reason: str = "entity_archived",
    ) -> None:
        """When a person entity is user-archived, soft-deactivate linked flats."""
        deactivate_memory = getattr(memory_service, "deactivate_long_term_memory", None)
        update_memory = getattr(memory_service, "update_long_term_memory", None)
        if deactivate_memory is None and update_memory is None:
            return

        metadata = entity.get("metadata")
        if not isinstance(metadata, dict):
            metadata = {}
        entity_id = self._builder._clean_text(entity.get("id"))
        source_ids = self._covered_source_memory_ids(metadata)
        source_memory_id = self._builder._clean_text(entity.get("source_memory_id"))
        if source_memory_id:
            source_ids.add(source_memory_id)

        for memory_id in source_ids:
            archive_metadata = {
                "canonical_entity_id": entity_id,
                "canonical_entity_type": entity.get("entity_type") or "person",
                "duplicate_archive_reason": reason,
            }
            try:
                if deactivate_memory is not None:
                    await deactivate_memory(memory_id)
                    if update_memory is not None:
                        await update_memory(memory_id, metadata=archive_metadata)
                elif update_memory is not None:
                    await update_memory(
                        memory_id,
                        active=False,
                        metadata=archive_metadata,
                    )
            except Exception:
                continue

    def _person_entity_covering_memory(
        self,
        entities: list[dict],
        *,
        memory_id: str,
        memory: dict,
        memory_metadata: dict[str, Any],
    ) -> Optional[tuple[dict, dict[str, str], str]]:
        for entity in entities:
            person_metadata = entity.get("metadata")
            if not isinstance(person_metadata, dict):
                continue
            if memory_id not in self._covered_source_memory_ids(person_metadata):
                continue
            person_attributes = person_metadata.get("attributes")
            if not isinstance(person_attributes, dict):
                person_attributes = {}
            if self._builder._is_self_entity(entity):
                attributes = self._builder._self_attributes(memory, memory_metadata)
                reason = "covered_by_self_person_card"
                if attributes and self._person_attributes_cover(
                    person_attributes, attributes
                ):
                    return entity, attributes, reason
                continue

            fact_kind = str(memory_metadata.get("fact_kind") or "").casefold()
            category = str(memory_metadata.get("memory_category") or "").casefold()
            if fact_kind == "relationship" or category == "people":
                return entity, {"relationship": "covered"}, "covered_by_person_card"

            attributes = self._person_memory_attributes(memory_metadata)
            reason = "covered_by_person_card"
            if attributes and self._person_attributes_cover(person_attributes, attributes):
                return entity, attributes, reason
        return None

    def _person_memory_attributes(
        self,
        metadata: dict[str, Any],
    ) -> dict[str, str]:
        if metadata.get("fact_kind") != "birthday":
            return {}
        birthday = self._builder._clean_text(metadata.get("normalized_date"))
        return {"birthday": birthday} if birthday else {}

    def _covered_source_memory_ids(self, metadata: dict[str, Any]) -> set[str]:
        covered: set[str] = set()
        for memory_id in metadata.get("source_memory_ids") or []:
            text = self._builder._clean_text(memory_id)
            if text:
                covered.add(text)
        attribute_sources = metadata.get("attribute_source_memory_ids")
        if isinstance(attribute_sources, dict):
            for values in attribute_sources.values():
                if not isinstance(values, list):
                    continue
                for memory_id in values:
                    text = self._builder._clean_text(memory_id)
                    if text:
                        covered.add(text)
        return covered

    def _person_attributes_cover(
        self,
        person_attributes: dict,
        memory_attributes: dict[str, str],
    ) -> bool:
        for key, value in memory_attributes.items():
            if key == "notes":
                continue
            person_value = self._builder._clean_text(person_attributes.get(key)).casefold()
            memory_value = self._builder._clean_text(value).casefold()
            if not memory_value:
                continue
            if not person_value or memory_value not in person_value:
                return False
        return True
