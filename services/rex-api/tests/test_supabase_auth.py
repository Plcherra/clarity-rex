import pytest
from fastapi import HTTPException
from types import SimpleNamespace

from app.auth import supabase_auth
from app.auth.supabase_auth import authenticate_access_token, authenticate_websocket
from app.config import Settings


class FakeSupabaseUserResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self._payload


@pytest.mark.asyncio
async def test_auth_rejects_dev_fallback_in_production_when_supabase_is_not_configured():
    with pytest.raises(HTTPException) as exc:
        await authenticate_access_token(
            None,
            Settings(app_environment="production", _env_file=None),
        )

    assert exc.value.status_code == 503
    assert exc.value.detail == "Supabase auth is not configured."


@pytest.mark.asyncio
async def test_auth_rejects_dev_fallback_for_unknown_environment():
    """Typos like 'prod' must fail closed — never mint the fixed fake user."""
    with pytest.raises(HTTPException) as exc:
        await authenticate_access_token(
            None,
            Settings(app_environment="prod", _env_file=None),
        )

    assert exc.value.status_code == 503
    assert exc.value.detail == "Supabase auth is not configured."


@pytest.mark.asyncio
async def test_auth_uses_development_user_when_supabase_is_not_configured():
    user = await authenticate_access_token(
        None,
        Settings(app_environment="development", _env_file=None),
    )

    assert user.id == "00000000-0000-0000-0000-000000000000"
    assert user.access_token == "development-token"


@pytest.mark.asyncio
async def test_auth_development_bypass_is_case_insensitive():
    user = await authenticate_access_token(
        None,
        Settings(app_environment="Development", _env_file=None),
    )

    assert user.id == "00000000-0000-0000-0000-000000000000"


@pytest.mark.asyncio
async def test_auth_rejects_missing_token_when_supabase_is_configured():
    with pytest.raises(HTTPException) as exc:
        await authenticate_access_token(
            None,
            Settings(
                supabase_url="https://example.supabase.co",
                supabase_anon_key="anon-key",
                _env_file=None,
            ),
        )

    assert exc.value.status_code == 401
    assert exc.value.detail == "Missing Supabase access token."


@pytest.mark.asyncio
async def test_auth_validates_token_with_supabase_user_endpoint(monkeypatch):
    calls = []

    async def fake_request(method, url, headers=None, **kwargs):
        calls.append({"method": method, "url": url, "headers": headers})
        return FakeSupabaseUserResponse(
            {
                "id": "user-123",
                "email": "person@example.com",
            }
        )

    monkeypatch.setattr(supabase_auth, "request_with_retries", fake_request)

    user = await authenticate_access_token(
        "access-token",
        Settings(
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            _env_file=None,
        ),
    )

    assert user.id == "user-123"
    assert user.email == "person@example.com"
    assert user.access_token == "access-token"
    assert calls == [
        {
            "method": "GET",
            "url": "https://example.supabase.co/auth/v1/user",
            "headers": {
                "apikey": "anon-key",
                "Authorization": "Bearer access-token",
                "Accept": "application/json",
            },
        }
    ]


@pytest.mark.asyncio
async def test_websocket_auth_uses_bearer_header_instead_of_query_param(
    monkeypatch,
):
    calls = []

    async def fake_request(method, url, headers=None, **kwargs):
        calls.append({"method": method, "url": url, "headers": headers})
        return FakeSupabaseUserResponse(
            {
                "id": "user-123",
                "email": "person@example.com",
            }
        )

    monkeypatch.setattr(supabase_auth, "request_with_retries", fake_request)
    websocket = SimpleNamespace(
        headers={"authorization": "Bearer header-token"},
        query_params={"access_token": "query-token"},
    )

    user = await authenticate_websocket(
        websocket,
        settings=Settings(
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            _env_file=None,
        ),
    )

    assert user.id == "user-123"
    assert user.access_token == "header-token"
    assert calls[0]["headers"]["Authorization"] == "Bearer header-token"


@pytest.mark.asyncio
async def test_websocket_auth_accepts_query_param_when_header_missing(
    monkeypatch,
):
    calls = []

    async def fake_request(method, url, headers=None, **kwargs):
        calls.append({"method": method, "url": url, "headers": headers})
        return FakeSupabaseUserResponse(
            {
                "id": "user-123",
                "email": "person@example.com",
            }
        )

    monkeypatch.setattr(supabase_auth, "request_with_retries", fake_request)
    websocket = SimpleNamespace(
        headers={},
        query_params={"access_token": "query-token"},
    )

    user = await authenticate_websocket(
        websocket,
        settings=Settings(
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            _env_file=None,
        ),
    )

    assert user.id == "user-123"
    assert user.access_token == "query-token"
    assert calls[0]["headers"]["Authorization"] == "Bearer query-token"
