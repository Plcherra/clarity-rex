from __future__ import annotations

import logging
from datetime import date, datetime
from typing import Any

from app.config import Settings, get_settings
from app.models.usage_tracking import (
    UsageStatus,
    UsageTrackingEvent,
    UsageTrackingValidationError,
)
from app.services.usage_cost_estimator import (
    duration_unit_minutes,
    estimate_llm_cost_cents,
    estimate_tts_cost_cents,
    estimate_usage_cost_cents,
    llm_unit_count,
    resolve_tts_usage_provider,
)
from app.services.usage_admin_period import UsageAdminPeriod, resolve_usage_admin_period
from app.services.usage_cost_breakdown import (
    attach_user_cost_insights,
    finalize_slices,
    group_events_by_user,
    largest_driver,
    merge_all_slices,
    plaid_platform_totals,
    pricing_from_cogs,
    voice_cost_cents,
)
from app.services.usage_tracking_owner_queries import (
    UsageOwnerQueries,
    aggregate_owner_users,
    build_period_platform_summary,
    build_usage_totals,
    empty_owner_totals,
    add_owner_row,
    merge_owner_users_with_profiles,
)
from app.services.usage_tracking_transport import UsageTrackingTransport


class UsageTrackingService:
    def __init__(
        self,
        settings: Settings | None = None,
        logger: logging.Logger | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.logger = logger or logging.getLogger("clarity.usage")
        self._transport = UsageTrackingTransport(self.settings)
        self._owner_queries = UsageOwnerQueries(self._transport)

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
            await self._transport.insert_event(event.to_insert_payload())
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
        provider: str | None = None,
        synthesis: dict[str, Any] | None = None,
        status: UsageStatus = "success",
        error_class: str | None = None,
    ) -> bool:
        units = (
            float(character_count)
            if character_count is not None and character_count > 0
            else duration_unit_minutes(duration_ms)
        )
        resolved_provider = resolve_tts_usage_provider(
            synthesis=synthesis,
            provider=provider,
            voice_name=model if model != "none" else None,
        )
        cost = estimate_tts_cost_cents(
            character_count=character_count,
            duration_ms=duration_ms,
            provider=resolved_provider,
            settings=self.settings,
        )
        return await self.record_event(
            user_id=user_id,
            event_type="tts",
            surface="voice",
            feature="text_to_speech",
            channel="voice",
            provider=resolved_provider,
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
        rows = await self._owner_queries.select_owner_daily(
            user_id=user_id,
            start_date=current_day.replace(day=1),
        )
        totals = build_usage_totals(rows, current_day)
        totals["daily"] = rows
        return totals

    async def get_owner_usage(
        self,
        *,
        requester_user_id: str,
        period: str = "all",
        year: int | None = None,
        month: int | None = None,
        day: date | None = None,
        today: date | None = None,
    ) -> dict[str, Any]:
        if not await self.is_usage_owner(requester_user_id):
            return {"authorized": False, "users": []}

        resolved = resolve_usage_admin_period(
            period=period,
            year=year,
            month=month,
            day=day,
            today=today,
        )
        rows = await self._load_owner_period_rows(resolved)
        usage_users = aggregate_owner_users(rows)
        profiles = await self._owner_queries.list_profiles()
        users = merge_owner_users_with_profiles(usage_users, profiles)
        insights = await self._owner_cost_insights(resolved)
        users = attach_user_cost_insights(
            users,
            grouped=insights["grouped"],
            plaid_counts=insights["plaid_counts"],
        )
        payload = {"authorized": True, "users": users}
        payload.update(resolved.to_response())
        payload["registered_user_count"] = len(profiles)
        return payload

    async def get_owner_platform_summary(
        self,
        *,
        requester_user_id: str,
        period: str = "all",
        year: int | None = None,
        month: int | None = None,
        day: date | None = None,
        today: date | None = None,
    ) -> dict[str, Any]:
        if not await self.is_usage_owner(requester_user_id):
            return {"authorized": False}

        resolved = resolve_usage_admin_period(
            period=period,
            year=year,
            month=month,
            day=day,
            today=today,
        )
        rows = await self._load_owner_period_rows(resolved)
        profiles = await self._owner_queries.list_profiles()
        summary = build_period_platform_summary(rows)
        insights = await self._owner_cost_insights(resolved)
        slices = insights["slices"]
        summary["registered_user_count"] = len(profiles)
        summary["authorized"] = True
        summary["cost_mix"] = slices
        summary["largest_cost_driver"] = largest_driver(slices)
        summary["pricing"] = pricing_from_cogs(
            cogs_cents=float(summary.get("month_estimated_cost_cents") or 0),
            active_user_count=int(summary.get("active_user_count") or 0),
            voice_seconds=float(summary.get("month_voice_seconds") or 0),
            voice_cost_cents=voice_cost_cents(slices),
        )
        summary["plaid"] = insights["plaid"]
        summary.update(resolved.to_response())
        return summary

    async def _owner_cost_insights(
        self,
        resolved: UsageAdminPeriod,
    ) -> dict[str, Any]:
        events = await self._owner_queries.select_usage_events(
            start_date=resolved.start_date,
            end_date=resolved.end_date,
        )
        grouped = group_events_by_user(events)
        slices = finalize_slices(merge_all_slices(grouped))
        plaid_counts = await self._owner_queries.plaid_link_counts()
        return {
            "grouped": grouped,
            "slices": slices,
            "plaid_counts": plaid_counts,
            "plaid": plaid_platform_totals(plaid_counts),
        }

    async def _load_owner_period_rows(
        self,
        resolved: UsageAdminPeriod,
    ) -> list[dict[str, Any]]:
        return await self._owner_queries.select_owner_daily(
            start_date=resolved.start_date,
            end_date=resolved.end_date,
        )

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
        rows = await self._owner_queries.select_owner_daily(
            user_id=user_id,
            start_date=start_date,
            end_date=end,
        )
        emails = await self._owner_queries.profile_emails([user_id])
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
            return await self._owner_queries.is_admin_user(user_id)
        except Exception as error:
            self.logger.warning(
                "usage_owner_check_failed error_class=%s",
                error.__class__.__name__,
            )
            return False
