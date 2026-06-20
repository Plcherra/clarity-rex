import re
from typing import Any, Optional


PERSON_RELATIONSHIPS = {
    "mom": "mother",
    "mother": "mother",
    "mum": "mother",
    "mama": "mother",
    "dad": "father",
    "father": "father",
    "papa": "father",
}


class PersonMemoryMaterializer:
    """Best-effort bridge from high-confidence flat facts to Person entities."""

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
        )
        if existing is None:
            await create_entity(card)
            return
        if update_entity is None:
            return

        updates = self._merge_person_card(existing, card)
        if updates:
            await update_entity(str(existing["id"]), **updates)

    def person_card_from_memory(self, memory: dict) -> Optional[dict[str, Any]]:
        if str(memory.get("memory_type") or "") != "fact":
            return None
        if int(memory.get("importance") or 0) < 4:
            return None

        metadata = memory.get("metadata")
        if not isinstance(metadata, dict):
            return None
        if metadata.get("fact_kind") != "birthday":
            return None

        label = self._clean_label(metadata.get("entity_label"))
        relationship = PERSON_RELATIONSHIPS.get(label)
        birthday = self._clean_text(metadata.get("normalized_date"))
        memory_id = self._clean_text(memory.get("id"))
        if not label or not relationship or not birthday:
            return None

        display_name = self._display_name(label)
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

    async def _find_existing_person(
        self,
        list_entities,
        *,
        normalized_name: str,
    ) -> Optional[dict]:
        entities = await list_entities(
            entity_type="person",
            active=True,
            limit=100,
        )
        for entity in entities:
            if self._normalize_name(entity.get("normalized_name")) == normalized_name:
                return entity
            if self._normalize_name(entity.get("display_name")) == normalized_name:
                return entity
            for alias in entity.get("aliases") or []:
                if self._normalize_name(alias) == normalized_name:
                    return entity
        return None

    def _merge_person_card(self, existing: dict, card: dict) -> dict[str, Any]:
        updates: dict[str, Any] = {}
        aliases = self._dedupe([*existing.get("aliases", []), *card.get("aliases", [])])
        if aliases != (existing.get("aliases") or []):
            updates["aliases"] = aliases

        if card.get("relationship") and not existing.get("relationship"):
            updates["relationship"] = card["relationship"]

        metadata = self._merge_metadata(existing.get("metadata"), card.get("metadata"))
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

    def _display_name(self, label: str) -> str:
        if label in {"mom", "mother", "mum", "mama"}:
            return "Mom"
        if label in {"dad", "father", "papa"}:
            return "Dad"
        return label.title()

    def _aliases_for(self, label: str, relationship: str, display_name: str) -> list[str]:
        return [
            alias
            for alias in self._dedupe([label, relationship])
            if alias.casefold() != display_name.casefold()
        ]

    def _clean_label(self, value: object) -> str:
        return self._normalize_name(value)

    def _normalize_name(self, value: object) -> str:
        text = self._clean_text(value).lower()
        text = re.sub(r"[^a-z0-9]+", " ", text)
        return re.sub(r"\s+", " ", text).strip()

    def _clean_text(self, value: object) -> str:
        if value is None:
            return ""
        return re.sub(r"\s+", " ", str(value)).strip()

    def _dedupe(self, values: list[object]) -> list[str]:
        seen: set[str] = set()
        result: list[str] = []
        for value in values:
            text = self._clean_text(value)
            if not text:
                continue
            key = text.casefold()
            if key in seen:
                continue
            seen.add(key)
            result.append(text)
        return result
