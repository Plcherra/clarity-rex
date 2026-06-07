from __future__ import annotations

import logging
from datetime import date, datetime, timedelta
from typing import Any
from urllib.parse import quote, urlencode

import httpx

from app.config import Settings, get_settings
from app.models.usage_tracking import (
    UsageStatus,
    UsageTrackingEvent,
    UsageTrackingValidationError,
)
from app.services.http_client import request_with_retries

USAGE_EVENTS_TABLE = "user_usage_events"
VOICE_SUMMARIES_VIEW = "user_voice_summaries"
ADMIN_USERS_TABLE = "admin_users"


class UsageTrackingService:
    def __init__(
        self,
        settings: Settings | None = None,
        logger: logging.Logger | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.logger = logger or logging.getLogger("clarity.usage")

    async def record_event(
        self,
        *,
        user_id: str,
        event_type: str,
        surface: str | None = None,
        feature: str | None = None,
        channel: str | None = None,
        provider: str = "clarity_api",
        model: str = "none",
        duration_ms: int | None = None,
        latency_ms: int | None = None,
        status: UsageStatus = "success",
        error_class: str | None = None,
    ) -> bool:
        try:
            event = UsageTrackingEvent(
                user_id=user_id,
                event_type=event_type,
                surface=surface,
                feature=feature,
                channel=channel,
                provider=provider,
                model=model,
                duration_ms=duration_ms,
                latency_ms=latency_ms,
                status=status,
                error_class=error_class,
            )
            await self._insert_event(event.to_insert_payload())
            return True
        except UsageTrackingValidationError as error:
            self.logger.warning("usage_tracking_rejected %s", str(error))
        except Exception as error:
            self.logger.warning(
                "usage_tracking_failed error_class=%s",
                error.__class__.__name__,
            )
        return False

    async def record_llm_turn(
        self,
        *,
        user_id: str,
        surface: str,
        channel: str,
        model: str,
        latency_ms: int | None = None,
        token_count: int | None = None,
        status: UsageStatus = "success",
        error_class: str | None = None,
    ) -> bool:
        del token_count
        return await self.record_event(
            user_id=user_id,
            event_type="llm",
            surface=surface,
            feature="assistant_response",
            channel=channel,
            provider="grok",
            model=model,
            latency_ms=latency_ms,
            status=status,
            error_class=error_class,
        )

    async def record_stt_turn(
        self,
        *,
        user_id: str,
        duration_ms: int | None = None,
        latency_ms: int | None = None,
        model: str = "none",
        status: UsageStatus = "success",
        error_class: str | None = None,
    ) -> bool:
        return await self.record_event(
            user_id=user_id,
            event_type="stt",
            surface="voice",
            feature="speech_to_text",
            channel="voice",
            provider="deepgram",
            model=model,
            duration_ms=duration_ms,
            latency_ms=latency_ms,
            status=status,
            error_class=error_class,
        )

    async def record_tts_turn(
        self,
        *,
        user_id: str,
        duration_ms: int | None = None,
        latency_ms: int | None = None,
        model: str = "none",
        status: UsageStatus = "success",
        error_class: str | None = None,
    ) -> bool:
        return await self.record_event(
            user_id=user_id,
            event_type="tts",
            surface="voice",
            feature="text_to_speech",
            channel="voice",
            provider="google_tts",
            model=model,
            duration_ms=duration_ms,
            latency_ms=latency_ms,
            status=status,
            error_class=error_class,
        )

    async def record_voice_session(
        self,
        *,
        user_id: str,
        duration_ms: int,
        status: UsageStatus = "completed",
    ) -> bool:
        return await self.record_event(
            user_id=user_id,
            event_type="voice_session",
            surface="voice",
            feature="voice_call",
            channel="voice",
            provider="clarity_api",
            duration_ms=duration_ms,
            status=status,
        )

    async def get_user_voice_usage(
        self,
        *,
        user_id: str,
        today: date | None = None,
    ) -> dict[str, Any]:
        current_day = today or datetime.now().date()
        rows = await self._select_voice_summaries(
            user_id=user_id,
            start_date=current_day.replace(day=1),
        )
        return _build_usage_totals(rows, current_day)

    async def get_owner_usage(
        self,
        *,
        requester_user_id: str,
        today: date | None = None,
    ) -> dict[str, Any]:
        if not await self.is_usage_owner(requester_user_id):
            return {"authorized": False, "users": []}

        current_day = today or datetime.now().date()
        rows = await self._select_voice_summaries(
            start_date=current_day.replace(day=1),
        )
        users: dict[str, dict[str, Any]] = {}
        for row in rows:
            user_id = str(row.get("user_id") or "")
            if not user_id:
                continue
            totals = users.setdefault(
                user_id,
                {
                    "user_id": user_id,
                    "month_voice_seconds": 0.0,
                    "month_llm_calls": 0,
                    "month_stt_seconds": 0.0,
                    "month_tts_seconds": 0.0,
                },
            )
            totals["month_voice_seconds"] += _float(row, "voice_seconds")
            totals["month_llm_calls"] += _int(row, "llm_calls")
            totals["month_stt_seconds"] += _float(row, "stt_seconds")
            totals["month_tts_seconds"] += _float(row, "tts_seconds")
        return {"authorized": True, "users": sorted(users.values(), key=_sort_usage)}

    async def is_usage_owner(self, user_id: str) -> bool:
        owner_user_id = (self.settings.usage_owner_user_id or "").strip()
        if owner_user_id and user_id == owner_user_id:
            return True

        try:
            rows = await self._select_rows(
                ADMIN_USERS_TABLE,
                {
                    "select": "user_id,role",
                    "user_id": f"eq.{user_id}",
                    "role": "in.(owner,admin)",
                    "limit": "1",
                },
            )
        except Exception as error:
            self.logger.warning(
                "usage_owner_check_failed error_class=%s",
                error.__class__.__name__,
            )
            return False
        return bool(rows)

    async def _insert_event(self, payload: dict[str, Any]) -> None:
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
            detail = _response_text(error.response)
            raise RuntimeError(f"Supabase usage tracking failed: {detail}") from error

    async def _select_voice_summaries(
        self,
        *,
        start_date: date,
        user_id: str | None = None,
    ) -> list[dict[str, Any]]:
        params = {
            "select": "*",
            "usage_date": f"gte.{start_date.isoformat()}",
        }
        if user_id is not None:
            params["user_id"] = f"eq.{user_id}"
        return await self._select_rows(VOICE_SUMMARIES_VIEW, params)

    async def _select_rows(
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
            detail = _response_text(error.response)
            raise RuntimeError(f"Supabase usage query failed: {detail}") from error
        data = response.json()
        return data if isinstance(data, list) else []


def _response_text(response: httpx.Response | None) -> str:
    if response is None:
        return "unknown"
    try:
        return response.text[:500]
    except Exception:
        return "unreadable response"


def _build_usage_totals(rows: list[dict[str, Any]], today: date) -> dict[str, Any]:
    week_start = today - timedelta(days=today.weekday())
    month_start = today.replace(day=1)
    totals = {
        "today_voice_seconds": 0.0,
        "week_voice_seconds": 0.0,
        "month_voice_seconds": 0.0,
        "today_llm_calls": 0,
        "week_llm_calls": 0,
        "month_llm_calls": 0,
        "today_stt_seconds": 0.0,
        "week_stt_seconds": 0.0,
        "month_stt_seconds": 0.0,
        "today_tts_seconds": 0.0,
        "week_tts_seconds": 0.0,
        "month_tts_seconds": 0.0,
    }
    for row in rows:
        usage_date = _date(row, "usage_date")
        if usage_date < month_start:
            continue
        _add_period(totals, "month", row)
        if usage_date >= week_start:
            _add_period(totals, "week", row)
        if usage_date == today:
            _add_period(totals, "today", row)
    return totals


def _add_period(totals: dict[str, Any], period: str, row: dict[str, Any]) -> None:
    totals[f"{period}_voice_seconds"] += _float(row, "voice_seconds")
    totals[f"{period}_llm_calls"] += _int(row, "llm_calls")
    totals[f"{period}_stt_seconds"] += _float(row, "stt_seconds")
    totals[f"{period}_tts_seconds"] += _float(row, "tts_seconds")


def _date(row: dict[str, Any], key: str) -> date:
    value = row.get(key)
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        return date.fromisoformat(value)
    raise ValueError(f"Invalid date field {key}.")


def _float(row: dict[str, Any], key: str) -> float:
    value = row.get(key, 0)
    return float(value or 0)


def _int(row: dict[str, Any], key: str) -> int:
    value = row.get(key, 0)
    return int(value or 0)


def _sort_usage(row: dict[str, Any]) -> tuple[float, str]:
    return (-float(row["month_voice_seconds"]), row["user_id"])
