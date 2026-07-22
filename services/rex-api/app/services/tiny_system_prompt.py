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

_TITLE_RULE = (
    'Title must be a short habit label (e.g. "Wake at 5am"), never the user\'s '
    "full sentence or a paste of their message."
)

_JSON_RULE = (
    "Use only valid JSON inside ```rex_action```. Canonical shape: "
    '{"action":"update_open_thread","payload":{"thread_id":"<listed-id>",'
    '"title":"Wake at 5:15am","summary":"Work on Clarity every morning"}}.'
)

_ACTIONS_MUTATE = (
    "When the user wants an open-thread create/update — including after they "
    "say yes to your offer — append ```rex_action``` in the same turn with "
    "create_open_thread or update_open_thread. "
    f"Payload MUST include a non-empty title. {_TITLE_RULE} "
    "Prefer update_open_thread with a listed thread_id when changing an "
    "existing thread. Include summary when the user gives reminder details, "
    "the reason it matters, or a renamed purpose. "
    f"{_JSON_RULE} Keep talking; do not claim updated before confirm."
)

_ACTIONS_MUTATE_CARD = (
    "When the user asks to create/update an open thread or change wake/sleep/"
    "habit time — and open threads are listed — you MUST append ```rex_action``` "
    "in the same turn with update_open_thread (preferred, with listed thread_id) "
    "or create_open_thread. "
    f"Payload MUST include a non-empty title. {_TITLE_RULE} "
    "Pre-fill both title and summary when known so the confirm card can edit "
    "both fields. "
    f"{_JSON_RULE} "
    "The body shows a confirm card — never only talk about updating in prose. "
    "Do not claim updated before they confirm on the card."
)

_ACTIONS_MUTATE_OFF = (
    "Always keep the conversation going. "
    "Open-thread create/update only on clear commands "
    "(e.g. \"update my thread to 5am\", \"change my sleep to 6am\", "
    "\"update my thread\", \"can you update it\" after a wake time was discussed). "
    "Then append ```rex_action``` with create_open_thread or update_open_thread, "
    f'payload with non-empty title (required; {_TITLE_RULE}), summary?, '
    'thread_id?, and "explicit":true. '
    "Prefer update_open_thread with a listed id. Off mode applies clear thread "
    "commands in chat without a confirm prompt or card, so only emit mutate "
    "actions when the user truly wants the thread changed now. "
    f"{_JSON_RULE} "
    "Do not propose for vague desires without a concrete change "
    '(e.g. "I wish I woke earlier") — just keep talking. '
    "Do not claim updated until the body applies it."
)


def _mode_guidance(mode: str) -> str:
    if mode == AUTO_PROPOSALS_OFF:
        return (
            "Auto Suggestions: off "
            "(keep chatting always; no auto offers; clear thread commands apply "
            "in chat with no confirm prompt or card)."
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
