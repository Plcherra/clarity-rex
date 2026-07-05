from __future__ import annotations

from urllib.parse import quote, urlencode
from typing import Any

import httpx

from app.config import Settings
from app.services.http_client import request_with_retries

USAGE_EVENTS_TABLE = "user_usage_events"
VOICE_SUMMARIES_VIEW = "user_voice_summaries"
OWNER_USAGE_DAILY_VIEW = "owner_usage_daily"
ADMIN_USERS_TABLE = "admin_users"
PROFILES_TABLE = "profiles"


def response_text(response: httpx.Response | None) -> str:
    if response is None:
        return "unknown"
    try:
        return response.text[:500]
    except Exception:
        return "unreadable response"


class UsageTrackingTransport:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def insert_event(self, payload: dict[str, Any]) -> None:
        rest_url = self.settings.supabase_rest_url
        service_key = self.settings.supabase_service_role_key
        if not rest_url or not service_key:
            raise RuntimeError("Supabase service role is not configured.")

        body = {key: value for key, value in payload.items() if value is not None}
        url = f"{rest_url}/{quote(USAGE_EVENTS_TABLE)}"
        headers = {
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }

        response = await request_with_retries("POST", url, headers=headers, json=body)
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError as error:
            detail = response_text(error.response)
            raise RuntimeError(f"Supabase usage tracking failed: {detail}") from error

    async def select_rows(
        self,
        table: str,
        params: dict[str, str],
    ) -> list[dict[str, Any]]:
        rest_url = self.settings.supabase_rest_url
        service_key = self.settings.supabase_service_role_key
        if not rest_url or not service_key:
            raise RuntimeError("Supabase service role is not configured.")

        query = urlencode(params)
        url = f"{rest_url}/{quote(table)}?{query}"
        headers = {
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
        }
        response = await request_with_retries("GET", url, headers=headers)
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError as error:
            detail = response_text(error.response)
            raise RuntimeError(f"Supabase usage query failed: {detail}") from error
        data = response.json()
        return data if isinstance(data, list) else []
