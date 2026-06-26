from __future__ import annotations

from typing import Any, Optional

from app.services.memory_correction_apply import MemoryCorrectionApplier
from app.services.memory_correction_intent_parser import (
    MemoryCorrectionIntentParser,
    has_trailing_conversational_filler,
    message_requests_filler_removal,
    trim_correction_value,
)
from app.services.memory_correction_record_rules import (
    confirmation_payload,
    record_title,
    spec_for_table,
)
from app.services.memory_correction_types import (
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
        self.applier = MemoryCorrectionApplier(
            memory_service,
            repository_ops=self.repository_ops,
            delete_applier=self.delete_applier,
            delete_resolver=self.delete_resolver,
        )

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
        correction = await self.applier.record_correction(
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
        return await self.applier.apply_correction(
            text,
            source_conversation_id=source_conversation_id,
            source_message_id=source_message_id,
            force=force,
            intent_override=intent_override,
            detect_intent=self.detect_correction_intent,
        )

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
