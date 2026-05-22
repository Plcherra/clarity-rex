import pytest
from fastapi import HTTPException

from app.auth import supabase_auth
from app.auth.supabase_auth import authenticate_access_token
from app.config import Settings


class FakeSupabaseUserResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self._payload


@pytest.mark.asyncio
async def test_auth_uses_development_user_when_supabase_is_not_configured():
    user = await authenticate_access_token(
        None,
        Settings(app_environment="development", _env_file=None),
    )

    assert user.id == "00000000-0000-0000-0000-000000000000"
    assert user.access_token == "development-token"


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

