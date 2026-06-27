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
from app.services.usage_cost_estimator import (
    duration_unit_minutes,
    estimate_llm_cost_cents,
    estimate_tts_cost_cents,
    estimate_usage_cost_cents,
    llm_unit_count,
)

USAGE_EVENTS_TABLE = "user_usage_events"
VOICE_SUMMARIES_VIEW = "user_voice_summaries"
OWNER_USAGE_DAILY_VIEW = "owner_usage_daily"
ADMIN_USERS_TABLE = "admin_users"
PROFILES_TABLE = "profiles"


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
        unit_count: float | None = None,
        estimated_cost_cents: float | None = None,
        status: UsageStatus = "success",
        error_class: str | None = None,
    ) -> bool:
        try:
            if estimated_cost_cents is None:
                estimated_cost_cents = estimate_usage_cost_cents(
                    event_type=event_type,
                    unit_count=unit_count,
                    duration_ms=duration_ms,
                    settings=self.settings,
                )
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
                unit_count=unit_count,
                estimated_cost_cents=estimated_cost_cents,
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
        prompt_tokens: int | None = None,
        completion_tokens: int | None = None,
        grok_cost_cents: float | None = None,
        status: UsageStatus = "success",
        error_class: str | None = None,
    ) -> bool:
        total = token_count
        if total is None and (prompt_tokens or completion_tokens):
            total = (prompt_tokens or 0) + (completion_tokens or 0)
        units = llm_unit_count(total)
        cost = grok_cost_cents
        if cost is None:
            cost = estimate_llm_cost_cents(
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_tokens=total,
                settings=self.settings,
            )
        return await self.record_event(
            user_id=user_id,
            event_type="llm",
            surface=surface,
            feature="assistant_response",
            channel=channel,
            provider="grok",
            model=model,
            latency_ms=latency_ms,
            unit_count=units,
            estimated_cost_cents=cost,
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
            unit_count=duration_unit_minutes(duration_ms),
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
        character_count: int | None = None,
        status: UsageStatus = "success",
        error_class: str | None = None,
    ) -> bool:
        units = (
            float(character_count)
            if character_count is not None and character_count > 0
            else duration_unit_minutes(duration_ms)
        )
        cost = estimate_tts_cost_cents(
            character_count=character_count,
            duration_ms=duration_ms,
            settings=self.settings,
        )
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
            unit_count=units,
            estimated_cost_cents=cost,
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
        rows = await self._select_owner_daily(
            user_id=user_id,
            start_date=current_day.replace(day=1),
        )
        totals = _build_usage_totals(rows, current_day)
        totals["daily"] = rows
        return totals

    async def get_owner_usage(
        self,
        *,
        requester_user_id: str,
        today: date | None = None,
    ) -> dict[str, Any]:
        if not await self.is_usage_owner(requester_user_id):
            return {"authorized": False, "users": []}

        current_day = today or datetime.now().date()
        rows = await self._select_owner_daily(
            start_date=current_day.replace(day=1),
        )
        users = _aggregate_owner_users(rows)
        emails = await self._profile_emails([user["user_id"] for user in users])
        for user in users:
            user["email"] = emails.get(user["user_id"])
        return {"authorized": True, "users": users}

    async def get_owner_platform_summary(
        self,
        *,
        requester_user_id: str,
        today: date | None = None,
    ) -> dict[str, Any]:
        if not await self.is_usage_owner(requester_user_id):
            return {"authorized": False}

        current_day = today or datetime.now().date()
        rows = await self._select_owner_daily(
            start_date=current_day.replace(day=1),
        )
        summary = _empty_owner_totals()
        user_ids: set[str] = set()
        for row in rows:
            user_id = str(row.get("user_id") or "")
            if user_id:
                user_ids.add(user_id)
            _add_owner_row(summary, row)
        summary["active_user_count"] = len(user_ids)
        summary["authorized"] = True
        return summary

    async def get_owner_user_daily(
        self,
        *,
        requester_user_id: str,
        user_id: str,
        start_date: date,
        end_date: date | None = None,
    ) -> dict[str, Any]:
        if not await self.is_usage_owner(requester_user_id):
            return {"authorized": False, "daily": []}

        end = end_date or datetime.now().date()
        rows = await self._select_owner_daily(
            user_id=user_id,
            start_date=start_date,
            end_date=end,
        )
        emails = await self._profile_emails([user_id])
        return {
            "authorized": True,
            "user_id": user_id,
            "email": emails.get(user_id),
            "daily": rows,
        }

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

    async def _select_owner_daily(
        self,
        *,
        start_date: date,
        user_id: str | None = None,
        end_date: date | None = None,
    ) -> list[dict[str, Any]]:
        params: dict[str, str] = {
            "select": "*",
            "order": "usage_date.asc",
        }
        if end_date is not None:
            params["and"] = (
                f"(usage_date.gte.{start_date.isoformat()},"
                f"usage_date.lte.{end_date.isoformat()})"
            )
        else:
            params["usage_date"] = f"gte.{start_date.isoformat()}"
        if user_id is not None:
            params["user_id"] = f"eq.{user_id}"
        return await self._select_rows(OWNER_USAGE_DAILY_VIEW, params)

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

    async def _profile_emails(self, user_ids: list[str]) -> dict[str, str | None]:
        if not user_ids:
            return {}
        try:
            ids = ",".join(user_ids)
            rows = await self._select_rows(
                PROFILES_TABLE,
                {
                    "select": "id,email",
                    "id": f"in.({ids})",
                },
            )
        except Exception as error:
            self.logger.warning(
                "usage_profile_email_lookup_failed error_class=%s",
                error.__class__.__name__,
            )
            return {}
        emails: dict[str, str | None] = {}
        for row in rows:
            user_id = str(row.get("id") or "")
            email = row.get("email")
            if user_id:
                emails[user_id] = email if isinstance(email, str) else None
        return emails

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
    totals = _empty_owner_totals()
    for row in rows:
        usage_date = _date(row, "usage_date")
        if usage_date < month_start:
            continue
        _add_owner_row(totals, row, prefix="month")
        if usage_date >= week_start:
            _add_owner_row(totals, row, prefix="week")
        if usage_date == today:
            _add_owner_row(totals, row, prefix="today")
    return totals


