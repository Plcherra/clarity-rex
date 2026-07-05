import pytest

import app.services.usage_tracking_service as usage_module
import app.services.usage_tracking_transport as usage_transport_module
from app.config import Settings
from app.models.usage_tracking import (
    UsageTrackingEvent,
    UsageTrackingValidationError,
)
from app.services.usage_tracking_service import UsageTrackingService


class FakeResponse:
    text = ""

    def raise_for_status(self):
        return None

    def json(self):
        return []


def _settings() -> Settings:
    return Settings(
        supabase_url="https://example.supabase.co",
        supabase_service_role_key="service-key",
        _env_file=None,
    )


def test_event_validation_fails_without_user_id():
    event = UsageTrackingEvent(
        user_id="",
        event_type="llm",
    )

    with pytest.raises(UsageTrackingValidationError):
        event.to_insert_payload()


@pytest.mark.asyncio
async def test_record_event_uses_service_role_insert(monkeypatch):
    calls = []

    async def fake_request(method, url, headers=None, json=None):
        calls.append(
            {
                "method": method,
                "url": url,
                "headers": headers,
                "json": json,
            }
        )
        return FakeResponse()

    monkeypatch.setattr(usage_transport_module, "request_with_retries", fake_request)
    settings = _settings()
    settings.usage_grok_cents_per_1k_tokens = 50
    settings.usage_grok_input_cents_per_1k_tokens = 0
    settings.usage_grok_output_cents_per_1k_tokens = 0
    service = UsageTrackingService(settings=settings)

    ok = await service.record_llm_turn(
        user_id="00000000-0000-0000-0000-000000000001",
        surface="assistant",
        channel="voice",
        model="grok-4.3",
        latency_ms=1200,
        token_count=450,
    )

    assert ok is True
    assert calls[0]["method"] == "POST"
    assert calls[0]["url"] == "https://example.supabase.co/rest/v1/user_usage_events"
    assert calls[0]["headers"]["apikey"] == "service-key"
    assert calls[0]["headers"]["Authorization"] == "Bearer service-key"
    assert calls[0]["json"]["event_type"] == "llm"
    assert calls[0]["json"]["provider"] == "grok"
    assert calls[0]["json"]["unit_count"] == 450.0
    assert calls[0]["json"]["estimated_cost_cents"] == 22.5
    assert "metadata" not in calls[0]["json"]


@pytest.mark.asyncio
async def test_record_event_fails_quietly_on_rejected_event_type(monkeypatch):
    calls = []

    async def fake_request(method, url, headers=None, json=None):
        calls.append(json)
        return FakeResponse()

    monkeypatch.setattr(usage_transport_module, "request_with_retries", fake_request)
    service = UsageTrackingService(settings=_settings())

    ok = await service.record_event(
        user_id="00000000-0000-0000-0000-000000000001",
        event_type="bad_event",
    )

    assert ok is False
    assert calls == []


@pytest.mark.asyncio
async def test_user_voice_usage_summarizes_today_week_and_month(monkeypatch):
    async def fake_request(method, url, headers=None, json=None):
        assert method == "GET"
        assert "owner_usage_daily" in url
        assert "usage_date=gte.2026-06-01" in url
        assert "user_id=eq.user-1" in url
        response = FakeResponse()
        response.json = lambda: [
            {
                "user_id": "user-1",
                "usage_date": "2026-06-06",
                "voice_seconds": 60,
                "llm_calls": 2,
                "chat_llm_calls": 1,
                "voice_llm_calls": 1,
                "stt_seconds": 55,
                "tts_seconds": 20,
                "estimated_cost_cents": 12.5,
            },
            {
                "user_id": "user-1",
                "usage_date": "2026-06-03",
                "voice_seconds": 120,
                "llm_calls": 3,
                "stt_seconds": 110,
                "tts_seconds": 30,
            },
        ]
        return response

    monkeypatch.setattr(usage_transport_module, "request_with_retries", fake_request)
    service = UsageTrackingService(settings=_settings())

    totals = await service.get_user_voice_usage(
        user_id="user-1",
        today=usage_module.date(2026, 6, 6),
    )

    assert totals["today_voice_seconds"] == 60
    assert totals["week_voice_seconds"] == 180
    assert totals["month_voice_seconds"] == 180
    assert totals["today_llm_calls"] == 2
    assert totals["week_llm_calls"] == 5
    assert totals["month_llm_calls"] == 5
    assert totals["today_stt_seconds"] == 55
    assert totals["week_stt_seconds"] == 165
    assert totals["month_stt_seconds"] == 165
    assert totals["today_tts_seconds"] == 20
    assert totals["week_tts_seconds"] == 50
    assert totals["month_tts_seconds"] == 50


