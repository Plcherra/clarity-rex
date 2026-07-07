from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from enum import StrEnum

USAGE_HISTORY_START = date(2026, 1, 1)


class UsageAdminPeriodKind(StrEnum):
    ALL = "all"
    YEAR = "year"
    MONTH = "month"
    DAY = "day"


@dataclass(frozen=True)
class UsageAdminPeriod:
    kind: UsageAdminPeriodKind
    start_date: date
    end_date: date

    def to_response(self) -> dict[str, str]:
        return {
            "period": self.kind.value,
            "start_date": self.start_date.isoformat(),
            "end_date": self.end_date.isoformat(),
        }


def resolve_usage_admin_period(
    *,
    period: str = "all",
    year: int | None = None,
    month: int | None = None,
    day: date | None = None,
    today: date | None = None,
) -> UsageAdminPeriod:
    current = today or date.today()
    normalized = (period or UsageAdminPeriodKind.ALL.value).strip().lower()
    try:
        kind = UsageAdminPeriodKind(normalized)
    except ValueError as error:
        raise ValueError(f"Unsupported usage period: {period}") from error

    if kind == UsageAdminPeriodKind.ALL:
        return UsageAdminPeriod(kind, USAGE_HISTORY_START, current)

    if kind == UsageAdminPeriodKind.YEAR:
        selected_year = year or current.year
        if selected_year < 2000 or selected_year > 2100:
            raise ValueError("Invalid year.")
        start = date(selected_year, 1, 1)
        end = date(selected_year, 12, 31)
        if selected_year == current.year:
            end = current
        return UsageAdminPeriod(kind, start, end)

    if kind == UsageAdminPeriodKind.MONTH:
        selected_year = year or current.year
        selected_month = month or current.month
        if selected_month < 1 or selected_month > 12:
            raise ValueError("Invalid month.")
        start = date(selected_year, selected_month, 1)
        if selected_month == 12:
            end = date(selected_year, 12, 31)
        else:
            end = date(selected_year, selected_month + 1, 1) - timedelta(days=1)
        if selected_year == current.year and selected_month == current.month:
            end = min(end, current)
        return UsageAdminPeriod(kind, start, end)

    if kind == UsageAdminPeriodKind.DAY:
        selected_day = day or current
        return UsageAdminPeriod(kind, selected_day, selected_day)

    raise ValueError(f"Unsupported usage period: {period}")
