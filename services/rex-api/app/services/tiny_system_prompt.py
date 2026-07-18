"""Tiny system prompt: Truth + Auto Suggestions + capability names. No persona."""

from __future__ import annotations

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.capability_catalog import capability_names_prompt
from app.services.clarity_knowledge_labels import CLARITY_KNOWLEDGE_LANGUAGE_PROMPT

_TRUTH_RULE = (
    "Truth Rule: Never say you saved, remembered, updated, deleted, or sent "
    "anything unless the body applied it this turn and the user can see it in "
    "the app. Prefer honest uncertainty over invented facts."
)

_PHASE_B_ACTIONS = (
    "Reply naturally (just_chat). When the user asks for something Clarity "
    "cannot do (email, SMS, etc.), be honest that you cannot send it; you may "
    "offer a draft in the reply. Append a single fenced block:\n"
    "```rex_action\n"
    '{"action":"unsupported","capability_hint":"send_email"}\n'
    "```\n"
    "For soft durable intents (habits/threads/goals/memory) you may append "
    '```rex_action``` with action names from the catalog and '
    '"payload":{...}. Auto Suggestions gate decides Off/Text/Card after you; '
    "do not invent silent saves. Mutate body dispatch is not applied yet."
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
        "silent saves. Off: talk freely; do not expect auto write cards or "
        "text-asks for soft intents."
    )
    sections = [
        _TRUTH_RULE,
        gate,
        capability_names_prompt(),
        _PHASE_B_ACTIONS,
        CLARITY_KNOWLEDGE_LANGUAGE_PROMPT,
    ]
    if open_thread_titles_block and open_thread_titles_block.strip():
        sections.append(open_thread_titles_block.strip())
    return "\n\n".join(sections)
