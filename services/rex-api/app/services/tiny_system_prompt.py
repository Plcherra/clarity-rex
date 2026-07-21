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
    "When the user wants an open-thread create/update — including after they "
    "say yes to your offer — append ```rex_action``` in the same turn with "
    "create_open_thread or update_open_thread. "
    "Payload MUST include a non-empty title (the new habit title, e.g. "
    '"Wake at 5:30am"). Prefer update_open_thread with a listed thread_id. '
    "Optional: summary. Keep talking; do not claim updated before confirm."
)

_ACTIONS_MUTATE_CARD = (
    "When the user asks to create/update an open thread or change wake/sleep/"
    "habit time — and open threads are listed — you MUST append ```rex_action``` "
    "in the same turn with update_open_thread (preferred, with listed thread_id) "
    "or create_open_thread. "
    "Payload MUST include a non-empty title (e.g. \"Wake at 5am\"). "
    "The body shows a confirm card — never only talk about updating in prose. "
    "Do not claim updated before they confirm on the card."
)

_ACTIONS_MUTATE_OFF = (
    "Open-thread create/update: when the user gives a clear change command "
    "(e.g. \"update my thread to 5am\", \"change my sleep to 6am\", "
    "\"I want to update my waking time to 5am\"), append ```rex_action``` with "
    "create_open_thread or update_open_thread, payload with non-empty title "
    '(required), summary?, thread_id?, and "explicit":true '
    "(do not set auto:true). Prefer update_open_thread with a listed id. "
    "Do not propose for vague desires without a concrete change "
    '(e.g. "I wish I woke earlier"). '
    "Keep talking; body uses brief say-yes confirm (no card). "
    "Do not claim updated before confirm."
)


def _mode_guidance(mode: str) -> str:
    if mode == AUTO_PROPOSALS_OFF:
        return (
            "Auto Suggestions: off "
            "(no auto proposals; explicit commands use say-yes Text confirm)."
        )
    if mode == AUTO_PROPOSALS_TEXT:
        return "Auto Suggestions: text (say-yes in chat; no confirm card)."
    if mode == AUTO_PROPOSALS_CARD:
        return "Auto Suggestions: card (confirm card)."
    return "Reply naturally."


def _actions_block(mode: str) -> str:
    if mode == AUTO_PROPOSALS_OFF:
        return f"{_ACTIONS_BASE}\n{_ACTIONS_MUTATE_OFF}"
    if mode == AUTO_PROPOSALS_CARD:
        return f"{_ACTIONS_BASE}\n{_ACTIONS_MUTATE_CARD}"
    return f"{_ACTIONS_BASE}\n{_ACTIONS_MUTATE}"


def build_tiny_system_prompt(
    proposal_settings: AssistantProposalSettings,
    *,
    open_thread_titles_block: str | None = None,
) -> str:
    mode = proposal_settings.mode
    if mode == AUTO_PROPOSALS_OFF:
        kinds = ", ".join(proposal_settings.enabled_kind_toggles()) or "none"
        kinds_label = f"Kind toggles for explicit commands: {kinds}."
    else:
        kinds = ", ".join(proposal_settings.enabled_kinds()) or "none"
        kinds_label = f"Kind toggles for auto offers: {kinds}."
    gate = f"{_mode_guidance(mode)} {kinds_label}"
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
