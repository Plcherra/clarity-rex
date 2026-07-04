from __future__ import annotations

import calendar
import re
from datetime import date, datetime
from typing import Optional

_EQUIPMENT_HINT = re.compile(
    r"\b(?:ram|storage|ssd|nvme|disk|drive|memory|tb|terabyte|gb)\b",
    re.IGNORECASE,
)
_PURCHASE_VERB = re.compile(
    r"\b(?:get|buy|upgrade|install|pick\s+up|add|purchase)\b",
    re.IGNORECASE,
)
_META_INSTRUCTION_BODY = re.compile(
    r"^(?:a\s+)?(?:(?:goal|commitment)(?:\s*/\s*(?:goal|commitment))?|"
    r"(?:goal|commitment)\s+or\s+(?:goal|commitment))\.?$",
    re.IGNORECASE,
)
_AFFIRMATION_PATTERN = re.compile(
    r"^(?:yes(?:\s+please)?|yeah|yep|sure|ok(?:ay)?|confirmed?|please)\.?$",
    re.IGNORECASE,
)
_GOAL_PREFIX_ONLY = re.compile(
    r"^(?:yes\s+but\s+)?(?:the\s+)?(?:goal|commitment)(?:\s*/\s*(?:goal|commitment))?"
    r"\s+is\s*:?\s*$",
    re.IGNORECASE,
)


def is_meta_instruction_body(body: str) -> bool:
    cleaned = re.sub(r"\s+", " ", str(body or "")).strip(" .")
    if not cleaned:
        return True
    if _META_INSTRUCTION_BODY.fullmatch(cleaned):
        return True
    lowered = cleaned.casefold()
    if lowered in {
        "goal",
        "commitment",
        "a goal",
        "a commitment",
        "be a goal",
        "be a commitment",
        "goal or commitment",
        "a goal or commitment",
        "be a goal or commitment",
        "goal/commitment",
        "a goal/commitment",
        "be a goal/commitment",
    }:
        return True
    if re.fullmatch(
        r"(?:be\s+)?(?:a\s+)?(?:goal|commitment)(?:\s*/\s*(?:goal|commitment))?",
        lowered,
    ):
        return True
    return len(cleaned) < 8


def looks_like_equipment_goal(text: str) -> bool:
    cleaned = re.sub(r"\s+", " ", str(text or "")).strip(" .")
    if len(cleaned) < 6:
        return False
    if not _EQUIPMENT_HINT.search(cleaned):
        return False
    return bool(_PURCHASE_VERB.search(cleaned) or re.search(r"\d", cleaned))


