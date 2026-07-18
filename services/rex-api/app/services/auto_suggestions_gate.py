"""Auto Suggestions gate — Off/Text/Card + kind toggles after Grok meaning."""

from __future__ import annotations

from dataclasses import dataclass, field

from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_CARD,
    AUTO_PROPOSALS_OFF,
    AUTO_PROPOSALS_TEXT,
    AssistantProposalSettings,
)
from app.services.brain_action_schema import BrainAction
from app.services.open_thread_user_intent import classify_open_thread_user_intent


@dataclass(frozen=True)
class AutoSuggestionsGateResult:
    """What the body may surface after settings are applied."""

    mode: str
    allowed_soft_actions: list[BrainAction] = field(default_factory=list)
    dropped_soft_actions: list[BrainAction] = field(default_factory=list)
    unsupported_hints: list[str] = field(default_factory=list)
    passthrough_actions: list[BrainAction] = field(default_factory=list)
    user_thread_intent: str = "soft"


def apply_auto_suggestions_gate(
    actions: list[BrainAction],
    settings: AssistantProposalSettings,
    *,
    user_message: str = "",
) -> AutoSuggestionsGateResult:
    allowed: list[BrainAction] = []
    dropped: list[BrainAction] = []
    unsupported: list[str] = []
    passthrough: list[BrainAction] = []
    user_intent = classify_open_thread_user_intent(user_message)

    for action in actions:
        if action.is_unsupported:
            hint = action.capability_hint or "unsupported"
            unsupported.append(hint)
            continue
        if action.name == "just_chat":
            passthrough.append(action)
            continue
        if not action.is_soft_mutate:
            passthrough.append(action)
            continue

        if settings.mode == AUTO_PROPOSALS_OFF:
            # Never trust Grok explicit alone — Off soft desires stay coach-only.
            if action.kind == "threads" and user_intent == "soft":
                dropped.append(action)
                continue
            if action.kind == "threads" and user_intent in {"ask", "command"}:
                allowed.append(action)
                continue
            # Non-thread soft mutates stay dropped on Off until later phases.
            dropped.append(action)
            continue

        kind = action.kind
        if kind is not None and settings.allows_kind(kind):
            allowed.append(action)
        else:
            dropped.append(action)

    return AutoSuggestionsGateResult(
        mode=settings.mode,
        allowed_soft_actions=allowed,
        dropped_soft_actions=dropped,
        unsupported_hints=unsupported,
        passthrough_actions=passthrough,
        user_thread_intent=user_intent,
    )


def gate_mode_label(settings: AssistantProposalSettings) -> str:
    if settings.mode == AUTO_PROPOSALS_TEXT:
        return AUTO_PROPOSALS_TEXT
    if settings.mode == AUTO_PROPOSALS_CARD:
        return AUTO_PROPOSALS_CARD
    return AUTO_PROPOSALS_OFF
