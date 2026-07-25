import pytest

from app.config import Settings
from app.services.usage_cost_estimator import (
    estimate_llm_cost_cents,
    estimate_tts_cost_cents,
    estimate_usage_cost_cents,
    resolve_tts_usage_provider,
)


def _settings(**overrides) -> Settings:
    return Settings(_env_file=None, **overrides)


def test_llm_cost_from_tokens():
    cost = estimate_usage_cost_cents(
        event_type="llm",
        unit_count=2000,
        settings=_settings(usage_grok_cents_per_1k_tokens=50),
    )
    assert cost == 100.0


def test_llm_cost_uses_input_output_split_when_available():
    cost = estimate_llm_cost_cents(
        prompt_tokens=1000,
        completion_tokens=500,
        total_tokens=1500,
        settings=_settings(
            usage_grok_input_cents_per_1k_tokens=0.125,
            usage_grok_output_cents_per_1k_tokens=0.25,
        ),
    )
    assert cost == pytest.approx(0.25)


def test_tts_cost_from_character_count():
    cost = estimate_tts_cost_cents(
        character_count=2000,
        duration_ms=60_000,
        settings=_settings(usage_tts_cents_per_1k_chars=1.6),
    )
    assert cost == pytest.approx(3.2)


def test_deepgram_tts_cost_uses_aura_rate():
    cost = estimate_tts_cost_cents(
        character_count=2000,
        duration_ms=60_000,
        provider="deepgram_tts",
        settings=_settings(
            usage_tts_cents_per_1k_chars=1.6,
            usage_deepgram_tts_cents_per_1k_chars=3.0,
        ),
    )
    assert cost == pytest.approx(6.0)


def test_deepgram_tts_cost_skips_duration_fallback():
    cost = estimate_tts_cost_cents(
        character_count=None,
        duration_ms=60_000,
        provider="deepgram_aura",
        settings=_settings(
            usage_tts_cents_per_minute=1.2,
            usage_deepgram_tts_cents_per_1k_chars=3.0,
        ),
    )
    assert cost is None


def test_resolve_tts_usage_provider_from_synthesis_metadata():
    assert (
        resolve_tts_usage_provider(
            synthesis={
                "voice_name": "aura-2-gloria-es",
                "metadata": {"vendor": "deepgram_aura"},
            }
        )
        == "deepgram_tts"
    )
    assert (
        resolve_tts_usage_provider(
            synthesis={
                "voice_name": "en-US-Neural2-J",
                "metadata": {"vendor": "google_tts"},
            }
        )
        == "google_tts"
    )
    assert resolve_tts_usage_provider(voice_name="aura-2-gloria-es") == "deepgram_tts"


def test_stt_cost_from_duration():
    cost = estimate_usage_cost_cents(
        event_type="stt",
        duration_ms=120_000,
        settings=_settings(usage_deepgram_cents_per_minute=4.5),
    )
    assert cost == 9.0


def test_zero_rate_returns_none():
    cost = estimate_usage_cost_cents(
        event_type="llm",
        unit_count=500,
        settings=_settings(
            usage_grok_cents_per_1k_tokens=0,
            usage_grok_input_cents_per_1k_tokens=0,
            usage_grok_output_cents_per_1k_tokens=0,
        ),
    )
    assert cost is None
