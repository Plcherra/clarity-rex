from __future__ import annotations

from typing import Optional

from app.services.locale_registry import resolve_locale_tag


def normalize_locale(locale: Optional[str]) -> Optional[str]:
    """Return the language subtag only (legacy helper for language-level checks)."""
    if locale is None:
        return None
    normalized = str(locale).strip()
    if not normalized:
        return None
    return normalized.replace("_", "-").split("-")[0].lower()


def locale_to_stt_code(locale: Optional[str]) -> str:
    return resolve_locale_tag(locale).stt_code


def locale_to_tts_code(locale: Optional[str]) -> str:
    return resolve_locale_tag(locale).tts_code


def locale_response_rule(locale: Optional[str]) -> Optional[str]:
    if locale is None:
        return None
    normalized = str(locale).strip()
    if not normalized:
        return None
    spec = resolve_locale_tag(normalized)
    return (
        f"App language locale: {spec.language}. Respond in {spec.prompt_label} when answering the user, "
        "unless the user's message clearly uses a different language."
    )
