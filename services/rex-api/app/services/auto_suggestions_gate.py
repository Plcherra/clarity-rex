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


@dataclass(frozen=True)
class AutoSuggestionsGateResult:
    """What the body may surface after settings are applied."""

    mode: str
    allowed_soft_actions: list[BrainAction] = field(default_factory=list)
    dropped_soft_actions: list[BrainAction] = field(default_factory=list)
    unsupported_hints: list[str] = field(default_factory=list)
    passthrough_actions: list[BrainAction] = field(default_factory=list)


def apply_auto_suggestions_gate(
    actions: list[BrainAction],
    settings: AssistantProposalSettings,
    *,
    user_message: str = "",
) -> AutoSuggestionsGateResult:
    _ = user_message  # API compat; the gate reads Grok's flags, never phrases
    allowed: list[BrainAction] = []
    dropped: list[BrainAction] = []
    unsupported: list[str] = []
    passthrough: list[BrainAction] = []

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

        kind = action.kind
        # Off silences Rex's own offers, not the work the user asked for: only
        # actions the brain flagged as its own idea are dropped. Kind toggles
        # still decide which capabilities may run at all.
        if settings.mode == AUTO_PROPOSALS_OFF:
            if (
                kind is not None
                and settings.allows_explicit_command(kind)
                and not action.auto
            ):
                allowed.append(action)
            else:
                dropped.append(action)
            continue

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
    )


def gate_mode_label(settings: AssistantProposalSettings) -> str:
    if settings.mode == AUTO_PROPOSALS_TEXT:
        return AUTO_PROPOSALS_TEXT
    if settings.mode == AUTO_PROPOSALS_CARD:
        return AUTO_PROPOSALS_CARD
    return AUTO_PROPOSALS_OFF
