from fastapi.testclient import TestClient

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.config import Settings
from app.main import app
import app.main as main_module


def test_public_ready_returns_status_only():
    response = TestClient(app).get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "clarity-rex"}


def test_ready_details_requires_auth(monkeypatch):
    from fastapi import HTTPException, status

    def deny_user():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Supabase access token.",
        )

    app.dependency_overrides[get_current_user] = deny_user
    try:
        response = TestClient(app).get("/ready/details")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 401


def test_ready_details_reports_config_for_authenticated_user(monkeypatch):
    monkeypatch.setattr(
        main_module,
        "settings",
        Settings(
            app_environment="development",
            grok_api_key="grok-key",
            grok_model="grok-4.3",
            grok_fast_model="grok-fast",
            grok_standard_model="grok-standard",
            grok_reasoning_model="grok-reasoning",
            supabase_url=None,
            supabase_anon_key=None,
            deepgram_api_key="deepgram-key",
            google_tts_project_id="rex-project",
            google_tts_credentials_json='{"type":"service_account"}',
            plaid_client_id="",
            plaid_secret="",
            google_tts_voice_name="en-US-Neural2-J",
            google_tts_speaking_rate=1.15,
            _env_file=None,
        ),
    )

    response = TestClient(app).get("/ready/details")
    assert response.status_code == 200
    payload = response.json()
    assert payload["service"] == "clarity-rex"
    assert payload["checks"]["assistant_pipeline"]["mode"] == "simple"
    assert payload["checks"]["plaid"]["required_for_ready"] is False
    assert "PLAID_SECRET" in payload["checks"]["plaid"]["required"]
    assert payload["checks"]["deepgram"]["configured"] is True
    assert payload["checks"]["google_tts"]["configured"] is True


def test_ready_details_requires_plaid_in_production(monkeypatch):
    monkeypatch.setattr(
        main_module,
        "settings",
        Settings(
            app_environment="production",
            grok_api_key="grok-key",
            grok_model="grok-4.3",
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            supabase_service_role_key="service-key",
            deepgram_api_key="deepgram-key",
            google_tts_project_id="rex-project",
            google_tts_credentials_json='{"type":"service_account"}',
            plaid_client_id="",
            plaid_secret="",
            _env_file=None,
        ),
    )

    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id="user-1",
        email=None,
        access_token="token",
    )
    try:
        response = TestClient(app).get("/ready/details")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    payload = response.json()
    assert payload["checks"]["plaid"]["required_for_ready"] is True
    assert payload["status"] == "degraded"
