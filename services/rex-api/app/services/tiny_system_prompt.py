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

_PHASE_C_ACTIONS = (
    "You are the conversational brain every turn — always reply naturally "
    "(just_chat). Body functions may attach beside your reply; they must not "
    "replace conversation.\n"
    "Unsupported (email/SMS): honest cannot-send; may offer a draft; append:\n"
    "```rex_action\n"
    '{"action":"unsupported","capability_hint":"send_email"}\n'
    "```\n"
    "For open-thread habits also append ```rex_action``` with "
    "create_open_thread or update_open_thread and payload "
    "{title, summary?, thread_id?}. Prefer update_open_thread with a listed id "
    "when changing an existing thread. Keep talking in your reply; do not "
    "claim updated before confirm/apply."
)


def _mode_guidance(mode: str) -> str:
    if mode == AUTO_PROPOSALS_OFF:
        return (
            "Off: Auto Suggestions are off. Soft desires (\"I want to wake at "
            "6am\") → coach only, still emit rex_action if relevant but expect "
            "no auto card. Straight commands (\"update my 3am thread to 5am\") "
            "→ emit update_open_thread; body may apply. Keep conversing."
        )
    if mode == AUTO_PROPOSALS_TEXT:
        return (
            "Text Auto Suggestions on: soft open-thread intents should emit "
            "create/update rex_action; body may ask say-yes. Keep conversing."
        )
    if mode == AUTO_PROPOSALS_CARD:
        return (
            "Card Auto Suggestions on: soft open-thread intents should emit "
            "create/update rex_action; body may show a confirm card. Keep "
            "conversing in your reply."
        )
    return "Keep conversing; do not invent silent saves."


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
        f"{_mode_guidance(mode)}"
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
