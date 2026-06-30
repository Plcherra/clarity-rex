"""Build structured plan candidates from conversational chat messages."""

from __future__ import annotations

import re
from typing import Any, Optional

from app.services.goal_command_formatting import (
    clean_goal_text,
    date_from_text,
    goal_title,
    plan_type,
    relative_date_from_text,
)

_LEADING_INTENT_PATTERN = re.compile(
    r"^\s*(?:"
    r"i(?:'m| am)\s+(?:working on|trying to|planning to|looking to|hoping to|focused on|making progress on)|"
    r"i\s+want\s+to|my\s+(?:focus|priority)\s+is\s+to|"
    r"my\s+next\s+step\s+is\s+to|"
    r"i\s+need\s+to|"
    r"this\s+(?:month|quarter|year)\s+i(?:'m| am)\s+(?:trying|working|focused)"
    r")\s+",
    re.IGNORECASE,
)


def build_plan_candidate_payload(
    message: str,
    *,
    time_context: dict,
    conversation_id: str,
    source_message_id: Optional[str] = None,
) -> dict[str, Any]:
    body = _candidate_body(message)
    target_text = relative_date_from_text(message, time_context=time_context) or (
        date_from_text(message, time_context=time_context)
    )
    metadata = {
        "source": "conversational_plan",
        "prevent_related_merge": True,
    }
    payload: dict[str, Any] = {
        "plan_type": plan_type(body),
        "title": goal_title(body),
        "description": body,
        "desired_outcome": body,
        "priority": 4,
        "source_conversation_id": conversation_id,
        "metadata": metadata,
    }
    if source_message_id:
        payload["source_message_id"] = source_message_id
    if target_text:
        payload["target_date"] = target_text
    return payload


def _candidate_body(message: str) -> str:
    text = clean_goal_text(message)
    text = _LEADING_INTENT_PATTERN.sub("", text).strip(" .,!?:;")
    return text or clean_goal_text(message)
