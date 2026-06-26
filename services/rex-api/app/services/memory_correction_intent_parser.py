from __future__ import annotations

import re

from app.services.entity_normalization_service import EntityNormalizationService
from app.services.memory_correction_types import CorrectionIntent, CorrectionIntentType
from app.services.memory_delete_reference import extract_reference_delete_target

_POLITE_SUFFIX_PATTERN = re.compile(
    r"(?:\s+|^)(?:please|thanks|thank you|thx|haha|ha ha|lol|ok|okay)\.?$",
    re.IGNORECASE,
)
_POLITE_PREFIX_PATTERN = re.compile(r"^(?:please\s+)", re.IGNORECASE)
_QUOTED_POLITE_SUFFIX_PATTERN = re.compile(
    r"\s+['\"]?(?:please|thanks|thank you)['\"]?\s*$",
    re.IGNORECASE,
)
_FILLER_REMOVAL_PATTERN = re.compile(
    r"\b(?:without|remove|drop|no)\s+(?:the\s+)?['\"]?(?P<filler>please|thanks|thank you)['\"]?\b",
    re.IGNORECASE,
)
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
                r"\b(?:delete|remove|archive|drop|forget|erase|clear)\s+"
                r"(?:any\s+)?"
                r"(?:mention|mentions|memory|memories|record|records)\s*"
                r"(?:of|about|for)?\s+(.+)$"
            ),
            cleaned,
            flags=re.IGNORECASE,
        )
        if removal is None:
            removal = re.search(
                r"\b(?:delete|remove|archive|drop|forget|erase|clear)\s+(.+)$",
                cleaned,
                flags=re.IGNORECASE,
            )
        if removal is None:
            removal = re.search(
                r"\bget\s+rid\s+of\s+(.+)$",
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

        goal_delete = re.search(
            r"\b(?:delete|remove|archive)\s+(?:the\s+)?(?:old\s+)?(?:goal|commitment)\b"
            r"(?:\s+['\"](?P<quoted>.+?)['\"])?",
            cleaned,
            flags=re.IGNORECASE,
        )
        if goal_delete:
            quoted = goal_delete.group("quoted")
            if quoted:
                return CorrectionIntent(
                    CorrectionIntentType.REMOVE_OBSOLETE,
                    old_value=trim_removal_target(quoted),
                    new_value="[archived]",
                    confidence=0.9,
                )
            return CorrectionIntent(
                CorrectionIntentType.REMOVE_OBSOLETE,
                old_value="goal",
                new_value="[archived]",
                confidence=0.72,
            )

        reference_target = extract_reference_delete_target(cleaned)
        if reference_target:
            return CorrectionIntent(
                CorrectionIntentType.REMOVE_OBSOLETE,
                old_value=trim_removal_target(reference_target),
                new_value="[archived]",
                confidence=0.88,
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
            old_value, new_value = normalize_correction_pair(
                direct_correction.group(1),
                direct_correction.group(2),
            )
            return CorrectionIntent(
                CorrectionIntentType.REPLACE_VALUE,
                old_value=old_value,
                new_value=new_value,
                confidence=0.9,
            )

        actually_correction = re.search(
            r"\b(?:the\s+)?(.+?)\s+is\s+actually\s+(.+)$",
            cleaned,
            flags=re.IGNORECASE,
        )
        if actually_correction:
            old_value, new_value = normalize_correction_pair(
                actually_correction.group(1),
                actually_correction.group(2),
            )
            return CorrectionIntent(
                CorrectionIntentType.REPLACE_VALUE,
                old_value=old_value,
                new_value=new_value,
                confidence=0.9,
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

        meant_correction = re.search(
            r"\b(.+?)\s+(?:should be|meant to be|is really)\s+(.+)$",
            cleaned,
            flags=re.IGNORECASE,
        )
        if meant_correction:
            old_value, new_value = normalize_correction_pair(
                meant_correction.group(1),
                meant_correction.group(2),
            )
            return CorrectionIntent(
                CorrectionIntentType.REPLACE_VALUE,
                old_value=old_value,
                new_value=new_value,
                confidence=0.88,
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
            (
                r"(?:\bcan you\s+|\bcould you\s+)?"
                r"\b(?:replace|rename|change|update|fix|edit)\s+(.+?)\s+(?:with|to)\s+(.+)$"
            ),
            cleaned,
            flags=re.IGNORECASE,
        )
        if replace:
            old_value, new_value = normalize_correction_pair(
                replace.group(1),
                replace.group(2),
            )
            return CorrectionIntent(
                CorrectionIntentType.REPLACE_VALUE,
                old_value=old_value,
                new_value=new_value,
                confidence=0.86,
            )

        return CorrectionIntent(CorrectionIntentType.UNKNOWN, confidence=0.2)


def clean_text(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def message_requests_filler_removal(text: str) -> bool:
    return bool(_FILLER_REMOVAL_PATTERN.search(clean_text(text)))


def trim_text(value: str) -> str:
    value = clean_text(value)
    value = re.sub(r"[.!?]+$", "", value).strip()
    return value.strip("\"'")


def trim_correction_value(value: str) -> str:
    value = trim_text(value)
    while True:
        updated = _QUOTED_POLITE_SUFFIX_PATTERN.sub("", value).strip()
        updated = _POLITE_SUFFIX_PATTERN.sub("", updated).strip()
        updated = _POLITE_PREFIX_PATTERN.sub("", updated).strip()
        if updated == value:
            break
        value = updated
    return value.strip("\"'")


def has_trailing_conversational_filler(value: str) -> bool:
    cleaned = trim_text(value)
    if _QUOTED_POLITE_SUFFIX_PATTERN.search(cleaned):
        return True
    return bool(_POLITE_SUFFIX_PATTERN.search(f" {cleaned}"))


def normalize_correction_pair(old_value: str, new_value: str) -> tuple[str, str]:
    raw_old = trim_text(old_value)
    raw_new = trim_text(new_value)
    trimmed_old = trim_correction_value(raw_old)
    trimmed_new = trim_correction_value(raw_new)

    if trimmed_old.casefold() == trimmed_new.casefold():
        if has_trailing_conversational_filler(raw_old):
            return raw_old, trimmed_new
        if has_trailing_conversational_filler(raw_new):
            return trimmed_old, trimmed_new
        return trimmed_old, trimmed_new

    return trimmed_old, trimmed_new

def trim_removal_target(value: str) -> str:
    value = trim_text(value)
    value = re.sub(
        r"^(?:please\s+)?(?:about\s+)?(?:that|this|the)\s+",
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
