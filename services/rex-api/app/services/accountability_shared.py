import re
from datetime import date, datetime, timezone
from typing import Any, Optional

from app.models.accountability import AccountabilitySourceRef


RULE_CATEGORY_TERMS = {
    "transport": {"cab", "lyft", "ride", "rideshare", "taxi", "uber"},
    "food_delivery": {
        "delivery",
        "doordash",
        "door dash",
        "grubhub",
        "ubereats",
        "uber eats",
    },
    "coffee": {"coffee", "dunkin", "latte", "starbucks"},
    "rent": {"landlord", "lease", "rent"},
}
GENERIC_RULE_TERMS = {
    "budget",
    "cap",
    "caps",
    "delivery",
    "doordash",
    "door dash",
    "grocery",
    "groceries",
    "lyft",
    "netflix",
    "rent",
    "subscription",
    "subscriptions",
    "uber",
}
VIOLATION_ACTION_TERMS = {
    "bought",
    "grabbed",
    "ordered",
    "paid",
    "renewed",
    "spent",
    "took",
    "used",
}
NEGATION_TERMS = {
    "avoid",
    "cancel",
    "canceled",
    "delete",
    "deleted",
    "didnt",
    "didn't",
    "dont",
    "don't",
    "no",
    "not",
    "stop",
    "stopped",
    "without",
}
COMPLETION_TERMS = {
    "completed",
    "did",
    "done",
    "finished",
    "kept",
    "made",
    "sent",
    "submitted",
    "went",
    "worked",
}
FOLLOW_UP_AGE_DAYS = 7
PLAN_STALL_DAYS = 14
UPCOMING_MILESTONE_DAYS = 7
PATTERN_LOOKBACK_DAYS = 30
PATTERN_MIN_OCCURRENCES = 3
SHORT_MEANINGFUL_TERMS = {"app", "ios", "rex"}
PROGRESS_TERMS = {
    "advanced",
    "built",
    "closed",
    "finished",
    "fixed",
    "improved",
    "launched",
    "made",
    "moved",
    "progress",
    "shipped",
    "started",
    "worked",
}
PATTERN_CATEGORIES = {
    "delivery_spending": {
        "label": "delivery food",
        "terms": {
            "delivery",
            "doordash",
            "door dash",
            "grubhub",
            "ubereats",
            "uber eats",
        },
    },
    "transport_spending": {
        "label": "rideshare",
        "terms": {"cab", "lyft", "rideshare", "taxi", "uber"},
    },
    "coffee_spending": {
        "label": "coffee spending",
        "terms": {"coffee", "dunkin", "latte", "starbucks"},
    },
    "missed_commitments": {
        "label": "missed commitments",
        "terms": {"missed", "overdue", "skipped", "didn't do", "did not do", "forgot"},
    },
    "dating_anxiety": {
        "label": "dating hesitation",
        "terms": {
            "anxious",
            "date",
            "dating",
            "hesitated",
            "nervous",
            "passive",
            "submissive",
        },
    },
}


def contains_term(text: str, term: str) -> bool:
    if " " in term:
        return term in text
    return bool(re.search(rf"\b{re.escape(term)}\b", text))


def normalize_text(value: Any) -> str:
    text = str(value or "").casefold()
    text = text.replace("’", "'")
    text = text.replace("-", " ")
    return re.sub(r"\s+", " ", text).strip()


def tokens(text: str) -> list[str]:
    return re.findall(r"[a-z0-9']+", normalize_text(text))


def term_start_indexes(tokens_: list[str], term_tokens: list[str]) -> list[int]:
    if not tokens_ or not term_tokens:
        return []
    width = len(term_tokens)
    return [
        index
        for index in range(0, len(tokens_) - width + 1)
        if tokens_[index : index + width] == term_tokens
    ]


def current_time(time_context: Optional[dict[str, Any]]) -> datetime:
    parsed = parse_datetime((time_context or {}).get("iso_timestamp"))
    return parsed or datetime.now(timezone.utc)


def parse_datetime(value: Any) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        parsed = value
    else:
        text = str(value).strip()
        if not text:
            return None
        try:
            parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return None

    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def parse_date(value: Any) -> Optional[date]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value

    text = str(value).strip()
    if not text:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).date()
    except ValueError:
        try:
            return date.fromisoformat(text)
        except ValueError:
            return None


def pattern_record_time(record: dict) -> Optional[datetime]:
    for field in ("occurred_at", "created_at", "updated_at", "last_accessed_at"):
        parsed = parse_datetime(record.get(field))
        if parsed is not None:
            return parsed
    return None


def is_recent_pattern_record(record: dict, current_time_: datetime) -> bool:
    timestamp = pattern_record_time(record)
    if timestamp is None:
        return True
    age_days = (current_time_ - timestamp).days
    return age_days <= PATTERN_LOOKBACK_DAYS


def meaningful_terms(text: str) -> set[str]:
    stop_terms = {
        "about",
        "active",
        "again",
        "checkpoint",
        "deadline",
        "goal",
        "need",
        "open",
        "other",
        "plan",
        "task",
        "that",
        "the",
        "this",
        "will",
        "with",
    }
    return {
        token
        for token in tokens(text)
        if (len(token) >= 4 or token in SHORT_MEANINGFUL_TERMS)
        and token not in stop_terms
    }


def bounded_int(value: Any, *, default: int, minimum: int, maximum: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = default
    return max(minimum, min(parsed, maximum))


def commitment_source_ref(commitment: dict) -> AccountabilitySourceRef:
    return AccountabilitySourceRef(
        source_type="commitment",
        source_id=str(commitment.get("id")) if commitment.get("id") else None,
        title=str(commitment.get("title") or "Commitment"),
        excerpt=str(commitment.get("commitment_text") or "") or None,
    )


def plan_source_ref(plan: dict) -> AccountabilitySourceRef:
    return AccountabilitySourceRef(
        source_type="plan",
        source_id=str(plan.get("id")) if plan.get("id") else None,
        title=str(plan.get("title") or "Plan"),
        excerpt=str(plan.get("description") or plan.get("desired_outcome") or "")
        or None,
    )


def milestone_source_ref(milestone: dict) -> AccountabilitySourceRef:
    return AccountabilitySourceRef(
        source_type="plan_milestone",
        source_id=str(milestone.get("id")) if milestone.get("id") else None,
        title=str(milestone.get("title") or "Milestone"),
        excerpt=str(milestone.get("description") or "") or None,
    )
