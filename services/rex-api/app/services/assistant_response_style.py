"""Resolve assistant response style and token limits per turn."""

from __future__ import annotations

import re
from typing import Optional

from app.services.assistant_proposal_settings import (
    RESPONSE_STYLE_BALANCED,
    RESPONSE_STYLE_CONCISE,
    RESPONSE_STYLE_DETAILED,
    AssistantProposalSettings,
)
from app.services.rex_channel import RexBrainChannel

_STYLE_ORDER = (
    RESPONSE_STYLE_CONCISE,
    RESPONSE_STYLE_BALANCED,
    RESPONSE_STYLE_DETAILED,
)

_MAX_TOKENS_BY_STYLE = {
    RESPONSE_STYLE_CONCISE: 450,
    RESPONSE_STYLE_BALANCED: 1000,
    RESPONSE_STYLE_DETAILED: 2000,
}

_DETAILED_OVERRIDE_PATTERNS = (
    re.compile(r"\b(?:be|go|get)\s+detailed\b", re.I),
    re.compile(r"\bfull(?:\s+|-)breakdown\b", re.I),
    re.compile(r"\bwalk me through\b", re.I),
    re.compile(r"\bexplain (?:this|it|everything)(?:\s+in detail)?\b", re.I),
    re.compile(r"\bin detail\b", re.I),
    re.compile(r"\bmore detail\b", re.I),
    re.compile(r"\blong(?:er)?(?:\s+|-)answer\b", re.I),
)


def requests_detailed_response(message: str) -> bool:
    normalized = " ".join(str(message or "").split())
    if not normalized:
        return False
    return any(pattern.search(normalized) for pattern in _DETAILED_OVERRIDE_PATTERNS)


def normalize_response_style(raw: Optional[str]) -> str:
    style = str(raw or RESPONSE_STYLE_BALANCED).strip().lower()
    if style in _MAX_TOKENS_BY_STYLE:
        return style
    return RESPONSE_STYLE_BALANCED


def shift_style_shorter(style: str) -> str:
    normalized = normalize_response_style(style)
    index = _STYLE_ORDER.index(normalized)
    return _STYLE_ORDER[max(index - 1, 0)]


def effective_response_style(
    message: str,
    *,
    proposal_settings: AssistantProposalSettings,
    channel: RexBrainChannel = RexBrainChannel.CHAT,
) -> str:
    if requests_detailed_response(message):
        return RESPONSE_STYLE_DETAILED

    style = normalize_response_style(proposal_settings.response_style)
    if channel == RexBrainChannel.VOICE:
        return shift_style_shorter(style)
    return style


def max_response_tokens_for_style(style: str) -> int:
    return _MAX_TOKENS_BY_STYLE[normalize_response_style(style)]