@pytest.mark.asyncio
async def test_owner_usage_allows_configured_owner_without_client_secret(monkeypatch):
    calls = []

    async def fake_request(method, url, headers=None, json=None):
        calls.append(url)
        response = FakeResponse()
        response.json = lambda: [
            {
                "user_id": "user-1",
                "usage_date": "2026-06-06",
                "voice_seconds": 60,
                "llm_calls": 2,
                "chat_llm_calls": 1,
                "voice_llm_calls": 1,
                "stt_seconds": 55,
                "tts_seconds": 20,
                "estimated_cost_cents": 12.5,
            }
        ]
        return response

    monkeypatch.setattr(usage_transport_module, "request_with_retries", fake_request)
    settings = _settings()
    settings.usage_owner_user_id = "owner-1"
    service = UsageTrackingService(settings=settings)

    result = await service.get_owner_usage(
        requester_user_id="owner-1",
        today=usage_module.date(2026, 6, 6),
    )

    assert result["authorized"] is True
    assert result["users"][0]["user_id"] == "user-1"
    assert "admin_users" not in "".join(calls)


@pytest.mark.asyncio
async def test_owner_usage_allowlist_requires_owner_or_admin_role(monkeypatch):
    calls = []

    async def fake_request(method, url, headers=None, json=None):
        calls.append(url)
        response = FakeResponse()
        response.json = lambda: []
        return response

    monkeypatch.setattr(usage_transport_module, "request_with_retries", fake_request)
    service = UsageTrackingService(settings=_settings())

    result = await service.get_owner_usage(
        requester_user_id="support-1",
        today=usage_module.date(2026, 6, 6),
    )

    assert result == {"authorized": False, "users": []}
    assert "admin_users" in calls[0]
    assert "role=in.%28owner%2Cadmin%29" in calls[0]


@pytest.mark.asyncio
async def test_owner_user_daily_uses_postgrest_and_date_filter(monkeypatch):
    calls = []

    async def fake_request(method, url, headers=None, json=None):
        calls.append(url)
        response = FakeResponse()
        response.json = lambda: [
            {
                "user_id": "user-1",
                "usage_date": "2026-06-06",
                "voice_seconds": 60,
                "llm_calls": 2,
                "estimated_cost_cents": 12.5,
            }
        ]
        return response

    monkeypatch.setattr(usage_transport_module, "request_with_retries", fake_request)
    settings = _settings()
    settings.usage_owner_user_id = "owner-1"
    service = UsageTrackingService(settings=settings)

    result = await service.get_owner_user_daily(
        requester_user_id="owner-1",
        user_id="user-1",
        start_date=usage_module.date(2026, 6, 1),
        end_date=usage_module.date(2026, 6, 6),
    )

    assert result["authorized"] is True
    assert len(result["daily"]) == 1
    assert "usage_date.gte.2026-06-01" in calls[0]
    assert "usage_date.lte.2026-06-06" in calls[0]
    assert "user_id=eq.user-1" in calls[0]


@pytest.mark.asyncio
async def test_tracking_failure_does_not_raise(monkeypatch):
    async def fake_request(method, url, headers=None, json=None):
        raise TimeoutError("network down")

    monkeypatch.setattr(usage_transport_module, "request_with_retries", fake_request)
    service = UsageTrackingService(settings=_settings())

    ok = await service.record_voice_session(
        user_id="00000000-0000-0000-0000-000000000001",
        duration_ms=60_000,
    )

    assert ok is False
