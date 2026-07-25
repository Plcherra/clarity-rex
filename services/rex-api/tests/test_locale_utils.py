from app.services.locale_utils import (
    locale_response_rule,
    locale_to_stt_code,
    locale_to_tts_code,
    locale_to_tts_voice_name,
    normalize_locale,
    tts_voice_name_for_language_code,
)
from app.services.prompt_service import PromptService


def test_normalize_locale_strips_region():
    assert normalize_locale("es-MX") == "es"
    assert normalize_locale("  en-US  ") == "en"
    assert normalize_locale("") is None
    assert normalize_locale(None) is None


def test_locale_to_stt_and_tts_codes():
    assert locale_to_stt_code("es") == "es"
    assert locale_to_tts_code("en") == "en-US"
    assert locale_to_stt_code(None) == "en-US"
    assert locale_to_tts_code("es") == "es"


def test_spanish_tts_uses_aura_gloria_not_english_default():
    assert (
        locale_to_tts_voice_name("es", default_voice="en-US-Neural2-J")
        == "aura-2-gloria-es"
    )
    assert (
        tts_voice_name_for_language_code(
            "es",
            default_voice="en-US-Neural2-J",
        )
        == "aura-2-gloria-es"
    )


def test_english_tts_keeps_configured_default_voice():
    assert (
        locale_to_tts_voice_name("en", default_voice="en-US-Neural2-D")
        == "en-US-Neural2-D"
    )
    assert (
        tts_voice_name_for_language_code(
            "en-US",
            default_voice="en-US-Neural2-D",
        )
        == "en-US-Neural2-D"
    )


def test_prompt_service_includes_locale_rule_when_set():
    service = PromptService()

    messages = service.build_messages(user_message="Hello", locale="es")

    assert any("Respond in Spanish" in message["content"] for message in messages)
