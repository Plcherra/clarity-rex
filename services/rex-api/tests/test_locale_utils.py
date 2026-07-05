from app.services.locale_utils import (
    locale_response_rule,
    locale_to_stt_code,
    locale_to_tts_code,
    normalize_locale,
)
from app.services.prompt_service import PromptService
from app.services.voice_stream_config import voice_response_instructions


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


def test_voice_response_instructions_include_locale_rule():
    instructions = voice_response_instructions("es")

    assert "Respond in Spanish" in instructions


def test_voice_response_instructions_warn_on_low_transcript_confidence():
    instructions = voice_response_instructions(
        "en",
        transcript_confidence=0.42,
    )

    assert "low speech recognition confidence" in instructions
    assert "Ask the user to repeat once" in instructions


def test_voice_response_instructions_skip_confidence_warning_when_high():
    instructions = voice_response_instructions(
        "en",
        transcript_confidence=0.91,
    )

    assert "low speech recognition confidence" not in instructions
