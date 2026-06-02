import pytest

import app.services.supabase_memory_transport as transport_module
from app.config import Settings
from app.services.memory_service import SupabaseMemoryService


class FakeSupabaseRestResponse:
    text = '[{"id":"record-1"}]'

    def raise_for_status(self):
        return None


@pytest.mark.asyncio
async def test_memory_service_uses_user_token_and_scopes_reads(monkeypatch):
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
        return FakeSupabaseRestResponse()

    monkeypatch.setattr(transport_module, "request_with_retries", fake_request)
    service = SupabaseMemoryService(
        settings=Settings(
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            supabase_service_role_key="service-key",
            _env_file=None,
        ),
        user_id="user-123",
        access_token="access-token",
    )

    await service._request(
        "GET",
        "conversations",
        query={"select": "id,title", "limit": "10"},
    )

    assert calls[0]["headers"]["apikey"] == "anon-key"
    assert calls[0]["headers"]["Authorization"] == "Bearer access-token"
    assert "user_id=eq.user-123" in calls[0]["url"]


@pytest.mark.asyncio
async def test_memory_service_attaches_user_id_to_inserts(monkeypatch):
    calls = []

    async def fake_request(method, url, headers=None, json=None):
        calls.append({"method": method, "url": url, "json": json})
        return FakeSupabaseRestResponse()

    monkeypatch.setattr(transport_module, "request_with_retries", fake_request)
    service = SupabaseMemoryService(
        settings=Settings(
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            supabase_service_role_key="service-key",
            _env_file=None,
        ),
        user_id="user-123",
        access_token="access-token",
    )

    await service._request(
        "POST",
        "conversations",
        body={"title": "Planning"},
        query={"select": "id,title"},
        prefer="return=representation",
    )

    assert calls[0]["json"] == {
        "title": "Planning",
        "user_id": "user-123",
    }
    assert "user_id=eq.user-123" not in calls[0]["url"]


@pytest.mark.asyncio
async def test_memory_service_overrides_untrusted_user_id_on_inserts(monkeypatch):
    calls = []

    async def fake_request(method, url, headers=None, json=None):
        calls.append({"method": method, "url": url, "json": json})
        return FakeSupabaseRestResponse()

    monkeypatch.setattr(transport_module, "request_with_retries", fake_request)
    service = SupabaseMemoryService(
        settings=Settings(
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            supabase_service_role_key="service-key",
            _env_file=None,
        ),
        user_id="user-123",
        access_token="access-token",
    )

    await service._request(
        "POST",
        "entities",
        body={
            "id": "client-picked-id",
            "user_id": "attacker-user",
            "display_name": "Clara",
            "created_at": "2026-01-01T00:00:00Z",
        },
    )

    assert calls[0]["json"] == {
        "display_name": "Clara",
        "user_id": "user-123",
    }


@pytest.mark.asyncio
async def test_memory_service_strips_protected_fields_on_updates(monkeypatch):
    calls = []

    async def fake_request(method, url, headers=None, json=None):
        calls.append({"method": method, "url": url, "json": json})
        return FakeSupabaseRestResponse()

    monkeypatch.setattr(transport_module, "request_with_retries", fake_request)
    service = SupabaseMemoryService(
        settings=Settings(
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            supabase_service_role_key="service-key",
            _env_file=None,
        ),
        user_id="user-123",
        access_token="access-token",
    )

    await service._update_record(
        "entities",
        "entity-1",
        updates={
            "user_id": "attacker-user",
            "updated_at": "2026-01-01T00:00:00Z",
            "display_name": "Clara",
        },
        select="id,display_name",
        empty_detail="No fields.",
    )

    assert calls[0]["json"] == {"display_name": "Clara"}
    assert "id=eq.entity-1" in calls[0]["url"]
    assert "user_id=eq.user-123" in calls[0]["url"]
