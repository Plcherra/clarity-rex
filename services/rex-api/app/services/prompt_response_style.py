"""System prompt rules for assistant response length/style."""

from __future__ import annotations

from app.services.assistant_proposal_settings import (
    RESPONSE_STYLE_BALANCED,
    RESPONSE_STYLE_CONCISE,
    RESPONSE_STYLE_DETAILED,
)
from app.services.assistant_response_style import normalize_response_style
from app.services.clarity_knowledge_labels import CLARITY_KNOWLEDGE_LANGUAGE_PROMPT

_STYLE_RULES = {
    RESPONSE_STYLE_CONCISE: (
        "Response style: concise.\n"
        "Lead with the direct answer in the first sentence.\n"
        "Keep the full reply short (about 2-4 sentences).\n"
        "Do not use markdown headings (no ###).\n"
        "Use at most one short bullet list with 3 items or fewer.\n"
        "If a longer plan would help, give the headline recommendation now and "
        "offer a fuller breakdown only if the user asks."
    ),
    RESPONSE_STYLE_BALANCED: (
        "Response style: balanced.\n"
        "Start with a short direct answer, then add one compact structured "
        "section only when it materially helps.\n"
        "Avoid long essays and avoid multiple numbered sections unless the user "
        "asked for a full plan.\n"
        "Prefer plain paragraphs over markdown headings."
    ),
    RESPONSE_STYLE_DETAILED: (
        "Response style: detailed.\n"
        "You may use headings, numbered steps, and fuller breakdowns when the "
        "user needs a complete plan or analysis.\n"
        "Stay organized and practical; do not pad with generic advice."
    ),
}


def response_style_prompt(style: str) -> str:
    normalized = normalize_response_style(style)
    rules = _STYLE_RULES[normalized]
    return f"{rules}\n\n{CLARITY_KNOWLEDGE_LANGUAGE_PROMPT}"
