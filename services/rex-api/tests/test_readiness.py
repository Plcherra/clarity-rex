from fastapi.testclient import TestClient

from app.config import Settings
from app.main import app
import app.main as main_module


def test_readiness_reports_missing_cloud_voice_config(monkeypatch):
    monkeypatch.setattr(
        main_module,
        "settings",
        Settings(
            grok_api_key="grok-key",
            grok_model="grok-4.3",
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            supabase_service_role_key="service-key",
            deepgram_api_key=None,
            google_tts_project_id=None,
        ),
    )

    response = TestClient(app).get("/ready")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "degraded"
    assert payload["checks"]["grok"]["configured"] is True
    assert payload["checks"]["supabase"]["configured"] is True
    assert payload["checks"]["deepgram"]["configured"] is False
    assert payload["checks"]["google_tts"]["configured"] is False
    assert payload["checks"]["rex_brain"]["configured"] is True
    assert payload["checks"]["rex_brain"]["routing_enabled"] is False
    assert payload["checks"]["time"]["timezone"] == "America/New_York"
    assert "DEEPGRAM_API_KEY" in payload["checks"]["deepgram"]["required"]


def test_readiness_reports_ready_when_all_required_services_are_configured(monkeypatch):
    monkeypatch.setattr(
        main_module,
        "settings",
        Settings(
            grok_api_key="grok-key",
            grok_model="grok-4.3",
            grok_fast_model="grok-fast",
            grok_standard_model="grok-standard",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_debug_enabled=True,
            rex_brain_rollout_stage="analytical",
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            supabase_service_role_key="service-key",
            deepgram_api_key="deepgram-key",
            google_tts_project_id="rex-project",
            google_tts_credentials_json='{"type":"service_account"}',
        ),
    )

    response = TestClient(app).get("/ready")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ready"
    assert payload["service"] == "clarity-rex"
    assert payload["systemd_unit"] == "clarity-rex.service"
    assert payload["checks"]["deepgram"]["configured"] is True
    assert payload["checks"]["deepgram"]["model"] == "nova-3"
    assert payload["checks"]["google_tts"]["configured"] is True
    assert payload["checks"]["google_tts"]["audio_encoding"] == "MP3"
    assert payload["checks"]["rex_brain"] == {
        "configured": True,
        "routing_enabled": True,
        "debug_enabled": True,
        "fast_first_enabled": False,
        "rollout_stage": "analytical",
        "rollout_stages": [
            "disabled",
            "logging_only",
            "fast_contextual",
            "analytical",
            "strategic_reflective",
            "deep_think_ui",
        ],
        "models": {
            "fallback": "grok-4.3",
            "fast": "grok-fast",
            "standard": "grok-standard",
            "reasoning": "grok-reasoning",
        },
    }
    assert payload["checks"]["time"]["configured"] is True
