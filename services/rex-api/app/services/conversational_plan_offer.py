"""Detect conversational plan/goal save offers and bare affirmations."""

from __future__ import annotations

import re
from typing import Any, Optional

_PLAN_SAVE_OFFER_MARKERS = (
    "as a goal in goals if you want",
    "just say the word",
    "save as a new plan in goals",
    "should i save that as",
    "want me to save that as",
    "save that as a goal",
    "save this as a goal",
    "save it as a goal",
    "as a goal if you want",
)

_QUOTED_GOAL_TITLE = re.compile(
    r"""I can save ["']([^"']+)["'] as a goal""",
    re.IGNORECASE,
)

_AFFIRMATIONS = frozenset(
    {
        "yes",
        "yeah",
        "yep",
        "sure",
        "ok",
        "okay",
        "please",
        "yes please",
        "yeah please",
        "yep please",
        "sure please",
        "ok please",
        "okay please",
        "do it",
        "go ahead",
        "save it",
        "save that",
    }
)

_DECLINES = frozenset({"no", "nope", "nah", "don't", "do not", "cancel"})


def plan_offer_state_from_history(
    conversation_history: list[dict],
) -> dict[str, Any]:
    """Return offered/declined/topic/title from recent assistant goal offers."""
    offered = False
    declined = False
    offered_title: Optional[str] = None
    topic_message: Optional[str] = None
    offer_index = -1

    for index, item in enumerate(conversation_history):
        role = str(item.get("role") or "")
        content = str(item.get("content") or "").strip()
        if not content:
            continue
        lower = content.lower()
        if role == "assistant" and _looks_like_goal_offer(lower):
            offered = True
            offer_index = index
            match = _QUOTED_GOAL_TITLE.search(content)
            offered_title = match.group(1).strip() if match else None
            topic_message = _prior_substantive_user_message(
                conversation_history,
                before_index=index,
            )
            if offered_title is None and topic_message:
                offered_title = topic_message.strip()[:120]

    if offer_index >= 0:
        for item in conversation_history[offer_index + 1 :]:
            if str(item.get("role") or "") != "user":
                continue
            normalized = _normalize_reply(str(item.get("content") or ""))
            if normalized in _DECLINES:
                declined = True
            if normalized in _AFFIRMATIONS:
                declined = False

    return {
        "offered": offered,
        "declined": declined,
        "topic_message": topic_message,
        "offered_title": offered_title,
    }


def is_plan_offer_affirmation(message: str, offer: dict[str, Any]) -> bool:
    if not offer.get("offered") or offer.get("declined"):
        return False
    return _normalize_reply(message) in _AFFIRMATIONS


def is_plan_offer_decline(message: str, offer: dict[str, Any]) -> bool:
    if not offer.get("offered"):
        return False
    return _normalize_reply(message) in _DECLINES


def _looks_like_goal_offer(lowered: str) -> bool:
    if "goal" not in lowered and "plan" not in lowered:
        return False
    return any(marker in lowered for marker in _PLAN_SAVE_OFFER_MARKERS)


def _prior_substantive_user_message(
    conversation_history: list[dict],
    *,
    before_index: int,
) -> Optional[str]:
    for item in reversed(conversation_history[:before_index]):
        if str(item.get("role") or "") != "user":
            continue
        content = str(item.get("content") or "").strip()
        if len(content) < 8:
            continue
        if _normalize_reply(content) in _AFFIRMATIONS | _DECLINES:
            continue
        return content
    return None


def _normalize_reply(value: str) -> str:
    cleaned = re.sub(r"[^\w\s']+", " ", value.lower())
    return " ".join(cleaned.split())
