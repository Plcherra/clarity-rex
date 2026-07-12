"""Short-lived single-use tickets for browser WebSocket auth.

Browser WebSockets cannot set Authorization headers. Prefer opaque tickets
over putting the Supabase JWT in the query string. The JWT stays server-side
inside the ticket record so RLS still uses the user token after consume.
"""

from __future__ import annotations

import secrets
import threading
import time
from dataclasses import dataclass

DEFAULT_TICKET_TTL_SECONDS = 60


@dataclass(frozen=True)
class VoiceStreamTicket:
    user_id: str
    email: str | None
    access_token: str
    expires_at: float


class VoiceStreamTicketStore:
    def __init__(self, *, ttl_seconds: int = DEFAULT_TICKET_TTL_SECONDS) -> None:
        self._ttl_seconds = max(ttl_seconds, 5)
        self._lock = threading.Lock()
        self._tickets: dict[str, VoiceStreamTicket] = {}

    def issue(
        self,
        *,
        user_id: str,
        access_token: str,
        email: str | None = None,
    ) -> tuple[str, int]:
        self._purge_expired()
        ticket = secrets.token_urlsafe(32)
        expires_at = time.monotonic() + self._ttl_seconds
        with self._lock:
            self._tickets[ticket] = VoiceStreamTicket(
                user_id=user_id,
                email=email,
                access_token=access_token,
                expires_at=expires_at,
            )
        return ticket, self._ttl_seconds

    def peek(self, ticket: str) -> VoiceStreamTicket | None:
        if not ticket:
            return None
        with self._lock:
            record = self._tickets.get(ticket)
        if record is None:
            return None
        if time.monotonic() > record.expires_at:
            return None
        return record

    def consume(self, ticket: str) -> VoiceStreamTicket | None:
        if not ticket:
            return None
        with self._lock:
            record = self._tickets.pop(ticket, None)
        if record is None:
            return None
        if time.monotonic() > record.expires_at:
            return None
        return record

    def _purge_expired(self) -> None:
        now = time.monotonic()
        with self._lock:
            expired = [
                key
                for key, value in self._tickets.items()
                if now > value.expires_at
            ]
            for key in expired:
                self._tickets.pop(key, None)


voice_stream_ticket_store = VoiceStreamTicketStore()
