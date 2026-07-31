from app.services.locale_registry import (
    LOCALE_REGISTRY,
    resolve_locale_tag,
)
from app.services.locale_utils import locale_to_stt_code, locale_to_tts_code


def test_registry_includes_planned_locales():
    tags = {spec.tag for spec in LOCALE_REGISTRY}
    assert tags == {"en", "es", "pt-BR", "pt-PT", "fr"}


def test_only_english_and_spanish_enabled_by_default():
    enabled = [spec.tag for spec in LOCALE_REGISTRY if spec.enabled]
    assert enabled == ["en", "es"]


def test_resolve_region_aware_portuguese():
    assert resolve_locale_tag("pt-BR").stt_code == "pt-BR"
    assert resolve_locale_tag("pt-PT").stt_code == "pt-PT"
    assert resolve_locale_tag("pt-br").tts_code == "pt-BR"


def test_resolve_language_only_portuguese_defaults_to_brazil():
    assert resolve_locale_tag("pt").stt_code == "pt-BR"


def test_resolve_regional_spanish_falls_back_to_language_spec():
    spec = resolve_locale_tag("es-MX")
    assert spec.tag == "es"
    assert spec.prompt_label == "Spanish"
    # Spanish voice runs on Deepgram Aura-2, which takes the bare language code.
    assert spec.stt_code == "es"
    assert spec.tts_code == "es"


def test_resolve_unknown_locale_falls_back_to_english():
    spec = resolve_locale_tag("de-DE")
    assert spec.tag == "en"
    assert spec.stt_code == "en-US"


def test_locale_to_stt_and_tts_use_registry():
    assert locale_to_stt_code("pt-BR") == "pt-BR"
    assert locale_to_tts_code("pt-PT") == "pt-PT"
    assert locale_to_stt_code(None) == "en-US"
