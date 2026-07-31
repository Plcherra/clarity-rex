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

_PEOPLE_OFFERS = (
    "Offer people and moments too, not only threads and goals: save_person for "
    "someone new, add_person_note for what happened with them, "
    "update_person_state for how things stand now."
)

_ACTIONS_MUTATE = (
    "When the user wants an open-thread create/update — including after they "
    "say yes to your offer — append ```rex_action``` in the same turn with "
    "create_open_thread or update_open_thread. "
    f"Payload MUST include a non-empty title. {_TITLE_RULE} "
    "Prefer update_open_thread with a listed thread_id when changing an "
    "existing thread. Include summary when the user gives reminder details, "
    "the reason it matters, or a renamed purpose. "
    "For achievement goals (not habits), use create_goal / update_goal / "
    "delete_goal with a short title (and description when known). "
    "Prefer plan_id or existing_title/reference when updating or deleting. "
    "A step under a goal is a milestone (create_milestone / update_milestone / "
    "delete_milestone) — include plan_id or goal_title. "
    "A recurring habit/check-in is an open thread, not a milestone. "
    f"{_PEOPLE_OFFERS} Ask once, in chat, and save on yes. "
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
    "For achievement goals, append create_goal / update_goal / delete_goal "
    "so a confirm card can appear — never only talk about saving a goal. "
    "For a step under a goal, append create_milestone / update_milestone / "
    "delete_milestone with plan_id or goal_title. Habits stay open threads. "
    f"{_PEOPLE_OFFERS} Give each card a clear title and description. "
    f"{_JSON_RULE} "
    "The body shows a confirm card — never only talk about updating in prose. "
    "Do not claim updated before they confirm on the card."
)

_ACTIONS_MUTATE_OFF = (
    "Always keep the conversation going, and never volunteer a save. "
    'On a clear command ("save Marcella", "update my thread to 5am", '
    '"can you update it" after a wake time was discussed) append '
    '```rex_action``` in the same turn with "explicit":true: create_open_thread '
    f"or update_open_thread (non-empty title required; {_TITLE_RULE} prefer a "
    "listed thread_id, add summary when they give details), goals, milestones "
    "(plan_id or goal_title), memory, or person saves and notes. Habits stay "
    "open threads. If they ask you to save but not what to save, ask which — "
    "the person, a note on their card, a goal — then act on their answer. Off "
    "applies these with no card, so send them only when the user wants the "
    'change now; mark your own ideas "auto":true so they stay unsaid. '
    f"{_JSON_RULE} "
    'Vague wishes ("I wish I woke earlier") stay conversation. '
    "Do not claim updated until the body applies it."
)


_ACTIONS_FINANCE = (
    "Money questions: append ```rex_action``` with fetch_spend_insight "
    "(category?, merchant?, period?) or fetch_account_summary (account?), then "
    "answer only from the fetched numbers — never invent amounts. Totals cover "
    "the period; rows can be a sample, so quote totals and call rows examples. "
    "Category names are the user's own buckets and often mix things (fast food "
    "in a coffee category): for a narrower question, separate it with the "
    "merchant lines and say what you left out. Finance changes: append the "
    "action in the same turn — never promise one in prose alone. "
    'update_category {"reference":"<current>","new_name":"<new>"} renames; '
    "categorize_transaction (transaction_ids) or bulk_categorize (merchant + "
    "category) moves rows and may name a category that does not exist yet — the "
    "body reuses or creates it on confirm, so split a mixed bucket with one "
    "bulk_categorize per merchant. Clarity cannot create transactions outside "
    "Plaid or CSV."
)

_ACTIONS_FINANCE_OFF = (
    f"{_ACTIONS_FINANCE} Off mode still runs finance changes the user asks for "
    '(send "explicit":true); it only means do not volunteer them.'
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
        return f"{_ACTIONS_BASE}\n{_ACTIONS_MUTATE_OFF}\n{_ACTIONS_FINANCE_OFF}"
    if mode == AUTO_PROPOSALS_CARD:
        return f"{_ACTIONS_BASE}\n{_ACTIONS_MUTATE_CARD}\n{_ACTIONS_FINANCE}"
    return f"{_ACTIONS_BASE}\n{_ACTIONS_MUTATE}\n{_ACTIONS_FINANCE}"


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