def clean_purchase_clause(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", str(text or "")).strip(" .,:;")
    cleaned = re.sub(r"^(?:to\s+)?", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"^(?:buy\s+or\s+get|get|buy|upgrade|install)\s+", "", cleaned, flags=re.I)
    if cleaned and not cleaned[0].isupper():
        cleaned = cleaned[:1].upper() + cleaned[1:]
    return cleaned


_NUMBERED_ITEM_PREFIX = re.compile(r"^\d+[.)]?\s+", re.IGNORECASE)


def normalize_equipment_goal_title(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", str(text or "")).strip(" .")
    cleaned = _NUMBERED_ITEM_PREFIX.sub("", cleaned).strip()
    cleaned = clean_purchase_clause(cleaned)
    if not cleaned:
        return "Untitled"
    if not _PURCHASE_VERB.search(cleaned):
        cleaned = f"Get {cleaned}"
    return cleaned


def expand_goal_save_items(
    *,
    title: str | None = None,
    description: str | None = None,
    desired_outcome: str | None = None,
) -> list[str]:
    for source in (description, desired_outcome, title):
        text = re.sub(r"\s+", " ", str(source or "")).strip(" .")
        if not text:
            continue
        items = split_compound_goal_bodies(text)
        if len(items) >= 2:
            return items
    return []


def split_numbered_goal_bodies(text: str) -> list[str]:
    cleaned = re.sub(r"\s+", " ", str(text or "")).strip(" .")
    if not cleaned:
        return []

    body = re.sub(r"^\d+\s+goals?[.:]?\s*", "", cleaned, flags=re.IGNORECASE)
    item_start = r"\d+[.)]?\s+(?:buy|get|upgrade|install|purchase|add)\b"
    if not re.search(item_start, body, re.IGNORECASE):
        if re.search(r"\d+[.)]\s+", body):
            parts = [
                part.strip(" .")
                for part in re.split(r"\d+[.)]\s+", body, flags=re.IGNORECASE)
            ]
            items = [
                normalize_equipment_goal_title(part)
                for part in parts
                if part and _looks_like_goal_clause(part)
            ]
            if len(items) >= 2:
                return items
        return []

    parts = re.split(
        rf"(?<=\.)\s*(?={item_start})|(?<=\S)\s+(?={item_start})",
        body,
        flags=re.IGNORECASE,
    )
    items = [
        normalize_equipment_goal_title(part)
        for part in parts
        if part and _looks_like_goal_clause(part)
    ]
    if len(items) >= 2:
        return items
    return []


def _looks_like_goal_clause(text: str) -> bool:
    cleaned = re.sub(r"\s+", " ", str(text or "")).strip(" .")
    if len(cleaned) < 4:
        return False
    if re.fullmatch(r"\d+\s*goals?", cleaned, re.IGNORECASE):
        return False
    if looks_like_equipment_goal(cleaned):
        return True
    return bool(_PURCHASE_VERB.search(cleaned) and re.search(r"\d", cleaned))


def split_compound_goal_bodies(text: str) -> list[str]:
    cleaned = re.sub(r"\s+", " ", str(text or "")).strip(" .")
    if not cleaned:
        return []

    numbered = split_numbered_goal_bodies(cleaned)
    if numbered:
        return numbered

    if re.search(r"\band\b", cleaned, re.IGNORECASE):
        parts = [
            part.strip(" .")
            for part in re.split(r"\s+and\s+", cleaned, flags=re.IGNORECASE)
        ]
        items = [
            normalize_equipment_goal_title(part)
            for part in parts
            if looks_like_equipment_goal(part)
        ]
        if len(items) >= 2:
            return items

    if looks_like_equipment_goal(cleaned):
        return [normalize_equipment_goal_title(cleaned)]
    if _looks_like_goal_clause(cleaned):
        return [normalize_equipment_goal_title(cleaned)]
    return []


def is_affirmation_or_goal_prefix(message: str) -> bool:
    cleaned = re.sub(r"\s+", " ", str(message or "")).strip()
    return bool(
        _AFFIRMATION_PATTERN.fullmatch(cleaned)
        or _GOAL_PREFIX_ONLY.fullmatch(cleaned)
    )


def substantive_goal_from_history(conversation_history: list[dict]) -> Optional[str]:
    for item in reversed(conversation_history[-10:]):
        if item.get("role") != "user":
            continue
        content = str(item.get("content") or "").strip()
        if not content or is_affirmation_or_goal_prefix(content):
            continue
        items = split_compound_goal_bodies(content)
        if items:
            return content
        if looks_like_equipment_goal(content):
            return content
    return None


def target_date_for_message(message: str, *, time_context: Optional[dict]) -> Optional[str]:
    if not re.search(r"\b(?:next|this)\s+month\b", message, re.IGNORECASE):
        return None
    if re.search(r"\bthis\s+month\b", message, re.IGNORECASE):
        return _last_day_of_month(_context_date(time_context), offset_months=0)
    return _last_day_of_month(_context_date(time_context), offset_months=1)


def _context_date(time_context: Optional[dict]) -> date:
    raw = (time_context or {}).get("date")
    if isinstance(raw, date):
        return raw
    if isinstance(raw, str) and raw:
        try:
            return date.fromisoformat(raw[:10])
        except ValueError:
            pass
    return datetime.utcnow().date()


def _last_day_of_month(base: date, *, offset_months: int) -> str:
    month_index = base.month - 1 + offset_months
    year = base.year + month_index // 12
    month = month_index % 12 + 1
    last_day = calendar.monthrange(year, month)[1]
    month_name = datetime(year, month, 1).strftime("%B")
    return f"{month_name} {last_day}"


_GOALS_INVENTORY_PATTERNS = (
    re.compile(
        r"\bwhat\s+(?:goals?|commitments?|plans?)\s+do\s+(?:we|i)\s+have\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\bwhat\s+do\s+(?:you|we|i)\s+have\s+saved\s+on\s+"
        r"(?:goals?|commitments?|plans?)\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\bwhat\s+kind\s+of\s+(?:goals?|commitments?|plans?)\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\bwhat\s+(?:saved\s+)?(?:goals?|commitments?|plans?)\s+"
        r"(?:do\s+(?:we|i)\s+have|are\s+(?:there|saved))\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\b(?:list|show|tell me)\s+(?:me\s+)?(?:my|our)\s+"
        r"(?:saved\s+)?(?:goals?|commitments?|plans?)\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\bhow many\s+(?:goals?|commitments?|plans?)\s+do\s+(?:we|i)\s+have\b",
        re.IGNORECASE,
    ),
)


def is_goals_inventory_query(message: str) -> bool:
    cleaned = re.sub(r"\s+", " ", str(message or "")).strip()
    if not cleaned:
        return False
    return any(pattern.search(cleaned) for pattern in _GOALS_INVENTORY_PATTERNS)


def goals_inventory_scope(message: str) -> str:
    return "goals"
