from __future__ import annotations

import re
from typing import Any, Optional

from app.services.memory_correction_intent_parser import MemoryCorrectionIntentParser
from app.services.memory_correction_record_rules import (
    confirmation_payload,
    correction_type_for_table,
    dedupe_affected,
    negative_fired_fact,
    normalize_key,
    person_fact_entity_updates,
    person_fact_stale_terms,
    record_contains,
    record_title,
    replacement_updates,
    replace_fired_fact_updates,
    spec_for_table,
)
from app.services.memory_correction_types import (
    CORRECTION_VERSION,
    HIGH_IMPACT_RECORD_THRESHOLD,
    TABLE_SPECS,
    CorrectionAffectedRecord,
    CorrectionIntent,
    CorrectionIntentType,
    CorrectionReport,
    MemoryCorrectionRepository,
    TableSpec,
)
from app.services.memory_reference_resolver import KnowsReferenceMatch, MemoryReferenceResolver


class MemoryCorrectionService:
    """Detects and applies explicit memory corrections across structured records."""

    def __init__(
        self,
        memory_service: MemoryCorrectionRepository,
        *,
        scan_limit: int = 250,
    ) -> None:
        self.memory_service = memory_service
        self.scan_limit = scan_limit
        self.intent_parser = MemoryCorrectionIntentParser()
        self.reference_resolver = MemoryReferenceResolver(memory_service)

    def detect_correction_intent(self, text: str) -> CorrectionIntent:
        return self.intent_parser.detect_correction_intent(text)

    async def preview_remove_obsolete(
        self,
        old_value: str,
    ) -> list[CorrectionAffectedRecord]:
        return await self._records_matching_removal(old_value)

    async def apply_confirmed_remove_obsolete(
        self,
        old_value: str,
        *,
        source_conversation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
    ) -> CorrectionReport:
        intent = CorrectionIntent(
            CorrectionIntentType.REMOVE_OBSOLETE,
            old_value=old_value,
            new_value="[archived]",
            confidence=0.9,
        )
        report = CorrectionReport(intent=intent)
        matches = await self.preview_remove_obsolete(old_value)
        if len(matches) != 1:
            report.requires_confirmation = len(matches) > 1
            if len(matches) > 1:
                report.confirmation_payload = {
                    **confirmation_payload(intent),
                    "affected_count": len(matches),
                }
            return report

        match = matches[0]
        affected_record = await self._apply_single_delete_match(match)
        if affected_record is None:
            report.errors.append(
                {
                    "source": match.table,
                    "message": "Delete was not confirmed by the backend.",
                }
            )
            return report

        remaining_matches = [
            remaining
            for remaining in await self.preview_remove_obsolete(old_value)
            if not (remaining.table == match.table and remaining.id == match.id)
        ]
        if remaining_matches:
            report.errors.append(
                {
                    "source": "memory_delete_verification",
                    "message": "Active saved records still match the delete target.",
                }
            )
            report.affected_records = [affected_record]
            return report

        report.affected_records = [affected_record]
        report.applied = True
        correction = await self._record_correction(
            intent,
            affected_record,
            source_conversation_id=source_conversation_id,
            source_message_id=source_message_id,
        )
        if correction:
            report.corrections.append(correction)
        return report

    async def apply_correction(
        self,
        text: str,
        *,
        source_conversation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
        force: bool = False,
    ) -> CorrectionReport:
        intent = self.detect_correction_intent(text)
        report = CorrectionReport(intent=intent)
        if intent.intent_type == CorrectionIntentType.UNKNOWN:
            person_affected = await self._apply_person_fact_correction(text)
            if not person_affected:
                return report
            report.affected_records = person_affected
            report.applied = True
            report.verification_stale_terms = person_fact_stale_terms(text)
            for affected_record in person_affected:
                correction = await self._record_correction(
                    intent,
                    affected_record,
                    source_conversation_id=source_conversation_id,
                    source_message_id=source_message_id,
                )
                if correction:
                    report.corrections.append(correction)
            return report

        if intent.requires_confirmation and not force:
            report.requires_confirmation = True
            report.confirmation_payload = confirmation_payload(intent)
            return report

        preview_count = await self._preview_affected_count(intent)
        if preview_count > HIGH_IMPACT_RECORD_THRESHOLD and not force:
            report.requires_confirmation = True
            report.confirmation_payload = {
                **confirmation_payload(intent),
                "affected_count": preview_count,
            }
            return report

        if intent.intent_type == CorrectionIntentType.REMOVE_OBSOLETE:
            affected = await self._archive_records_matching(intent.old_value or "")
        elif intent.intent_type == CorrectionIntentType.REPLACE_VALUE:
            affected = await self._replace_value(intent.old_value or "", intent.new_value or "")
        else:
            report.requires_confirmation = True
            report.confirmation_payload = confirmation_payload(intent)
            return report

        report.affected_records = affected
        report.applied = bool(affected)
        for affected_record in affected:
            correction = await self._record_correction(
                intent,
                affected_record,
                source_conversation_id=source_conversation_id,
                source_message_id=source_message_id,
            )
            if correction:
                report.corrections.append(correction)
        return report

    async def _apply_person_fact_correction(
        self,
        text: str,
    ) -> list[CorrectionAffectedRecord]:
        affected: list[CorrectionAffectedRecord] = []
        entities = await self._safe_list(spec_for_table("entities"))
        if not entities:
            return affected

        for entity in entities:
            updates = person_fact_entity_updates(entity, text)
            if not updates:
                continue
            updated = await self._safe_update(
                spec_for_table("entities"),
                str(entity["id"]),
                updates,
            )
            if updated is None:
                continue
            affected.append(
                CorrectionAffectedRecord(
                    table="entities",
                    id=str(entity["id"]),
                    action="updated",
                    title=record_title(entity),
                    previous=entity,
                    updated=updated,
                )
            )

        negative_fired = negative_fired_fact(text)
        if negative_fired:
            affected.extend(
                await self._replace_person_stale_fired_fact(
                    person_name=negative_fired["name"],
                    replacement=negative_fired["replacement"],
                )
            )
        return dedupe_affected(affected)

    async def _replace_person_stale_fired_fact(
        self,
        *,
        person_name: str,
        replacement: str,
    ) -> list[CorrectionAffectedRecord]:
        affected: list[CorrectionAffectedRecord] = []
        person_key = normalize_key(person_name)
        if not person_key or not replacement:
            return affected

        for spec in TABLE_SPECS:
            records = await self._safe_list(spec)
            for record in records:
                if not record_contains(record, spec, person_name):
                    continue
                updates = replace_fired_fact_updates(record, spec, replacement)
                if not updates:
                    continue
                updated = await self._safe_update(spec, str(record["id"]), updates)
                if updated is None:
                    continue
                affected.append(
                    CorrectionAffectedRecord(
                        table=spec.table,
                        id=str(record["id"]),
                        action="updated",
                        title=record_title(record),
                        previous=record,
                        updated=updated,
                    )
                )
        return affected

    async def _preview_affected_count(self, intent: CorrectionIntent) -> int:
        if intent.intent_type not in {
            CorrectionIntentType.REMOVE_OBSOLETE,
            CorrectionIntentType.REPLACE_VALUE,
        }:
            return 0
        count = 0
        for spec in TABLE_SPECS:
            records = await self._safe_list(spec)
            for record in records:
                if intent.intent_type == CorrectionIntentType.REMOVE_OBSOLETE:
                    if record_contains(record, spec, intent.old_value or ""):
                        count += 1
                elif replacement_updates(
                    record,
                    spec,
                    intent.old_value or "",
                    intent.new_value or "",
                ):
                    count += 1
        return count

    async def _replace_value(
        self,
        old_value: str,
        new_value: str,
    ) -> list[CorrectionAffectedRecord]:
        if not old_value or not new_value:
            return []
        affected: list[CorrectionAffectedRecord] = []
        for spec in TABLE_SPECS:
            records = await self._safe_list(spec)
            for record in records:
                updates = replacement_updates(record, spec, old_value, new_value)
                if not updates:
                    continue
                updated = await self._safe_update(spec, str(record["id"]), updates)
                if updated is None:
                    continue
                affected.append(
                    CorrectionAffectedRecord(
                        table=spec.table,
                        id=str(record["id"]),
                        action="updated",
                        title=record_title(record),
                        previous=record,
                        updated=updated,
                    )
                )

        affected.extend(await self._archive_superseded_entities(old_value, new_value))
        return dedupe_affected(affected)

    async def _archive_records_matching(
        self,
        old_value: str,
    ) -> list[CorrectionAffectedRecord]:
        if not old_value:
            return []
        affected: list[CorrectionAffectedRecord] = []
        for match in await self._records_matching_removal(old_value):
            affected_record = await self._apply_single_delete_match(match)
            if affected_record is None:
                continue
            affected.append(affected_record)
        return affected

    async def _records_matching_removal(
        self,
        old_value: str,
    ) -> list[CorrectionAffectedRecord]:
        exact_matches: list[CorrectionAffectedRecord] = []
        fuzzy_matches: list[CorrectionAffectedRecord] = []
        terms = removal_match_terms(old_value)
        for spec in TABLE_SPECS:
            records = await self._safe_list(spec)
            for record in records:
                if record_contains(record, spec, old_value):
                    exact_matches.append(self._affected_preview(spec, record))
                elif terms and record_contains_all_terms(record, spec, terms):
                    fuzzy_matches.append(self._affected_preview(spec, record))
        if exact_matches or fuzzy_matches:
            return dedupe_affected(exact_matches or fuzzy_matches)

        knows_matches = await self.reference_resolver.resolve_knows_delete_reference(
            old_value,
            limit=self.scan_limit,
        )
        return dedupe_affected(
            [self._affected_preview_for_knows_match(match) for match in knows_matches]
        )

    def _affected_preview(
        self,
        spec: TableSpec,
        record: dict[str, Any],
    ) -> CorrectionAffectedRecord:
        return CorrectionAffectedRecord(
            table=spec.table,
            id=str(record["id"]),
            action="would_archive",
            title=record_title(record),
            previous=record,
        )

    def _affected_preview_for_knows_match(
        self,
        match: KnowsReferenceMatch,
    ) -> CorrectionAffectedRecord:
        previous = dict(match.record)
        if match.attribute_key:
            previous["__delete_resolution"] = {
                "action": match.action,
                "attribute_key": match.attribute_key,
                "attribute_value": match.attribute_value,
                "source_memory_ids": list(match.source_memory_ids),
            }
        return CorrectionAffectedRecord(
            table=match.table,
            id=match.id,
            action=match.action,
            title=match.title,
            previous=previous,
        )

    async def _apply_single_delete_match(
        self,
        match: CorrectionAffectedRecord,
    ) -> Optional[CorrectionAffectedRecord]:
        if match.action == "would_remove_attribute":
            updated = await self._safe_remove_entity_attribute(match)
            if updated is None:
                return None
            return CorrectionAffectedRecord(
                table=match.table,
                id=match.id,
                action="updated",
                title=match.title,
                previous=match.previous,
                updated=updated,
            )

        archived = await self._safe_archive(spec_for_table(match.table), match.id)
        if not archived:
            return None
        return CorrectionAffectedRecord(
            table=match.table,
            id=match.id,
            action="archived",
            title=match.title,
            previous=match.previous,
        )

    async def _safe_remove_entity_attribute(
        self,
        match: CorrectionAffectedRecord,
    ) -> Optional[dict[str, Any]]:
        resolution = match.previous.get("__delete_resolution")
        if not isinstance(resolution, dict):
            return None
        attribute_key = str(resolution.get("attribute_key") or "").strip()
        if not attribute_key:
            return None

        previous = {
            key: value
            for key, value in match.previous.items()
            if key != "__delete_resolution"
        }
        metadata = previous.get("metadata")
        if not isinstance(metadata, dict):
            return None
        updated_metadata = dict(metadata)
        attributes = dict(updated_metadata.get("attributes") or {})
        if attribute_key not in attributes:
            return None

        attribute_value = str(attributes.pop(attribute_key) or "").strip()
        updated_metadata["attributes"] = attributes

        attribute_sources = updated_metadata.get("attribute_source_memory_ids")
        if isinstance(attribute_sources, dict):
            updated_sources = dict(attribute_sources)
            updated_sources.pop(attribute_key, None)
            updated_metadata["attribute_source_memory_ids"] = updated_sources

        summary = _summary_without_attribute(
            str(previous.get("summary") or ""),
            attribute_key,
            attribute_value,
        )

        updated = await self._safe_update(
            spec_for_table("entities"),
            match.id,
            {
                "metadata": updated_metadata,
                "summary": summary,
            },
        )
        if updated is None:
            return None

        active_sources = await self._active_source_memories(
            resolution.get("source_memory_ids") or [],
        )
        for source_memory in active_sources:
            archived = await self._safe_archive(
                spec_for_table("long_term_memory"),
                str(source_memory["id"]),
            )
            if not archived:
                return None

        if _entity_attribute_still_present(updated, attribute_key, attribute_value):
            return None
        return updated

    async def _active_source_memories(
        self,
        source_memory_ids: list,
    ) -> list[dict[str, Any]]:
        source_ids = {
            str(source_id).strip()
            for source_id in source_memory_ids
            if str(source_id).strip()
        }
        if not source_ids:
            return []
        active_memories = await self._safe_list(spec_for_table("long_term_memory"))
        return [
            memory
            for memory in active_memories
            if str(memory.get("id") or "") in source_ids
        ]

    async def _archive_superseded_entities(
        self,
        old_value: str,
        new_value: str,
    ) -> list[CorrectionAffectedRecord]:
        old_key = normalize_key(old_value)
        new_key = normalize_key(new_value)
        if not old_key or not new_key or old_key == new_key:
            return []
        entities = await self._safe_list(spec_for_table("entities"))
        canonical = next(
            (
                entity
                for entity in entities
                if normalize_key(entity.get("display_name")) == new_key
                or normalize_key(entity.get("normalized_name")) == new_key
            ),
            None,
        )
        if canonical is None:
            return []

        affected: list[CorrectionAffectedRecord] = []
        for entity in entities:
            if str(entity.get("id")) == str(canonical.get("id")):
                continue
            names = [
                entity.get("display_name"),
                entity.get("normalized_name"),
                *(entity.get("aliases") or []),
            ]
            if old_key not in {normalize_key(name) for name in names}:
                continue
            archived = await self._safe_archive(spec_for_table("entities"), str(entity["id"]))
            if archived:
                affected.append(
                    CorrectionAffectedRecord(
                        table="entities",
                        id=str(entity["id"]),
                        action="archived",
                        title=record_title(entity),
                        previous=entity,
                    )
                )

        metadata = dict(canonical.get("metadata") or {})
        obsolete = set(metadata.get("obsolete_aliases") or [])
        obsolete.add(old_key)
        metadata["obsolete_aliases"] = sorted(obsolete)
        metadata["correction_confidence"] = 0.9
        updated_canonical = await self._safe_update(
            spec_for_table("entities"),
            str(canonical["id"]),
            {"metadata": metadata},
        )
        if updated_canonical:
            affected.append(
                CorrectionAffectedRecord(
                    table="entities",
                    id=str(canonical["id"]),
                    action="updated",
                    title=record_title(canonical),
                    previous=canonical,
                    updated=updated_canonical,
                )
            )
        return affected

    async def _record_correction(
        self,
        intent: CorrectionIntent,
        affected_record: CorrectionAffectedRecord,
        *,
        source_conversation_id: Optional[str],
        source_message_id: Optional[str],
    ) -> Optional[dict[str, Any]]:
        create_correction = getattr(self.memory_service, "create_memory_correction", None)
        if create_correction is None:
            return None
        payload = {
            "correction_type": correction_type_for_table(affected_record.table, intent),
            "old_value": intent.old_value or affected_record.title,
            "new_value": intent.new_value or "[archived]",
            "target_table": affected_record.table,
            "target_id": affected_record.id,
            "source_conversation_id": source_conversation_id,
            "source_message_id": source_message_id,
            "applied": True,
            "confidence": intent.confidence,
            "metadata": {
                "correction_version": CORRECTION_VERSION,
                "intent_type": intent.intent_type.value,
                "action": affected_record.action,
                "affected_title": affected_record.title,
            },
        }
        try:
            return await create_correction(payload)
        except Exception:
            return None

    async def _safe_list(self, spec: TableSpec) -> list[dict[str, Any]]:
        method = getattr(self.memory_service, spec.list_method, None)
        if method is None:
            return []
        try:
            return await method(active=True, limit=self.scan_limit)
        except TypeError:
            try:
                return await method(limit=self.scan_limit)
            except Exception:
                return []
        except Exception:
            return []

    async def _safe_update(
        self,
        spec: TableSpec,
        record_id: str,
        updates: dict[str, Any],
    ) -> Optional[dict[str, Any]]:
        method = getattr(self.memory_service, spec.update_method, None)
        if method is None:
            return None
        try:
            return await method(record_id, **updates)
        except Exception:
            return None

    async def _safe_archive(self, spec: TableSpec, record_id: str) -> bool:
        method = getattr(self.memory_service, spec.deactivate_method, None)
        if method is None:
            return False
        try:
            archived = await method(record_id)
        except Exception:
            return False
        return await self._archive_was_confirmed(spec, record_id, archived)

    async def _archive_was_confirmed(
        self,
        spec: TableSpec,
        record_id: str,
        archived: object,
    ) -> bool:
        if not archived:
            return False
        if isinstance(archived, dict) and archived.get("active") is not False:
            return False
        active_records = await self._verified_active_list(spec)
        if active_records is None:
            return False
        return all(str(record.get("id") or "") != record_id for record in active_records)

    async def _verified_active_list(
        self,
        spec: TableSpec,
    ) -> Optional[list[dict[str, Any]]]:
        method = getattr(self.memory_service, spec.list_method, None)
        if method is None:
            return None
        try:
            return await method(active=True, limit=self.scan_limit)
        except TypeError:
            try:
                return await method(limit=self.scan_limit)
            except Exception:
                return None
        except Exception:
            return None


