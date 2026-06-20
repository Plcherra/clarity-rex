from __future__ import annotations

import re

from app.services.entity_normalization_service import EntityNormalizationService
from app.services.memory_correction_types import CorrectionIntent, CorrectionIntentType


class MemoryCorrectionIntentParser:
    """Parses explicit user correction language into correction intents."""

    def __init__(
        self,
        entity_normalization_service: EntityNormalizationService | None = None,
    ) -> None:
        self.entity_normalization_service = (
            entity_normalization_service or EntityNormalizationService()
        )

    def detect_correction_intent(self, text: str) -> CorrectionIntent:
        cleaned = clean_text(text)
        lowered = cleaned.lower()
        if not cleaned:
            return CorrectionIntent(CorrectionIntentType.UNKNOWN, confidence=0)

        removal = re.search(
            (
                r"\b(?:delete|remove|archive|drop)\s+"
                r"(?:any\s+)?"
                r"(?:mention|mentions|memory|memories|record|records)\s*"
                r"(?:of|about|for)?\s+(.+)$"
            ),
            cleaned,
            flags=re.IGNORECASE,
        )
        if removal is None:
            removal = re.search(
                r"\b(?:delete|remove|archive|drop)\s+(.+)$",
                cleaned,
                flags=re.IGNORECASE,
            )
        if removal:
            return CorrectionIntent(
                CorrectionIntentType.REMOVE_OBSOLETE,
                old_value=trim_removal_target(removal.group(1)),
                new_value="[archived]",
                confidence=0.9,
            )

        if re.search(r"\bnot\s+a\s+plan\b.*\b(?:task|commitment|checklist)\b", lowered):
            return CorrectionIntent(
                CorrectionIntentType.DOWNGRADE_PLAN_TO_TASK,
                target_hint=cleaned,
                confidence=0.72,
                requires_confirmation=True,
            )

        direct_correction = re.search(
            r"\bnot\s+(.+?)\s*,?\s+(?:it\s+is|it's|actually|the\s+real\s+name\s+is)\s+(.+)$",
            cleaned,
            flags=re.IGNORECASE,
        )
        if direct_correction:
            return CorrectionIntent(
                CorrectionIntentType.REPLACE_VALUE,
                old_value=trim_text(direct_correction.group(1)),
                new_value=trim_text(direct_correction.group(2)),
                confidence=0.9,
            )

        pairs = self.entity_normalization_service.correction_pairs_from_text(cleaned)
        if pairs:
            pair = pairs[0]
            return CorrectionIntent(
                CorrectionIntentType.REPLACE_VALUE,
                old_value=pair.old_value,
                new_value=pair.new_value,
                confidence=pair.confidence,
            )

        replace = re.search(
            r"\b(?:replace|rename|change)\s+(.+?)\s+(?:with|to)\s+(.+)$",
            cleaned,
            flags=re.IGNORECASE,
        )
        if replace:
            return CorrectionIntent(
                CorrectionIntentType.REPLACE_VALUE,
                old_value=trim_text(replace.group(1)),
                new_value=trim_text(replace.group(2)),
                confidence=0.86,
            )

        if re.search(r"\bmerge\b.*\bplans?\b|\bplans?\b.*\bmerge\b", lowered):
            return CorrectionIntent(
                CorrectionIntentType.MERGE_ITEMS,
                target_hint=cleaned,
                confidence=0.7,
                requires_confirmation=True,
            )

        move = re.search(
            r"\b(?:under|inside|into)\s+(?:the\s+)?(.+?)\s+plan\b",
            cleaned,
            flags=re.IGNORECASE,
        )
        if move:
            return CorrectionIntent(
                CorrectionIntentType.MOVE_UNDER_PARENT,
                target_hint=trim_text(move.group(1)),
                confidence=0.72,
                requires_confirmation=True,
            )

        return CorrectionIntent(CorrectionIntentType.UNKNOWN, confidence=0.2)


def clean_text(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def trim_text(value: str) -> str:
    value = clean_text(value)
    value = re.sub(r"[.!?]+$", "", value).strip()
    return value.strip("\"'")


def trim_removal_target(value: str) -> str:
    value = trim_text(value)
    value = re.sub(
        r"^(?:please\s+)?(?:that|this|the)\s+",
        "",
        value,
        flags=re.IGNORECASE,
    )
    value = re.sub(
        (
            r"^(?:saved\s+)?"
            r"(?:mention|mentions|memory|memories|record|records)\s*"
            r"(?:of|about|for)?\s+"
        ),
        "",
        value,
        flags=re.IGNORECASE,
    )
    return value.strip()
