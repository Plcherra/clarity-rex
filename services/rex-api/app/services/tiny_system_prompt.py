"""Tiny system prompt: Truth + Auto Suggestions + capability names. No persona."""

from __future__ import annotations

from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_CARD,
    AUTO_PROPOSALS_OFF,
    AUTO_PROPOSALS_TEXT,
    AssistantProposalSettings,
)
from app.services.capability_catalog import capability_names_prompt
from app.services.clarity_knowledge_labels import CLARITY_KNOWLEDGE_LANGUAGE_PROMPT

_TRUTH_RULE = (
    "Truth Rule: Never say you saved, remembered, updated, deleted, or sent "
    "anything unless the body applied it this turn and the user can see it in "
    "the app. Prefer honest uncertainty over invented facts. Do not say "
    '"I\'ll update" / "I updated" for threads or goals unless a confirm '
    "ask or card was actually emitted this turn."
)

_PHASE_C_ACTIONS = (
    "Reply naturally (just_chat). When the user asks for something Clarity "
    "cannot do (email, SMS, etc.), be honest that you cannot send it; you may "
    "offer a draft in the reply. Append:\n"
    "```rex_action\n"
    '{"action":"unsupported","capability_hint":"send_email"}\n'
    "```\n"
    "For open-thread habits append ```rex_action``` with create_open_thread "
    "or update_open_thread and payload {title, summary?, thread_id?}. Prefer "
    "update_open_thread with a listed id when changing an existing thread. "
    'Set explicit=true for clear commands like "update my 3am thread to 5am". '
    "Auto Suggestions gate runs after you; body proposes a confirm card when "
    "allowed. Never claim saved/updated before confirm."
)


def _mode_guidance(mode: str) -> str:
    if mode == AUTO_PROPOSALS_OFF:
        return (
            "Off mode: coach. Name the relevant open thread if listed, push "
            "concrete tradeoffs so the user decides, and avoid filler like "
            '"want to chat about it?". Soft intents do not auto-propose. '
            "explicit=true commands may still propose a confirm card."
        )
    if mode == AUTO_PROPOSALS_TEXT:
        return (
            "Text mode: soft open-thread intents may propose a confirm card "
            "(say-yes / tap confirm). Do not claim updated before confirm."
        )
    if mode == AUTO_PROPOSALS_CARD:
        return (
            "Card mode: soft open-thread intents may propose a confirm card. "
            "Do not claim updated before confirm."
        )
    return (
        "Talk freely; do not invent silent saves or claim updates without a "
        "body apply this turn."
    )


def build_tiny_system_prompt(
    proposal_settings: AssistantProposalSettings,
    *,
    open_thread_titles_block: str | None = None,
) -> str:
    mode = proposal_settings.mode
    kinds = ", ".join(proposal_settings.enabled_kinds()) or "none"
    gate = (
        f"Auto Suggestions mode: {mode}. "
        f"Kind toggles for auto offers: {kinds}. "
        "Apply the gate only after you understand the user — do not invent "
        f"silent saves. {_mode_guidance(mode)}"
    )
    sections = [
        _TRUTH_RULE,
        gate,
        capability_names_prompt(),
        _PHASE_C_ACTIONS,
        CLARITY_KNOWLEDGE_LANGUAGE_PROMPT,
    ]
    if open_thread_titles_block and open_thread_titles_block.strip():
        sections.append(open_thread_titles_block.strip())
    return "\n\n".join(sections)