REMOVAL_MATCH_STOP_WORDS = {
    "a",
    "about",
    "an",
    "any",
    "event",
    "fact",
    "for",
    "it",
    "memory",
    "memories",
    "mention",
    "mentions",
    "of",
    "plan",
    "planning",
    "plans",
    "record",
    "records",
    "saved",
    "that",
    "the",
    "this",
    "to",
}


def removal_match_terms(value: str) -> set[str]:
    return {
        term
        for term in normalize_key(value).split()
        if len(term) >= 3 and term not in REMOVAL_MATCH_STOP_WORDS
    }


def record_contains_all_terms(
    record: dict[str, Any],
    spec: TableSpec,
    terms: set[str],
) -> bool:
    if not terms:
        return False
    haystack = normalize_key([record.get(field_name) for field_name in spec.text_fields])
    return all(term in haystack for term in terms)


def _summary_without_attribute(
    summary: str,
    attribute_key: str,
    attribute_value: str,
) -> str:
    if not summary or not attribute_value:
        return summary
    value_key = normalize_key(attribute_value)
    attribute_label = normalize_key(attribute_key.replace("_", " "))
    kept_sentences = []
    for sentence in re.split(r"(?<=[.!?])\s+", summary):
        sentence_key = normalize_key(sentence)
        if value_key and value_key in sentence_key:
            continue
        if attribute_label and sentence_key.startswith(attribute_label):
            continue
        kept_sentences.append(sentence.strip())
    return " ".join(sentence for sentence in kept_sentences if sentence).strip()


def _entity_attribute_still_present(
    entity: dict[str, Any],
    attribute_key: str,
    attribute_value: str,
) -> bool:
    metadata = entity.get("metadata")
    if not isinstance(metadata, dict):
        return False
    attributes = metadata.get("attributes")
    if not isinstance(attributes, dict):
        return False
    if attribute_key in attributes:
        return True
    value_key = normalize_key(attribute_value)
    return bool(value_key and value_key in normalize_key(attributes))
