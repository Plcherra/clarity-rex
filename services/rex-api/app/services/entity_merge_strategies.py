from __future__ import annotations

import re
from typing import Any

from app.services.entity_errors import EntityServiceError

ENTITY_DESCRIPTOR_PREFIXES = (
    "the girl ",
    "a girl ",
    "girl ",
    "the guy ",
    "a guy ",
    "guy ",
    "the person ",
    "a person ",
    "person ",
)

ENTITY_DESCRIPTOR_SUFFIXES = (
    " from work",
    " at work",
    " from school",
    " from church",
    " from gym",
    " from the gym",
)

PERSON_DESCRIPTOR_ALIASES = (
    ("girl from work", r"\b(?:the |a |that )?girl from work\b"),
    ("guy from work", r"\b(?:the |a |that )?guy from work\b"),
    ("person from work", r"\b(?:the |a |that )?person from work\b"),
    ("coworker", r"\bcoworker\b"),
)


def strip_entity_descriptors(normalized: str) -> str | None:
    return _strip_entity_descriptors(normalized)


def _strip_entity_descriptors(normalized: str) -> str | None:
    stripped = normalized
    for prefix in ENTITY_DESCRIPTOR_PREFIXES:
        if stripped.startswith(prefix):
            stripped = stripped[len(prefix) :].strip()
            break
    for suffix in ENTITY_DESCRIPTOR_SUFFIXES:
        if stripped.endswith(suffix):
            stripped = stripped[: -len(suffix)].strip()
            break
    if not stripped or _is_descriptor_fragment(stripped):
        return None
    return stripped


def canonical_display_name(
    entity_type: str | None,
    display_name: str,
    normalized_name: str | None,
    aliases: list[str],
) -> str:
    if entity_type != "person":
        return display_name
    for value in (display_name, normalized_name, *aliases):
        canonical = _canonical_person_name(value)
        if canonical:
            return canonical
    return display_name


def entity_aliases(
    payload: dict[str, Any],
    *,
    original_display_name: str,
    original_normalized_name: str | None,
    original_aliases: list[str],
    display_name: str,
) -> list[str]:
    aliases = [*original_aliases]
    if payload.get("entity_type") == "person":
        aliases.extend([original_display_name, original_normalized_name or ""])
        aliases.extend(
            _person_descriptor_aliases(
                " ".join(
                    str(payload.get(field) or "")
                    for field in ("relationship", "summary")
                )
            )
        )
    aliases = _dedupe_strings(aliases)
    return [alias for alias in aliases if alias.casefold() != display_name.casefold()]


def correction_wrong_names(payload: dict[str, Any]) -> set[str]:
    return _correction_wrong_names(payload)


def entity_match_keys(
    entity: dict[str, Any],
    *,
    include_aliases: bool = True,
) -> set[str]:
    return _entity_match_keys(entity, include_aliases=include_aliases)


def entity_matches_payload(
    entity: dict[str, Any],
    payload: dict[str, Any],
    *,
    ignore_alias_matches: bool = False,
) -> bool:
    return _entity_matches_payload(
        entity,
        payload,
        ignore_alias_matches=ignore_alias_matches,
    )


def is_superseded_entity(entity: dict[str, Any], wrong_names: set[str]) -> bool:
    return _is_superseded_entity(entity, wrong_names)


def _canonical_person_name(value: Any) -> str | None:
    cleaned = clean_optional(value)
    if not cleaned:
        return None
    canonical = re.sub(
        r"^(?:the |a |that )?(?:girl|guy|person|woman|man)\s+",
        "",
        cleaned,
        flags=re.I,
    ).strip()
    canonical = re.sub(
        r"\s+(?:from|at)\s+(?:work|school|church|the gym|gym)$",
        "",
        canonical,
        flags=re.I,
    ).strip()
    if not canonical:
        return None
    normalized = normalize_key(canonical)
    if _is_descriptor_fragment(normalized):
        return None
    return canonical


def _person_descriptor_aliases(text: str) -> list[str]:
    aliases = []
    for alias, pattern in PERSON_DESCRIPTOR_ALIASES:
        if re.search(pattern, text, flags=re.I):
            aliases.append(alias)
    return aliases


def _is_descriptor_fragment(value: str) -> bool:
    return value in {
        "girl",
        "guy",
        "person",
        "woman",
        "man",
        "work",
        "from work",
        "at work",
        "school",
        "from school",
        "at school",
        "church",
        "from church",
        "gym",
        "from gym",
        "from the gym",
        "dating interest",
        "date",
        "coworker",
    }


def _entity_match_keys(
    entity: dict[str, Any],
    *,
    include_aliases: bool = True,
) -> set[str]:
    raw_values = [
        entity.get("normalized_name"),
        entity.get("display_name"),
    ]
    if include_aliases:
        raw_values.extend(entity.get("aliases", []))
    return {
        normalize_entity_name(value)
        for value in raw_values
        if clean_optional(value)
    }


