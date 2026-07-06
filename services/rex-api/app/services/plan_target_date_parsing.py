"""Parse target dates for existing goal/plan updates."""

from __future__ import annotations

import calendar
import re
from datetime import date
from typing import Any, Optional

from app.services.goal_command_formatting import date_from_text, relative_date_from_text
from app.services.memory_date_normalizer import MemoryDateNormalizer

_DATE_NORMALIZER = MemoryDateNormalizer()

_MONTH_NAMES = (
    r"(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|"
    r"jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|"
    r"dec(?:ember)?)"
)
_END_OF_MONTH = re.compile(
    rf"\bend of\s+(?P<month>{_MONTH_NAMES})\b",
    re.IGNORECASE,
)
_PLAN_DATE_UPDATE = re.compile(
    rf"\b(?:add|set|give|put|assign|update)\b.{{0,80}}\b(?:date|deadline|due(?:\s+date)?|target(?:\s+date)?)\b"
    rf"|\b(?:add|set)\b.{{0,60}}\b(?:end of|by)\s+{_MONTH_NAMES}\b"
    rf"|\b(?:end of|by)\s+{_MONTH_NAMES}\b.{{0,60}}\b(?:goals?|plans?|all)\b",
    re.IGNORECASE,
)
_ALL_PLANS = re.compile(
    r"\b(?:all|each|every|both|three|the other)\b.{0,40}\b(?:goals?|plans?)\b"
    r"|\b(?:goals?|plans?)\b.{0,40}\b(?:all|each|every)\b",
    re.IGNORECASE,
)


def looks_like_plan_target_date_update(message: str) -> bool:
    cleaned = re.sub(r"\s+", " ", str(message or "")).strip()
    if len(cleaned) < 8:
        return False
    return bool(_PLAN_DATE_UPDATE.search(cleaned))


def selects_all_active_plans(message: str) -> bool:
    cleaned = re.sub(r"\s+", " ", str(message or "")).strip()
    if _ALL_PLANS.search(cleaned):
        return True
    if re.search(r"\b\d+\s+goals?\b", cleaned, re.IGNORECASE):
        return True
    if re.search(r"\bother\s+\d+\b", cleaned, re.IGNORECASE):
        return True
    return False


def resolve_plan_target_date_iso(
    message: str,
    *,
    time_context: Optional[dict[str, Any]],
) -> Optional[str]:
    cleaned = re.sub(r"\s+", " ", str(message or "")).strip()
    if not cleaned:
        return None

    end_of = _END_OF_MONTH.search(cleaned)
    if end_of:
        month_number = _month_number(end_of.group("month"))
        if month_number is not None:
            year = _context_year(time_context)
            last_day = calendar.monthrange(year, month_number)[1]
            return date(year, month_number, last_day).isoformat()

    for resolver in (
        lambda: date_from_text(cleaned, time_context=time_context or {}),
        lambda: relative_date_from_text(cleaned, time_context=time_context),
    ):
        raw = resolver()
        iso = normalize_plan_target_date_for_storage(raw, time_context=time_context)
        if iso:
            return iso
    return None


def normalize_plan_target_date_for_storage(
    value: Any,
    *,
    time_context: Optional[dict[str, Any]] = None,
) -> Optional[str]:
    cleaned = re.sub(r"\s+", " ", str(value or "")).strip(" .")
    if not cleaned:
        return None
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", cleaned):
        return cleaned

    month_number = _month_number(cleaned)
    if month_number is not None and not re.search(r"\d", cleaned):
        year = _context_year(time_context)
        last_day = calendar.monthrange(year, month_number)[1]
        return date(year, month_number, last_day).isoformat()

    normalized = _DATE_NORMALIZER.normalize(cleaned, time_context=time_context)
    if not normalized:
        return None

    month_day = re.fullmatch(
        rf"(?i)({_MONTH_NAMES})\s+(\d{{1,2}})(?:st|nd|rd|th)?",
        normalized.strip(),
    )
    if month_day:
        month_number = _month_number(month_day.group(1))
        day = int(month_day.group(2))
        if month_number is not None and 1 <= day <= 31:
            year = _context_year(time_context)
            return date(year, month_number, day).isoformat()

    month_only = re.fullmatch(rf"(?i){_MONTH_NAMES}", normalized.strip())
    if month_only:
        month_number = _month_number(month_only.group(0))
        if month_number is not None:
            year = _context_year(time_context)
            last_day = calendar.monthrange(year, month_number)[1]
            return date(year, month_number, last_day).isoformat()

    return None


def format_plan_target_date_label(iso_value: str) -> str:
    try:
        parsed = date.fromisoformat(iso_value)
    except ValueError:
        return iso_value
    return f"{parsed.strftime('%B')} {parsed.day}, {parsed.year}"


def _context_year(time_context: Optional[dict[str, Any]]) -> int:
    raw = (time_context or {}).get("date")
    if isinstance(raw, date):
        return raw.year
    if isinstance(raw, str) and raw:
        try:
            return date.fromisoformat(raw[:10]).year
        except ValueError:
            pass
    return date.today().year


def _month_number(token: str) -> Optional[int]:
    cleaned = re.sub(r"\s+", " ", str(token or "")).strip().casefold()
    month_map = {
        "jan": 1,
        "january": 1,
        "feb": 2,
        "february": 2,
        "mar": 3,
        "march": 3,
        "apr": 4,
        "april": 4,
        "may": 5,
        "jun": 6,
        "june": 6,
        "jul": 7,
        "july": 7,
        "aug": 8,
        "august": 8,
        "sep": 9,
        "sept": 9,
        "september": 9,
        "oct": 10,
        "october": 10,
        "nov": 11,
        "november": 11,
        "dec": 12,
        "december": 12,
    }
    for key, value in month_map.items():
        if re.fullmatch(re.escape(key), cleaned):
            return value
    return None
