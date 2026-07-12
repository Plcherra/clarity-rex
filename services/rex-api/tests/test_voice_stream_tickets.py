"""Tests for short-lived voice stream tickets."""

import pytest
from fastapi import HTTPException
from types import SimpleNamespace

from app.auth.supabase_auth import authenticate_websocket
from app.config import Settings
from app.services.voice_stream_ticket_store import VoiceStreamTicketStore


def test_ticket_is_single_use_and_expires_conceptually():
    store = VoiceStreamTicketStore(ttl_seconds=60)
    ticket, expires_in = store.issue(
        user_id="user-1",
        access_token="user-jwt",
        email="a@example.com",
    )
    assert expires_in == 60
    peeked = store.peek(ticket)
    assert peeked is not None
    assert peeked.access_token == "user-jwt"
    consumed = store.consume(ticket)
    assert consumed is not None
    assert consumed.user_id == "user-1"
    assert store.consume(ticket) is None
    assert store.peek(ticket) is None


@pytest.mark.asyncio
async def test_websocket_auth_accepts_valid_ticket(monkeypatch):
    from app.auth import supabase_auth

    store = VoiceStreamTicketStore(ttl_seconds=60)
    ticket, _ = store.issue(
        user_id="user-99",
        access_token="ticket-jwt",
        email=None,
    )
    monkeypatch.setattr(supabase_auth, "voice_stream_ticket_store", store)

    websocket = SimpleNamespace(
        headers={},
        query_params={"ticket": ticket},
    )
    user = await authenticate_websocket(
        websocket,
        settings=Settings(
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon-key",
            _env_file=None,
        ),
    )
    assert user.id == "user-99"
    assert user.access_token == "ticket-jwt"
    assert store.consume(ticket) is None


@pytest.mark.asyncio
async def test_websocket_auth_rejects_invalid_ticket():
    websocket = SimpleNamespace(
        headers={},
        query_params={"ticket": "not-a-real-ticket"},
    )
    with pytest.raises(HTTPException) as exc:
        await authenticate_websocket(
            websocket,
            settings=Settings(
                supabase_url="https://example.supabase.co",
                supabase_anon_key="anon-key",
                _env_file=None,
            ),
        )
    assert exc.value.status_code == 401
