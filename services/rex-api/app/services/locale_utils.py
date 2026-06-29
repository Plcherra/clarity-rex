from __future__ import annotations

from typing import Optional

_LOCALE_LANGUAGE_LABELS = {
    "en": "English",
    "es": "Spanish",
}

_STT_CODES = {
    "en": "en-US",
    "es": "es-US",
}

_TTS_CODES = {
    "en": "en-US",
    "es": "es-US",
}


def normalize_locale(locale: Optional[str]) -> Optional[str]:
    if locale is None:
        return None
    normalized = str(locale).strip()
    if not normalized:
        return None
    return normalized.split("-")[0].lower()


def locale_to_stt_code(locale: Optional[str]) -> str:
    language = normalize_locale(locale) or "en"
    return _STT_CODES.get(language, "en-US")


def locale_to_tts_code(locale: Optional[str]) -> str:
    language = normalize_locale(locale) or "en"
    return _TTS_CODES.get(language, "en-US")


def locale_response_rule(locale: Optional[str]) -> Optional[str]:
    language = normalize_locale(locale)
    if not language:
        return None
    label = _LOCALE_LANGUAGE_LABELS.get(language, language)
    return (
        f"App language locale: {language}. Respond in {label} when answering the user, "
        "unless the user's message clearly uses a different language."
    )
