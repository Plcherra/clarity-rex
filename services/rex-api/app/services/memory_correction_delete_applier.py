"""Apply confirmed delete matches for memory correction."""

from __future__ import annotations

import re
from typing import Any, Optional

from app.services.memory_correction_record_rules import normalize_key, spec_for_table
from app.services.memory_correction_repository_ops import MemoryCorrectionRepositoryOps
from app.services.memory_correction_types import CorrectionAffectedRecord


class MemoryCorrectionDeleteApplier:
    def __init__(self, repository_ops: MemoryCorrectionRepositoryOps) -> None:
        self.repository_ops = repository_ops

    async def apply_single_delete_match(
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

        archived = await self.repository_ops.safe_archive(
            spec_for_table(match.table),
            match.id,
        )
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

        updated = await self.repository_ops.safe_update(
            spec_for_table("entities"),
            match.id,
            {
                "metadata": updated_metadata,
                "summary": summary,
            },
        )
        if updated is None:
            return None

        active_sources = await self.repository_ops.active_source_memories(
            resolution.get("source_memory_ids") or [],
        )
        for source_memory in active_sources:
            archived = await self.repository_ops.safe_archive(
                spec_for_table("long_term_memory"),
                str(source_memory["id"]),
            )
            if not archived:
                return None

        if _entity_attribute_still_present(updated, attribute_key, attribute_value):
            return None
        return updated


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
