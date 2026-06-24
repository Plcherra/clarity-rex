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

SELF_LABELS = {"self", "user", "me", "myself"}
SELF_DISPLAY_FALLBACK = "User"

UNSAFE_ALIAS_TERMS = {
    "account",
    "bank",
    "checking",
    "credit",
    "debit",
    "deposit",
    "deposits",
    "merchant",
    "payroll",
    "zelle",
}


class PersonMemoryMaterializer:
    """Best-effort bridge from high-confidence flat facts to Person entities."""

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
        if existing is None:
            await create_entity(card)
            await self._archive_covered_person_source_memories(memory_service, [memory])
            return
        if update_entity is None:
            return

        updates = self._merge_person_card(existing, card)
        if updates:
            await update_entity(str(existing["id"]), **updates)
        await self._archive_covered_person_source_memories(memory_service, [memory])

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

        if metadata.get("fact_kind") != "birthday":
            return None

        label = self._clean_label(metadata.get("entity_label"))
        relationship = PERSON_RELATIONSHIPS.get(label) or "person"
        birthday = self._clean_text(metadata.get("normalized_date"))
        memory_id = self._clean_text(memory.get("id"))
        if not label or not birthday:
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
        if self._clean_label(relationship) == "self" or normalized_name in {
            "self",
            "user",
        }:
            for entity in entities:
                if self._is_self_entity(entity):
                    return entity
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

        if is_self_card and card.get("display_name") != SELF_DISPLAY_FALLBACK:
            current_display = self._clean_text(existing.get("display_name"))
            if not current_display or current_display in {"User", "Self"}:
                updates["display_name"] = card["display_name"]
                current_normalized = self._normalize_name(existing.get("normalized_name"))
                if current_normalized in {"", "self", "user"}:
                    updates["normalized_name"] = card["normalized_name"]

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

    async def _archive_covered_person_source_memories(
        self,
        memory_service,
        memories: list[dict],
    ) -> None:
        list_entities = getattr(memory_service, "list_entities", None)
        update_memory = getattr(memory_service, "update_long_term_memory", None)
        if list_entities is None or update_memory is None:
            return
        try:
            entities = await list_entities(entity_type="person", active=True, limit=100)
        except Exception:
            return

        for memory in memories:
            if not isinstance(memory, dict) or memory.get("active", True) is not True:
                continue
            memory_id = self._clean_text(memory.get("id"))
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
            person, attributes, reason = matched
            archived_metadata = {
                **memory_metadata,
                "canonical_entity_id": person.get("id"),
                "canonical_entity_type": "person",
                "duplicate_archive_reason": reason,
                "covered_attributes": sorted(attributes),
            }
            try:
                await update_memory(
                    memory_id,
                    active=False,
                    metadata=archived_metadata,
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
                continue
            if self._is_self_entity(entity):
                attributes = self._self_attributes(memory, memory_metadata)
                reason = "covered_by_self_person_card"
            else:
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
        birthday = self._clean_text(metadata.get("normalized_date"))
        return {"birthday": birthday} if birthday else {}

    def _covered_source_memory_ids(self, metadata: dict[str, Any]) -> set[str]:
        covered: set[str] = set()
        for memory_id in metadata.get("source_memory_ids") or []:
            text = self._clean_text(memory_id)
            if text:
                covered.add(text)
        attribute_sources = metadata.get("attribute_source_memory_ids")
        if isinstance(attribute_sources, dict):
            for values in attribute_sources.values():
                if not isinstance(values, list):
                    continue
                for memory_id in values:
                    text = self._clean_text(memory_id)
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
            person_value = self._clean_text(person_attributes.get(key)).casefold()
            memory_value = self._clean_text(value).casefold()
            if not memory_value:
                continue
            if not person_value or memory_value not in person_value:
                return False
        return True

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

    def _display_name(self, label: str) -> str:
        if label in {"mom", "mother", "mum", "mama"}:
            return "Mom"
        if label in {"dad", "father", "papa"}:
            return "Dad"
        return label.title()

    def _aliases_for(self, label: str, relationship: str, display_name: str) -> list[str]:
        return [
            alias
            for alias in self._safe_aliases(self._dedupe([label, relationship]))[0]
            if alias.casefold() != display_name.casefold()
        ]

    def _self_birthday_from_memory(
        self,
        content: str,
        metadata: dict[str, Any],
    ) -> str:
        entity_label = self._clean_label(metadata.get("entity_label"))
        if (
            metadata.get("fact_kind") == "birthday"
            and entity_label in SELF_LABELS
            and metadata.get("normalized_date")
        ):
            return self._clean_text(metadata.get("normalized_date"))

        match = re.search(
            r"\b(?:my birthday is|user's birthday is|your birthday is)\s+([^.!?;,]+)",
            content,
            flags=re.IGNORECASE,
        )
        if match is None:
            return ""
        return self._trim_fact_value(match.group(1))

    def _extract_full_name(self, content: str) -> str:
        match = re.search(
            r"\b(?:my name is|user's name is|your name is)\s+"
            r"([A-Za-z][A-Za-z.'-]*(?:\s+[A-Za-z][A-Za-z.'-]*){1,4})",
            content,
            flags=re.IGNORECASE,
        )
        if match is None:
            return ""
        name = self._trim_fact_value(match.group(1))
        return name if self._is_safe_full_name(name) else ""

    def _extract_location(self, content: str) -> str:
        match = re.search(
            r"\b(?:i live in|user lives in|you live in)\s+([^.!?;]+)",
            content,
            flags=re.IGNORECASE,
        )
        if match is None:
            return ""
        return self._trim_fact_value(match.group(1))

    def _extract_work(
        self,
        content: str,
        metadata: dict[str, Any],
    ) -> dict[str, str]:
        result: dict[str, str] = {}
        workplace = self._clean_text(
            metadata.get("workplace") or metadata.get("company")
        )
        job = self._clean_text(metadata.get("job"))
        if workplace:
            result["workplace"] = workplace
        if job:
            result["job"] = job

        work_as_at = re.search(
            r"\b(?:i work|user works|you work)\s+as\s+(?:a|an)?\s*"
            r"(.+?)\s+(?:at|for)\s+([^.!?;]+)",
            content,
            flags=re.IGNORECASE,
        )
        if work_as_at is not None:
            result.setdefault("job", self._trim_fact_value(work_as_at.group(1)))
            result.setdefault(
                "workplace",
                self._trim_workplace(work_as_at.group(2)),
            )
            return {key: value for key, value in result.items() if value}

        work_at = re.search(
            r"\b(?:i work|user works|you work)\s+(?:at|for)\s+([^.!?;]+)",
            content,
            flags=re.IGNORECASE,
        )
        if work_at is not None:
            result.setdefault("workplace", self._trim_workplace(work_at.group(1)))

        workplace_is = re.search(
            r"\b(?:my|user's|your)\s+(?:workplace|employer|company)\s+is\s+([^.!?;]+)",
            content,
            flags=re.IGNORECASE,
        )
        if workplace_is is not None:
            result.setdefault(
                "workplace",
                self._trim_workplace(workplace_is.group(1)),
            )

        job_is = re.search(
            r"\b(?:my|user's|your)\s+job\s+is\s+([^.!?;]+)",
            content,
            flags=re.IGNORECASE,
        )
        if job_is is not None:
            result.setdefault("job", self._trim_fact_value(job_is.group(1)))

        return {key: value for key, value in result.items() if value}

    def _trim_workplace(self, value: str) -> str:
        value = self._trim_fact_value(value)
        value = re.split(
            r"\s+\b(?:with|where|because|while)\b",
            value,
            maxsplit=1,
            flags=re.IGNORECASE,
        )[0]
        return self._clean_text(value)

    def _trim_fact_value(self, value: str) -> str:
        value = self._clean_text(value)
        value = re.split(
            r"\s+\b(?:and|but|with)\b\s+",
            value,
            maxsplit=1,
            flags=re.IGNORECASE,
        )[0]
        value = re.sub(r"[,.;:!?]+$", "", value).strip()
        return value.strip("\"'")

    def _is_safe_full_name(self, value: str) -> bool:
        tokens = self._normalize_name(value).split()
        if len(tokens) < 2:
            return False
        return not self._is_unsafe_alias(value)

    def _is_self_entity(self, entity: dict) -> bool:
        if self._clean_label(entity.get("relationship")) == "self":
            return True
        if self._normalize_name(entity.get("normalized_name")) in {"self", "user"}:
            return True
        metadata = entity.get("metadata")
        return (
            isinstance(metadata, dict)
            and self._clean_label(metadata.get("entity_direction")) == "self"
        )

    def _safe_aliases(self, values: list[object]) -> tuple[list[str], list[str]]:
        aliases = self._dedupe(values)
        safe: list[str] = []
        removed: list[str] = []
        for alias in aliases:
            if self._is_unsafe_alias(alias):
                removed.append(alias)
            else:
                safe.append(alias)
        return safe, removed

    def _is_unsafe_alias(self, value: object) -> bool:
        text = self._normalize_name(value)
        if not text:
            return False
        tokens = set(text.split())
        return bool(tokens & UNSAFE_ALIAS_TERMS) or "bank of america" in text

    def _summary_for_attributes(self, attributes: dict[str, str]) -> str:
        parts: list[str] = []
        if attributes.get("full_name"):
            parts.append(f"Full name: {attributes['full_name']}.")
        if attributes.get("location"):
            parts.append(f"Lives in {attributes['location']}.")
        if attributes.get("birthday"):
            parts.append(f"Birthday: {attributes['birthday']}.")
        work_note = self._work_note(attributes)
        if work_note:
            parts.append(f"{work_note}.")
        return " ".join(parts)

    def _work_note(self, attributes: dict[str, str]) -> str:
        job = attributes.get("job")
        workplace = attributes.get("workplace")
        if job and workplace:
            return f"Works as {job} at {workplace}"
        if workplace:
            return f"Works at {workplace}"
        if job:
            return f"Job: {job}"
        return ""

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
