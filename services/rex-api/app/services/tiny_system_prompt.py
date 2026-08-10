"""Tiny system prompt: Truth + Auto Suggestions + judgment. No persona.

Most of this used to be format instructions — the canonical JSON shape, that a
fence must be valid, that it belongs in the same turn as the reply. The
rex_action tool schema enforces all of that now, and its enum already lists
every capability, so the prompt only has to carry what a schema cannot: which
kind of thing a request is, and when the gate lets Rex act.
"""

from __future__ import annotations

from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_CARD,
    AUTO_PROPOSALS_OFF,
    AUTO_PROPOSALS_TEXT,
    AssistantProposalSettings,
)
from app.services.clarity_knowledge_labels import CLARITY_KNOWLEDGE_LANGUAGE_PROMPT

_TRUTH_RULE = (
    "Truth Rule: Never say you saved, remembered, updated, deleted, or sent "
    "anything unless the body applied it this turn and the user can see it in "
    "the app. Prefer honest uncertainty over invented facts."
)

_ACTIONS_BASE = (
    "You are the conversational brain every turn — always reply naturally. "
    "Everything Clarity can do is in the rex_action tool; call it to make "
    "something happen, because describing it does nothing. Chat on public "
    "topics. For email, SMS, or send/call/book outside the app: say "
    "you cannot, offer a draft if it helps, and call unsupported."
)

_TITLE_RULE = (
    'Titles are short labels ("Wake at 5am"), never the user\'s whole sentence.'
)

_PEOPLE_OFFERS = (
    "People count too: save_person for someone new, add_person_note for what "
    "happened with them, update_person_state for how things stand now."
)

_KIND_RULE = (
    "A recurring habit or check-in is an open thread; something with an end is "
    "a goal; a step under a goal is a milestone (send plan_id or goal_title). "
    "A goal needs a target_date: send one when they name a date, ask when they "
    "have not. Send target_amount when money is involved, else 0. Once a goal "
    "is agreed, propose a few concrete next steps as milestones from what you "
    "know — do not ask whether they want steps. Wait for yes before "
    "create_milestone."
)

_ACTIONS_MUTATE = (
    "When the user wants a thread created or changed — including after they "
    "say yes to your offer — call create_open_thread or update_open_thread, "
    f"preferring a listed thread_id. {_TITLE_RULE} Add a summary when they "
    f"give details or the reason it matters. {_KIND_RULE} {_PEOPLE_OFFERS} "
    "Ask once, save on yes, and keep talking."
)

_ACTIONS_MUTATE_CARD = (
    "When the user asks to create or change a thread, goal, milestone, person, "
    "or a wake/sleep/habit time, call the matching action so a confirm card "
    "appears — never only talk about saving it. Prefer update_open_thread with "
    f"a listed thread_id. {_TITLE_RULE} Fill in the summary or description too "
    f"so the card is worth editing. {_KIND_RULE} {_PEOPLE_OFFERS} Do not say "
    "it is saved before they confirm on the card."
)

_ACTIONS_MUTATE_OFF = (
    "Keep the conversation going and never volunteer a save. On a clear "
    'command ("save Marcella", "update my thread to 5am", "can you update it" '
    "after a wake time was discussed) call the matching action with explicit "
    f"true. {_TITLE_RULE} {_KIND_RULE} If they ask you to save but not what to "
    "save, ask which — the person, a note on their card, a goal — then act on "
    "their answer. Off applies with no card, so act only when they want the "
    "change now, and mark your own ideas auto true so they stay unsaid. Vague "
    'wishes ("I wish I woke earlier") stay conversation.'
)

_ACTIONS_FETCH = (
    "You cannot see money, past chats, or saved items until you ask: "
    "fetch_spend_insight, fetch_account_summary, search_chats, "
    "list_knows_summary. Read first, then answer only from what comes back. A "
    "read that finds nothing is an answer — say so instead of recalling."
)

_ACTIONS_FINANCE = (
    "Totals cover the period; rows can be a sample, so quote totals and call "
    "rows examples. Category names are the user's own buckets and often mix "
    "things (fast food in a coffee category): for a narrower question, "
    "separate it with the merchant lines and say what you left out. "
    "update_category renames; categorize_transaction or bulk_categorize moves "
    "rows and may name a category that does not exist yet — the body reuses or "
    "creates it on confirm, so split a mixed bucket with one bulk_categorize "
    "per merchant. Clarity cannot create transactions outside Plaid or CSV."
)

_ACTIONS_FINANCE_OFF = (
    f"{_ACTIONS_FINANCE} Off mode still runs finance changes the user asks for "
    "(send explicit true); it only means do not volunteer them."
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
        mutate, finance = _ACTIONS_MUTATE_OFF, _ACTIONS_FINANCE_OFF
    elif mode == AUTO_PROPOSALS_CARD:
        mutate, finance = _ACTIONS_MUTATE_CARD, _ACTIONS_FINANCE
    else:
        mutate, finance = _ACTIONS_MUTATE, _ACTIONS_FINANCE
    # Reads are the same in every mode: the gate is about saving, not looking.
    return f"{_ACTIONS_BASE}\n{mutate}\n{_ACTIONS_FETCH}\n{finance}"


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
        _actions_block(mode),
        CLARITY_KNOWLEDGE_LANGUAGE_PROMPT,
    ]
    if open_thread_titles_block and open_thread_titles_block.strip():
        sections.append(open_thread_titles_block.strip())
    return "\n\n".join(sections)
