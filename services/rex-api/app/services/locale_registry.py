from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

DEFAULT_LOCALE_TAG = "en"


@dataclass(frozen=True)
class LocaleSpec:
    """One supported Rex locale with prompt and voice provider codes."""

    tag: str
    language: str
    prompt_label: str
    stt_code: str
    tts_code: str
    enabled: bool = False


LOCALE_REGISTRY: tuple[LocaleSpec, ...] = (
    LocaleSpec(
        tag="en",
        language="en",
        prompt_label="English",
        stt_code="en-US",
        tts_code="en-US",
        enabled=True,
    ),
    LocaleSpec(
        tag="es",
        language="es",
        prompt_label="Spanish",
        stt_code="es-US",
        tts_code="es-US",
        enabled=True,
    ),
    LocaleSpec(
        tag="pt-BR",
        language="pt",
        prompt_label="Portuguese (Brazil)",
        stt_code="pt-BR",
        tts_code="pt-BR",
    ),
    LocaleSpec(
        tag="pt-PT",
        language="pt",
        prompt_label="Portuguese (Portugal)",
        stt_code="pt-PT",
        tts_code="pt-PT",
    ),
    LocaleSpec(
        tag="fr",
        language="fr",
        prompt_label="French",
        stt_code="fr-FR",
        tts_code="fr-FR",
    ),
)

_BY_TAG: dict[str, LocaleSpec] = {
    spec.tag.lower(): spec for spec in LOCALE_REGISTRY
}


def parse_locale_tag(raw: Optional[str]) -> tuple[str, Optional[str]]:
    if raw is None:
        return DEFAULT_LOCALE_TAG, None
    normalized = str(raw).strip()
    if not normalized:
        return DEFAULT_LOCALE_TAG, None
    parts = normalized.replace("_", "-").split("-")
    language = parts[0].lower()
    region = parts[1].upper() if len(parts) >= 2 and parts[1] else None
    return language, region


def canonical_tag(language: str, region: Optional[str]) -> str:
    if region:
        return f"{language}-{region}"
    return language


def resolve_locale_tag(locale: Optional[str]) -> LocaleSpec:
    """Resolve a BCP-47 tag to a registry spec with safe English fallback."""
    language, region = parse_locale_tag(locale)

    if region:
        regional = canonical_tag(language, region)
        spec = _BY_TAG.get(regional.lower())
        if spec is not None:
            return spec

    language_only = _BY_TAG.get(language)
    if language_only is not None:
        return language_only

    for candidate in LOCALE_REGISTRY:
        if candidate.language == language and "-" not in candidate.tag:
            return candidate

    if language == "pt":
        return _BY_TAG["pt-br"]

    return _BY_TAG[DEFAULT_LOCALE_TAG]
