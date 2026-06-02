from __future__ import annotations

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

    def detect_correction_intent(self, text: str) -> CorrectionIntent:
        return self.intent_parser.detect_correction_intent(text)

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
        for spec in TABLE_SPECS:
            records = await self._safe_list(spec)
            for record in records:
                if not record_contains(record, spec, old_value):
                    continue
                archived = await self._safe_archive(spec, str(record["id"]))
                if not archived:
                    continue
                affected.append(
                    CorrectionAffectedRecord(
                        table=spec.table,
                        id=str(record["id"]),
                        action="archived",
                        title=record_title(record),
                        previous=record,
                    )
                )
        return affected

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
            return bool(await method(record_id))
        except Exception:
            return False
