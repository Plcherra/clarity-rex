from app.services.locale_utils import (
    locale_response_rule,
    locale_to_stt_code,
    locale_to_tts_code,
    normalize_locale,
)
from app.services.prompt_service import PromptService


def test_normalize_locale_strips_region():
    assert normalize_locale("es-MX") == "es"
    assert normalize_locale("  en-US  ") == "en"
    assert normalize_locale("") is None
    assert normalize_locale(None) is None


def test_locale_to_stt_and_tts_codes():
    assert locale_to_stt_code("es") == "es-US"
    assert locale_to_tts_code("en") == "en-US"
    assert locale_to_stt_code(None) == "en-US"


def test_prompt_service_includes_locale_rule_when_set():
    service = PromptService()

    messages = service.build_messages(user_message="Hello", locale="es")

    assert any("Respond in Spanish" in message["content"] for message in messages)
