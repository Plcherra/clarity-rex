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
        supabase_service_role_key=None,
        deepgram_api_key=None,
        _env_file=None,
    )

    errors = settings.production_validation_errors()

    assert "GROK_API_KEY" in errors
    assert "GROK_MODEL" in errors
    assert "SUPABASE_URL" in errors
    assert "SUPABASE_ANON_KEY" in errors
    assert "SUPABASE_SERVICE_ROLE_KEY" in errors
    assert "DEEPGRAM_API_KEY" in errors
    assert any("GOOGLE_TTS_PROJECT_ID" in error for error in errors)


def test_production_validation_requires_plaid_encryption_when_plaid_present():
    settings = Settings(
        app_environment="production",
        grok_api_key="k",
        grok_model="m",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="anon",
        supabase_service_role_key="service",
        deepgram_api_key="dg",
        google_tts_project_id="p",
        google_tts_credentials_json="{}",
        plaid_client_id="client",
        plaid_secret="secret",
        plaid_token_encryption_secret=None,
        _env_file=None,
    )

    errors = settings.production_validation_errors()
    assert "PLAID_TOKEN_ENCRYPTION_SECRET" in errors


def test_development_skips_production_validation():
    settings = Settings(app_environment="development", _env_file=None)

    assert settings.production_validation_errors() == []


def test_unknown_app_environment_rejected_at_startup():
    settings = Settings(app_environment="prod", _env_file=None)

    errors = settings.environment_validation_errors()
    assert len(errors) == 1
    assert "APP_ENVIRONMENT" in errors[0]
    assert "prod" in errors[0]
    assert settings.startup_validation_errors() == errors
    assert settings.allows_unauthenticated_dev_user is False


def test_production_environment_is_recognized_case_insensitively():
    settings = Settings(app_environment="Production", _env_file=None)

    assert settings.is_production is True
    assert settings.environment_validation_errors() == []
    assert settings.allows_unauthenticated_dev_user is False


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

    with pytest.raises(RuntimeError, match="Startup configuration invalid"):
        with TestClient(app):
            pass


def test_lifespan_fails_on_unknown_app_environment(monkeypatch):
    monkeypatch.setattr(
        main_module,
        "get_settings",
        lambda: Settings(app_environment="staging", _env_file=None),
    )

    with pytest.raises(RuntimeError, match="APP_ENVIRONMENT"):
        with TestClient(app):
            pass