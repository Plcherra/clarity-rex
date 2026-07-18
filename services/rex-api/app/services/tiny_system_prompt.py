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
    "the app. Prefer honest uncertainty over invented facts."
)

_ACTIONS_BASE = (
    "You are the conversational brain every turn — always reply naturally.\n"
    "Unsupported (email/SMS): honest cannot-send; may offer a draft; append:\n"
    "```rex_action\n"
    '{"action":"unsupported","capability_hint":"send_email"}\n'
    "```"
)

_ACTIONS_MUTATE = (
    "When the user wants an open-thread create/update, append ```rex_action``` "
    "in the same turn with create_open_thread or update_open_thread and payload "
    "{title, summary?, thread_id?}. Prefer update_open_thread with a listed id. "
    "Keep talking in your reply; do not claim updated before confirm."
)


def _mode_guidance(mode: str) -> str:
    if mode == AUTO_PROPOSALS_OFF:
        return "Auto Suggestions: off."
    if mode == AUTO_PROPOSALS_TEXT:
        return "Auto Suggestions: text (say-yes in chat; no confirm card)."
    if mode == AUTO_PROPOSALS_CARD:
        return "Auto Suggestions: card (confirm card)."
    return "Reply naturally."


def _actions_block(mode: str) -> str:
    if mode == AUTO_PROPOSALS_OFF:
        return _ACTIONS_BASE
    return f"{_ACTIONS_BASE}\n{_ACTIONS_MUTATE}"


def build_tiny_system_prompt(
    proposal_settings: AssistantProposalSettings,
    *,
    open_thread_titles_block: str | None = None,
) -> str:
    mode = proposal_settings.mode
    kinds = ", ".join(proposal_settings.enabled_kinds()) or "none"
    gate = (
        f"{_mode_guidance(mode)} "
        f"Kind toggles for auto offers: {kinds}."
    )
    sections = [
        _TRUTH_RULE,
        gate,
        capability_names_prompt(),
        _actions_block(mode),
        CLARITY_KNOWLEDGE_LANGUAGE_PROMPT,
    ]
    if open_thread_titles_block and open_thread_titles_block.strip():
        sections.append(open_thread_titles_block.strip())
    return "\n\n".join(sections)
