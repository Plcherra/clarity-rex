from __future__ import annotations

from typing import Optional

from app.services.locale_registry import LOCALE_REGISTRY, resolve_locale_tag


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


def locale_to_tts_voice_name(
    locale: Optional[str],
    *,
    default_voice: str,
) -> str:
    """Pick a Google TTS voice that matches the locale language.

    English keeps [default_voice] so prod can override via GOOGLE_TTS_VOICE_NAME.
    Other languages use the registry voice — never an English name with a
    non-English languageCode (Google rejects that mismatch).
    """
    spec = resolve_locale_tag(locale)
    if spec.language == "en":
        return default_voice or spec.tts_voice_name
    return spec.tts_voice_name


def tts_voice_name_for_language_code(
    language_code: Optional[str],
    *,
    default_voice: str,
) -> str:
    """Resolve voice name from a BCP-47 TTS language code (e.g. es-US)."""
    code = str(language_code or "").strip()
    if not code:
        return default_voice
    configured = str(default_voice or "").strip()
    if configured.startswith(code):
        return configured
    for spec in LOCALE_REGISTRY:
        if spec.tts_code.lower() == code.lower():
            if spec.language == "en":
                return configured or spec.tts_voice_name
            return spec.tts_voice_name
    language = code.split("-", 1)[0].lower()
    for spec in LOCALE_REGISTRY:
        if spec.language == language:
            if spec.language == "en":
                return configured or spec.tts_voice_name
            return spec.tts_voice_name
    return configured


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
