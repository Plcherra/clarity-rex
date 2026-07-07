from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any

from app.services.usage_tracking_transport import (
    ADMIN_USERS_TABLE,
    OWNER_USAGE_DAILY_VIEW,
    PROFILES_TABLE,
    UsageTrackingTransport,
)


def build_usage_totals(rows: list[dict[str, Any]], today: date) -> dict[str, Any]:
    week_start = today - timedelta(days=today.weekday())
    month_start = today.replace(day=1)
    totals = empty_owner_totals()
    for row in rows:
        usage_date = parse_date(row, "usage_date")
        if usage_date < month_start:
            continue
        add_owner_row(totals, row, prefix="month")
        if usage_date >= week_start:
            add_owner_row(totals, row, prefix="week")
        if usage_date == today:
            add_owner_row(totals, row, prefix="today")
    return totals


def empty_owner_totals() -> dict[str, Any]:
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


def add_owner_row(
    totals: dict[str, Any],
    row: dict[str, Any],
    *,
    prefix: str | None = None,
) -> None:
    if prefix is None:
        totals["month_voice_seconds"] = totals.get("month_voice_seconds", 0.0) + float_value(
            row, "voice_seconds"
        )
        totals["month_llm_calls"] = totals.get("month_llm_calls", 0) + int_value(row, "llm_calls")
        totals["month_chat_llm_calls"] = totals.get("month_chat_llm_calls", 0) + int_value(
            row, "chat_llm_calls"
        )
        totals["month_voice_llm_calls"] = totals.get("month_voice_llm_calls", 0) + int_value(
            row, "voice_llm_calls"
        )
        totals["month_stt_seconds"] = totals.get("month_stt_seconds", 0.0) + float_value(
            row, "stt_seconds"
        )
        totals["month_tts_seconds"] = totals.get("month_tts_seconds", 0.0) + float_value(
            row, "tts_seconds"
        )
        totals["month_estimated_cost_cents"] = totals.get(
            "month_estimated_cost_cents", 0.0
        ) + float_value(row, "estimated_cost_cents")
        return

    totals[f"{prefix}_voice_seconds"] += float_value(row, "voice_seconds")
    totals[f"{prefix}_llm_calls"] += int_value(row, "llm_calls")
    totals[f"{prefix}_chat_llm_calls"] += int_value(row, "chat_llm_calls")
    totals[f"{prefix}_voice_llm_calls"] += int_value(row, "voice_llm_calls")
    totals[f"{prefix}_stt_seconds"] += float_value(row, "stt_seconds")
    totals[f"{prefix}_tts_seconds"] += float_value(row, "tts_seconds")
    totals[f"{prefix}_estimated_cost_cents"] += float_value(row, "estimated_cost_cents")


def aggregate_owner_users(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    users: dict[str, dict[str, Any]] = {}
    for row in rows:
        user_id = str(row.get("user_id") or "")
        if not user_id:
            continue
        totals = users.setdefault(user_id, user_monthly_shell(user_id))
        totals["month_voice_seconds"] += float_value(row, "voice_seconds")
        totals["month_llm_calls"] += int_value(row, "llm_calls")
        totals["month_chat_llm_calls"] += int_value(row, "chat_llm_calls")
        totals["month_voice_llm_calls"] += int_value(row, "voice_llm_calls")
        totals["month_stt_seconds"] += float_value(row, "stt_seconds")
        totals["month_tts_seconds"] += float_value(row, "tts_seconds")
        totals["month_estimated_cost_cents"] += float_value(row, "estimated_cost_cents")
    return sorted(users.values(), key=sort_usage)


def user_monthly_shell(user_id: str) -> dict[str, Any]:
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


def parse_date(row: dict[str, Any], key: str) -> date:
    value = row.get(key)
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        return date.fromisoformat(value)
    raise ValueError(f"Invalid date field {key}.")


def float_value(row: dict[str, Any], key: str) -> float:
    value = row.get(key, 0)
    return float(value or 0)


def int_value(row: dict[str, Any], key: str) -> int:
    value = row.get(key, 0)
    return int(value or 0)


def sort_usage(row: dict[str, Any]) -> tuple[float, str]:
    return (-float(row["month_estimated_cost_cents"]), row["user_id"])


def sort_owner_user_rows(row: dict[str, Any]) -> tuple[int, float, str, str]:
    has_usage = (
        float(row.get("month_estimated_cost_cents") or 0) > 0
        or int(row.get("month_llm_calls") or 0) > 0
        or float(row.get("month_voice_seconds") or 0) > 0
    )
    email = str(row.get("email") or "").strip().lower()
    return (
        0 if has_usage else 1,
        -float(row.get("month_estimated_cost_cents") or 0),
        email,
        str(row.get("user_id") or ""),
    )


def build_period_platform_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    summary = {
        "month_voice_seconds": 0.0,
        "month_llm_calls": 0,
        "month_chat_llm_calls": 0,
        "month_voice_llm_calls": 0,
        "month_stt_seconds": 0.0,
        "month_tts_seconds": 0.0,
        "month_estimated_cost_cents": 0.0,
        "active_user_count": 0,
    }
    user_ids: set[str] = set()
    for row in rows:
        user_id = str(row.get("user_id") or "")
        if user_id:
            user_ids.add(user_id)
        add_owner_row(summary, row)
    summary["active_user_count"] = len(user_ids)
    return summary


def merge_owner_users_with_profiles(
    usage_users: list[dict[str, Any]],
    profiles: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    users: dict[str, dict[str, Any]] = {
        str(row["user_id"]): dict(row) for row in usage_users if row.get("user_id")
    }
    for profile in profiles:
        user_id = str(profile.get("id") or "")
        if not user_id:
            continue
        row = users.setdefault(user_id, user_monthly_shell(user_id))
        email = profile.get("email")
        if isinstance(email, str) and email.strip():
            row["email"] = email.strip()
    return sorted(users.values(), key=sort_owner_user_rows)


class UsageOwnerQueries:
    def __init__(self, transport: UsageTrackingTransport) -> None:
        self._transport = transport

    async def select_owner_daily(
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
        return await self._transport.select_rows(OWNER_USAGE_DAILY_VIEW, params)

    async def list_profiles(self) -> list[dict[str, Any]]:
        return await self._transport.select_rows(
            PROFILES_TABLE,
            {
                "select": "id,email,created_at",
                "order": "created_at.desc",
            },
        )

    async def profile_emails(self, user_ids: list[str]) -> dict[str, str | None]:
        if not user_ids:
            return {}
        try:
            ids = ",".join(user_ids)
            rows = await self._transport.select_rows(
                PROFILES_TABLE,
                {
                    "select": "id,email",
                    "id": f"in.({ids})",
                },
            )
        except Exception:
            return {}
        emails: dict[str, str | None] = {}
        for row in rows:
            user_id = str(row.get("id") or "")
            email = row.get("email")
            if user_id:
                emails[user_id] = email if isinstance(email, str) else None
        return emails

    async def is_admin_user(self, user_id: str) -> bool:
        rows = await self._transport.select_rows(
            ADMIN_USERS_TABLE,
            {
                "select": "user_id,role",
                "user_id": f"eq.{user_id}",
                "role": "in.(owner,admin)",
                "limit": "1",
            },
        )
        return bool(rows)