def _empty_owner_totals() -> dict[str, Any]:
    return {
        "today_voice_seconds": 0.0,
        "week_voice_seconds": 0.0,
        "month_voice_seconds": 0.0,
        "today_llm_calls": 0,
        "week_llm_calls": 0,
        "month_llm_calls": 0,
        "today_chat_llm_calls": 0,
        "week_chat_llm_calls": 0,
        "month_chat_llm_calls": 0,
        "today_voice_llm_calls": 0,
        "week_voice_llm_calls": 0,
        "month_voice_llm_calls": 0,
        "today_stt_seconds": 0.0,
        "week_stt_seconds": 0.0,
        "month_stt_seconds": 0.0,
        "today_tts_seconds": 0.0,
        "week_tts_seconds": 0.0,
        "month_tts_seconds": 0.0,
        "today_estimated_cost_cents": 0.0,
        "week_estimated_cost_cents": 0.0,
        "month_estimated_cost_cents": 0.0,
    }


def _add_owner_row(
    totals: dict[str, Any],
    row: dict[str, Any],
    *,
    prefix: str | None = None,
) -> None:
    if prefix is None:
        totals["month_voice_seconds"] = totals.get("month_voice_seconds", 0.0) + _float(
            row, "voice_seconds"
        )
        totals["month_llm_calls"] = totals.get("month_llm_calls", 0) + _int(row, "llm_calls")
        totals["month_chat_llm_calls"] = totals.get("month_chat_llm_calls", 0) + _int(
            row, "chat_llm_calls"
        )
        totals["month_voice_llm_calls"] = totals.get("month_voice_llm_calls", 0) + _int(
            row, "voice_llm_calls"
        )
        totals["month_stt_seconds"] = totals.get("month_stt_seconds", 0.0) + _float(
            row, "stt_seconds"
        )
        totals["month_tts_seconds"] = totals.get("month_tts_seconds", 0.0) + _float(
            row, "tts_seconds"
        )
        totals["month_estimated_cost_cents"] = totals.get(
            "month_estimated_cost_cents", 0.0
        ) + _float(row, "estimated_cost_cents")
        return

    totals[f"{prefix}_voice_seconds"] += _float(row, "voice_seconds")
    totals[f"{prefix}_llm_calls"] += _int(row, "llm_calls")
    totals[f"{prefix}_chat_llm_calls"] += _int(row, "chat_llm_calls")
    totals[f"{prefix}_voice_llm_calls"] += _int(row, "voice_llm_calls")
    totals[f"{prefix}_stt_seconds"] += _float(row, "stt_seconds")
    totals[f"{prefix}_tts_seconds"] += _float(row, "tts_seconds")
    totals[f"{prefix}_estimated_cost_cents"] += _float(row, "estimated_cost_cents")


def _aggregate_owner_users(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    users: dict[str, dict[str, Any]] = {}
    for row in rows:
        user_id = str(row.get("user_id") or "")
        if not user_id:
            continue
        totals = users.setdefault(user_id, _user_monthly_shell(user_id))
        totals["month_voice_seconds"] += _float(row, "voice_seconds")
        totals["month_llm_calls"] += _int(row, "llm_calls")
        totals["month_chat_llm_calls"] += _int(row, "chat_llm_calls")
        totals["month_voice_llm_calls"] += _int(row, "voice_llm_calls")
        totals["month_stt_seconds"] += _float(row, "stt_seconds")
        totals["month_tts_seconds"] += _float(row, "tts_seconds")
        totals["month_estimated_cost_cents"] += _float(row, "estimated_cost_cents")
    return sorted(users.values(), key=_sort_usage)


def _user_monthly_shell(user_id: str) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "email": None,
        "month_voice_seconds": 0.0,
        "month_llm_calls": 0,
        "month_chat_llm_calls": 0,
        "month_voice_llm_calls": 0,
        "month_stt_seconds": 0.0,
        "month_tts_seconds": 0.0,
        "month_estimated_cost_cents": 0.0,
    }


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
    return (-float(row["month_estimated_cost_cents"]), row["user_id"])