def _entity_matches_payload(
    entity: dict[str, Any],
    payload: dict[str, Any],
    *,
    ignore_alias_matches: bool = False,
) -> bool:
    existing_keys = _entity_match_keys(
        entity,
        include_aliases=not ignore_alias_matches,
    )
    incoming_keys = _entity_match_keys(
        payload,
        include_aliases=not ignore_alias_matches,
    )
    return bool(existing_keys & incoming_keys)


def _correction_wrong_names(payload: dict[str, Any]) -> set[str]:
    metadata = payload.get("metadata") or {}
    values: list[Any] = []
    for key in ("wrong_names", "wrong_name", "old_names", "old_name"):
        raw_value = metadata.get(key)
        if isinstance(raw_value, list):
            values.extend(raw_value)
        elif raw_value:
            values.append(raw_value)

    person_correction = metadata.get("person_correction")
    if isinstance(person_correction, dict):
        raw_value = person_correction.get("wrong_names")
        if isinstance(raw_value, list):
            values.extend(raw_value)
        elif raw_value:
            values.append(raw_value)

    for field in ("source_content",):
        values.extend(_wrong_names_from_text(metadata.get(field)))
    for field in ("relationship", "summary"):
        values.extend(_wrong_names_from_text(payload.get(field)))

    return {
        normalize_entity_name(value)
        for value in values
        if _looks_like_wrong_name(value)
    }


def _wrong_names_from_text(value: Any) -> list[str]:
    text = clean_optional(value)
    if not text:
        return []

    values: list[str] = []
    for pattern in (
        r"\b(?:corrected|replacing)\s+from\s+([A-Za-z0-9 ,/]+?)(?:[.!?)]|$)",
        r"\bpreviously\s+(?:referenced\s+as|called|known\s+as)\s+([A-Za-z0-9 ,/]+?)(?:[.!?)]|$)",
    ):
        for match in re.finditer(pattern, text, flags=re.I):
            values.extend(_split_wrong_name_text(match.group(1)))

    correction_context = re.search(
        r"\b(?:name|person|correction|corrected|wrong|mistaken|referenced)\b",
        text,
        flags=re.I,
    )
    if correction_context:
        values.extend(
            match.group(1)
            for match in re.finditer(r"\bnot\s+([A-Za-z0-9]{1,32})\b", text, re.I)
        )

    return values


def _split_wrong_name_text(value: str) -> list[str]:
    return [
        token
        for token in re.split(r"\s*(?:,|/|\bor\b|\band\b)\s*", value)
        if token
    ]


def _looks_like_wrong_name(value: Any) -> bool:
    cleaned = clean_optional(value)
    if not cleaned:
        return False
    normalized = re.sub(r"[^a-z0-9]+", "", cleaned.casefold())
    if not normalized:
        return False
    return normalized not in {
        "a",
        "an",
        "as",
        "from",
        "name",
        "not",
        "or",
        "person",
        "previously",
        "referenced",
        "the",
    }


def _is_superseded_entity(entity: dict[str, Any], wrong_names: set[str]) -> bool:
    keys = _entity_match_keys(entity)
    if keys & wrong_names:
        return True

    normalized_name = _safe_normalize_entity_name(entity.get("normalized_name"))
    display_name = _safe_normalize_entity_name(entity.get("display_name"))
    if normalized_name in {"next week date", "date plan"} or display_name in {
        "next week date",
        "date plan",
    }:
        text = _safe_normalize_entity_name(
            " ".join(
                str(entity.get(field) or "")
                for field in ("relationship", "summary")
            )
        )
        return bool(set(text.split()) & wrong_names)

    return False


def _safe_normalize_entity_name(value: Any) -> str:
    if not clean_optional(value):
        return ""
    try:
        return normalize_entity_name(value)
    except EntityServiceError:
        return ""


def _dedupe_strings(values: list[str] | None) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values or []:
        cleaned = clean_optional(value)
        if not cleaned:
            continue
        key = cleaned.lower()
        if key in seen:
            continue
        seen.add(key)
        result.append(cleaned)
    return result


def clean_required(value: Any, field_name: str) -> str:
    cleaned = clean_optional(value)
    if not cleaned:
        raise EntityServiceError(f"{field_name} is required.", 422)
    return cleaned


def clean_optional(value: Any) -> str | None:
    if value is None:
        return None
    cleaned = re.sub(r"\s+", " ", str(value)).strip()
    return cleaned or None


def normalize_key(value: Any) -> str:
    cleaned = clean_required(value, "normalized_name").lower()
    normalized = re.sub(r"[^a-z0-9]+", " ", cleaned)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    if not normalized:
        raise EntityServiceError("normalized_name is required.", 422)
    return normalized


def normalize_entity_name(value: Any) -> str:
    normalized = normalize_key(value)
    stripped = _strip_entity_descriptors(normalized)
    return stripped or normalized


def dedupe_strings(values: list[str] | None) -> list[str]:
    return _dedupe_strings(values)


def merge_metadata(
    existing: dict[str, Any] | None, incoming: dict[str, Any] | None
) -> dict[str, Any]:
    return {**(existing or {}), **(incoming or {})}
