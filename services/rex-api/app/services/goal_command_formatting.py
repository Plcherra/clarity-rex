"""Title, type, date, and response helpers for goal commands."""

from __future__ import annotations

import re
from typing import Any, Optional

from app.services.goal_command_parsing import target_date_for_message
from app.services.clarity_knowledge_labels import (
    reclassified_from_memory_message,
    reclassified_without_memory_message,
)
from app.services.goal_command_types import GoalCommand
from app.services.memory_date_normalizer import MemoryDateNormalizer

_DATE_NORMALIZER = MemoryDateNormalizer()

_MONTH_TOKEN = (
    r"(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|"
    r"jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|"
    r"dec(?:ember)?)"
)
_DAY_TOKEN = r"\d{1,2}(?:st|nd|rd|th)?"
_ORDINAL_DAY_TOKEN = (
    r"(?:first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|"
    r"eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|seventeenth|"
    r"eighteenth|nineteenth|twentieth|twenty[\s-]?first|twenty[\s-]?second|"
    r"twenty[\s-]?third|twenty[\s-]?fourth|twenty[\s-]?fifth|twenty[\s-]?sixth|"
    r"twenty[\s-]?seventh|twenty[\s-]?eighth|twenty[\s-]?ninth|thirtieth|"
    r"thirty[\s-]?first)"
)
_DUE_DATE_TOKEN = (
    rf"(?:{_MONTH_TOKEN}(?:\s+(?:{_DAY_TOKEN}|{_ORDINAL_DAY_TOKEN}))?|"
    rf"{_DAY_TOKEN}|{_ORDINAL_DAY_TOKEN})"
)

_OBLIGATION_ACTION_PATTERN = re.compile(
    r"\bi\s+(?:need|have)\s+to\s+"
    r"(?P<action>(?:upgrade|install|buy|get|replace|purchase|add|pick\s+up)\b.+)",
    re.IGNORECASE,
)
_DUE_PATTERN = re.compile(
    rf"\b(?:on|by)\s+(?:the\s+)?(?P<date>{_DUE_DATE_TOKEN})\b",
    re.IGNORECASE,
)
_RELATIVE_TIME_PATTERN = re.compile(
    r"\b(?P<relative>(?:next|this)\s+(?:month|week|quarter|year))\b",
    re.IGNORECASE,
)


def clean_goal_text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip(" .")


def goal_title(text: str) -> str:
    cleaned = clean_goal_text(text) or "Untitled"
    return cleaned[:1].upper() + cleaned[1:]


def plan_type(text: str) -> str:
    lowered = text.casefold()
    if any(term in lowered for term in ("save", "$", "money", "budget")):
        return "finance"
    if any(term in lowered for term in ("work", "job", "career")):
        return "career"
    if any(term in lowered for term in ("health", "gym", "work out")):
        return "health"
    return "personal"


def date_from_text(text: str, *, time_context: dict) -> Optional[str]:
    match = _DUE_PATTERN.search(text)
    if not match:
        return None
    return _DATE_NORMALIZER.normalize(
        match.group("date"),
        time_context=time_context,
    )


def relative_date_from_text(
    text: str,
    *,
    time_context: Optional[dict] = None,
) -> Optional[str]:
    month_target = target_date_for_message(text, time_context=time_context)
    if month_target:
        return month_target
    match = _RELATIVE_TIME_PATTERN.search(text)
    if match is None:
        return None
    relative = match.group("relative")
    return relative[:1].upper() + relative[1:].lower()


def extract_obligation_action(message: str) -> Optional[str]:
    match = _OBLIGATION_ACTION_PATTERN.search(message)
    if match is None:
        return None
    return clean_goal_text(match.group("action"))


def combined_recent_text(message: str, conversation_history: list[dict]) -> str:
    recent = " ".join(
        str(item.get("content") or "")
        for item in conversation_history[-8:]
    )
    return f"{message} {recent}".strip()


def recent_user_content(conversation_history: list[dict]) -> Optional[str]:
    for message in reversed(conversation_history):
        if message.get("role") == "user":
            return str(message.get("content") or "")
    return None


def clean_reclassified_body(value: str) -> str:
    cleaned = clean_goal_text(value)
    cleaned = re.sub(r"\b(\d+)\s*to\b", r"\1GB to", cleaned, flags=re.I)
    cleaned = re.sub(r"\b(\d+)\s*or\b", r"\1GB or", cleaned, flags=re.I)
    cleaned = re.sub(r"\bterab\b", "TB", cleaned, flags=re.I)
    cleaned = re.sub(r"\b1terab\b", "1TB", cleaned, flags=re.I)
    cleaned = re.sub(r"\b2terab\b", "2TB", cleaned, flags=re.I)
    return cleaned.strip(" .")


def reclassification_response(
    command: GoalCommand,
    *,
    archived_record: Optional[dict],
    total_goals: int = 1,
    titles: Optional[list[str]] = None,
) -> Optional[str]:
    joined = ", ".join(titles) if titles else None
    if archived_record is None:
        return reclassified_without_memory_message(
            title=command.title,
            total=total_goals,
            titles=joined,
        )
    return reclassified_from_memory_message(
        title=command.title,
        total=total_goals,
        titles=joined,
    )


def archived_memory_record(
    archived_record: Optional[dict],
) -> Optional[list[dict]]:
    if archived_record is None:
        return None
    return [
        {
            "kind": "long_term_memory",
            "type": archived_record.get("memory_type") or "fact",
            "action": "archived",
            "id": archived_record.get("id"),
            "title": str(archived_record.get("content") or "")[:80],
            "metadata": {"source": "memory_to_goal_reclassification"},
        }
    ]


def target_date_for_combined_text(
    message: str,
    conversation_history: list[dict],
    *,
    time_context: dict,
) -> Optional[str]:
    combined = combined_recent_text(message, conversation_history)
    return (
        target_date_for_message(combined, time_context=time_context)
        or relative_date_from_text(combined, time_context=time_context)
        or date_from_text(combined, time_context=time_context)
    )
