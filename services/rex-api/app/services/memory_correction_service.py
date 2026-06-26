from __future__ import annotations

import re
from typing import Any, Optional

from app.services.memory_correction_intent_parser import (
    MemoryCorrectionIntentParser,
    has_trailing_conversational_filler,
    message_requests_filler_removal,
    trim_correction_value,
)
from app.services.memory_correction_record_rules import (
    confirmation_payload,
    correction_type_for_table,
    dedupe_affected,
    negative_fired_fact,
    normalize_key,
    person_fact_entity_updates,
    person_fact_stale_terms,
    record_contains,
    record_contains_all_terms,
    record_title,
    removal_match_terms,
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
from app.services.memory_correction_delete_applier import MemoryCorrectionDeleteApplier
from app.services.memory_correction_repository_ops import MemoryCorrectionRepositoryOps
from app.services.memory_delete_resolver import MemoryDeleteResolver, ParsedDeleteRequest
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
        self.delete_resolver = MemoryDeleteResolver(
            memory_service,
            reference_resolver=self.reference_resolver,
            scan_limit=scan_limit,
        )
        self.repository_ops = MemoryCorrectionRepositoryOps(
            memory_service,
            scan_limit=scan_limit,
        )
        self.delete_applier = MemoryCorrectionDeleteApplier(self.repository_ops)

    def detect_correction_intent(self, text: str) -> CorrectionIntent:
        return self.intent_parser.detect_correction_intent(text)

    async def resolve_filler_strip_intent(self, text: str) -> CorrectionIntent | None:
        if not message_requests_filler_removal(text):
            return None

        entities = await self.repository_ops.safe_list(spec_for_table("entities")) or []
        candidates = [
            entity
            for entity in entities
            if has_trailing_conversational_filler(
                str(entity.get("display_name") or "")
            )
        ]
        if len(candidates) != 1:
            return None

        display_name = str(candidates[0].get("display_name") or "").strip()
        cleaned_name = trim_correction_value(display_name)
        if not display_name or not cleaned_name or display_name.casefold() == cleaned_name.casefold():
            return None

        return CorrectionIntent(
            CorrectionIntentType.REPLACE_VALUE,
            old_value=display_name,
            new_value=cleaned_name,
            confidence=0.84,
        )

    async def preview_remove_obsolete(
        self,
        old_value: str,
        *,
        scope_tables: tuple[str, ...] = (),
        is_vague: bool = False,
    ) -> list[CorrectionAffectedRecord]:
        return await self._records_matching_removal(
            old_value,
            scope_tables=scope_tables,
            is_vague=is_vague,
        )

    async def apply_confirmed_remove_obsolete(
        self,
        old_value: str,
        *,
        source_conversation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
        scope_tables: tuple[str, ...] = (),
        is_vague: bool = False,
    ) -> CorrectionReport:
        intent = CorrectionIntent(
            CorrectionIntentType.REMOVE_OBSOLETE,
            old_value=old_value,
            new_value="[archived]",
            confidence=0.9,
            delete_scope_tables=scope_tables,
            is_vague_delete_reference=is_vague,
        )
        report = CorrectionReport(intent=intent)
        matches = await self.preview_remove_obsolete(
            old_value,
            scope_tables=scope_tables,
            is_vague=is_vague,
        )
        if len(matches) != 1:
            report.requires_confirmation = len(matches) > 1
            if len(matches) > 1:
                report.confirmation_payload = {
                    **confirmation_payload(intent),
                    "affected_count": len(matches),
                }
            return report

        match = matches[0]
        affected_record = await self.delete_applier.apply_single_delete_match(match)
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
            for remaining in await self.preview_remove_obsolete(
                old_value,
                scope_tables=scope_tables,
                is_vague=is_vague,
            )
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
        intent_override: CorrectionIntent | None = None,
    ) -> CorrectionReport:
        intent = intent_override or self.detect_correction_intent(text)
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
        entities = await self.repository_ops.safe_list(spec_for_table("entities"))
        if not entities:
            return affected

        for entity in entities:
            updates = person_fact_entity_updates(entity, text)
            if not updates:
                continue
            updated = await self.repository_ops.safe_update(
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
            records = await self.repository_ops.safe_list(spec)
            for record in records:
                if not record_contains(record, spec, person_name):
                    continue
                updates = replace_fired_fact_updates(record, spec, replacement)
                if not updates:
                    continue
                updated = await self.repository_ops.safe_update(spec, str(record["id"]), updates)
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
            records = await self.repository_ops.safe_list(spec)
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
            records = await self.repository_ops.safe_list(spec)
            for record in records:
                updates = replacement_updates(record, spec, old_value, new_value)
                if not updates:
                    continue
                updated = await self.repository_ops.safe_update(spec, str(record["id"]), updates)
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
            affected_record = await self.delete_applier.apply_single_delete_match(match)
            if affected_record is None:
                continue
            affected.append(affected_record)
        return affected

    async def _records_matching_removal(
        self,
        old_value: str,
        *,
        scope_tables: tuple[str, ...] = (),
        is_vague: bool = False,
    ) -> list[CorrectionAffectedRecord]:
        return await self.delete_resolver.resolve(
            ParsedDeleteRequest(
                reference=old_value,
                scope_tables=scope_tables,
                is_vague=is_vague,
            )
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

    async def _archive_superseded_entities(
        self,
        old_value: str,
        new_value: str,
    ) -> list[CorrectionAffectedRecord]:
        old_key = normalize_key(old_value)
        new_key = normalize_key(new_value)
        if not old_key or not new_key or old_key == new_key:
            return []
        entities = await self.repository_ops.safe_list(spec_for_table("entities"))
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
            archived = await self.repository_ops.safe_archive(spec_for_table("entities"), str(entity["id"]))
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
        updated_canonical = await self.repository_ops.safe_update(
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
