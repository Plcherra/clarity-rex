import re
from typing import Any

from app.services.person_card_constants import (
    SELF_LABELS,
    UNSAFE_ALIAS_TERMS,
)


class PersonCardBuilderText:
    def _display_name(self, label: str) -> str:
        if label in {"mom", "mother", "mum", "mama"}:
            return "Mom"
        if label in {"dad", "father", "papa"}:
            return "Dad"
        return label.title()

    def _display_possessive_label(self, label: str) -> str:
        cleaned = self._clean_text(label)
        if not cleaned:
            return ""
        if "'s" not in cleaned.lower():
            return self._display_name(cleaned)
        owner, _, relation = cleaned.lower().partition("'s")
        owner_display = owner.strip().title()
        relation_display = self._display_name(relation.strip())
        return f"{owner_display}'s {relation_display}"

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

    def _extract_single_name(self, content: str) -> str:
        """Accept a single given name for explicit name facts (e.g. 'My name is Pedro')."""
        match = re.search(
            r"\b(?:my name is|user's name is|your name is)\s+"
            r"([A-Za-z][A-Za-z.'-]*)",
            content,
            flags=re.IGNORECASE,
        )
        if match is None:
            return ""
        name = self._trim_fact_value(match.group(1))
        if not name or name.casefold() in SELF_LABELS:
            return ""
        return name if name.replace(".", "").replace("'", "").isalpha() else ""

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
