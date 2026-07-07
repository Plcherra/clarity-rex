from datetime import date

import pytest

from app.services.usage_admin_period import (
    USAGE_HISTORY_START,
    UsageAdminPeriodKind,
    resolve_usage_admin_period,
)


def test_resolve_all_time_period():
    resolved = resolve_usage_admin_period(
        period="all",
        today=date(2026, 7, 6),
    )

    assert resolved.kind == UsageAdminPeriodKind.ALL
    assert resolved.start_date == USAGE_HISTORY_START
    assert resolved.end_date == date(2026, 7, 6)


def test_resolve_year_period_for_current_year():
    resolved = resolve_usage_admin_period(
        period="year",
        year=2026,
        today=date(2026, 7, 6),
    )

    assert resolved.start_date == date(2026, 1, 1)
    assert resolved.end_date == date(2026, 7, 6)


def test_resolve_year_period_for_past_year():
    resolved = resolve_usage_admin_period(
        period="year",
        year=2025,
        today=date(2026, 7, 6),
    )

    assert resolved.start_date == date(2025, 1, 1)
    assert resolved.end_date == date(2025, 12, 31)


def test_resolve_month_period_for_past_month():
    resolved = resolve_usage_admin_period(
        period="month",
        year=2026,
        month=6,
        today=date(2026, 7, 6),
    )

    assert resolved.start_date == date(2026, 6, 1)
    assert resolved.end_date == date(2026, 6, 30)


def test_resolve_day_period():
    resolved = resolve_usage_admin_period(
        period="day",
        day=date(2026, 6, 15),
        today=date(2026, 7, 6),
    )

    assert resolved.start_date == date(2026, 6, 15)
    assert resolved.end_date == date(2026, 6, 15)


def test_invalid_period_raises():
    with pytest.raises(ValueError):
        resolve_usage_admin_period(period="weekly")
