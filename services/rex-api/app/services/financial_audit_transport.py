"""Service-role transport for financial_audit_events."""

from __future__ import annotations

from typing import Any
from urllib.parse import quote

import httpx

from app.config import Settings
from app.services.http_client import request_with_retries
from app.services.usage_tracking_transport import response_text

FINANCIAL_AUDIT_EVENTS_TABLE = "financial_audit_events"


class FinancialAuditTransport:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def insert_event(self, payload: dict[str, Any]) -> None:
        rest_url = self.settings.supabase_rest_url
        service_key = self.settings.supabase_service_role_key
        if not rest_url or not service_key:
            raise RuntimeError("Supabase service role is not configured.")

        body = {key: value for key, value in payload.items() if value is not None}
        url = f"{rest_url}/{quote(FINANCIAL_AUDIT_EVENTS_TABLE)}"
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
            raise RuntimeError(f"Supabase financial audit insert failed: {detail}") from error
