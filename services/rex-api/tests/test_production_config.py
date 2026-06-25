import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import app
import app.main as main_module


def test_production_validation_requires_core_release_config():
    settings = Settings(
        app_environment="production",
        grok_api_key=None,
        grok_model=None,
        supabase_url=None,
        supabase_anon_key=None,
        deepgram_api_key=None,
        _env_file=None,
    )

    errors = settings.production_validation_errors()

    assert "GROK_API_KEY" in errors
    assert "GROK_MODEL" in errors
    assert "SUPABASE_URL" in errors
    assert "SUPABASE_ANON_KEY" in errors
    assert "DEEPGRAM_API_KEY" in errors
    assert any("GOOGLE_TTS_PROJECT_ID" in error for error in errors)


def test_production_validation_rejects_experimental_rex_brain_routing():
    settings = Settings(
        app_environment="production",
        grok_api_key="grok-key",
        grok_model="grok-4.3",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="anon-key",
        deepgram_api_key="deepgram-key",
        google_tts_project_id="rex-project",
        google_tts_credentials_json='{"type":"service_account"}',
        rex_brain_routing_enabled=True,
        _env_file=None,
    )

    errors = settings.production_validation_errors()

    assert "REX_BRAIN_ROUTING_ENABLED must remain false in production" in errors


def test_production_validation_rejects_non_disabled_rollout_stage():
    settings = Settings(
        app_environment="production",
        grok_api_key="grok-key",
        grok_model="grok-4.3",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="anon-key",
        deepgram_api_key="deepgram-key",
        google_tts_project_id="rex-project",
        google_tts_credentials_json='{"type":"service_account"}',
        rex_brain_rollout_stage="analytical",
        _env_file=None,
    )

    errors = settings.production_validation_errors()

    assert "REX_BRAIN_ROLLOUT_STAGE must remain disabled in production" in errors


def test_development_skips_production_validation():
    settings = Settings(app_environment="development", _env_file=None)

    assert settings.production_validation_errors() == []


def test_production_lifespan_fails_when_required_config_is_missing(monkeypatch):
    monkeypatch.setattr(
        main_module,
        "get_settings",
        lambda: Settings(
            app_environment="production",
            grok_api_key=None,
            grok_model=None,
            supabase_url=None,
            supabase_anon_key=None,
            _env_file=None,
        ),
    )

    with pytest.raises(RuntimeError, match="Production configuration incomplete"):
        with TestClient(app):
            pass
