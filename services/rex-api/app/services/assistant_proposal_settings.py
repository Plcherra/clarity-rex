"""User/env settings for automatic save and open-thread proposals."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from app.config import Settings, get_settings

AUTO_PROPOSALS_OFF = "off"
AUTO_PROPOSALS_TEXT = "text"
AUTO_PROPOSALS_CARD = "card"

RESPONSE_STYLE_CONCISE = "concise"
RESPONSE_STYLE_BALANCED = "balanced"
RESPONSE_STYLE_DETAILED = "detailed"

PROPOSAL_KIND_THREADS = "threads"
PROPOSAL_KIND_GOALS = "goals"
PROPOSAL_KIND_MEMORY = "memory"

_VALID_MODES = {AUTO_PROPOSALS_OFF, AUTO_PROPOSALS_TEXT, AUTO_PROPOSALS_CARD}
_VALID_RESPONSE_STYLES = {
    RESPONSE_STYLE_CONCISE,
    RESPONSE_STYLE_BALANCED,
    RESPONSE_STYLE_DETAILED,
}


@dataclass(frozen=True)
class AssistantProposalSettings:
    mode: str = AUTO_PROPOSALS_CARD
    threads: bool = True
    goals: bool = True
    memory: bool = True
    response_style: str = RESPONSE_STYLE_BALANCED
    finance_edits_enabled: bool = True

    def auto_proposals_enabled(self) -> bool:
        return self.mode in {AUTO_PROPOSALS_TEXT, AUTO_PROPOSALS_CARD}

    def uses_text_offers(self) -> bool:
        return self.mode == AUTO_PROPOSALS_TEXT

    def uses_confirm_cards(self) -> bool:
        return self.mode == AUTO_PROPOSALS_CARD

    def allows_kind(self, kind: str) -> bool:
        if not self.auto_proposals_enabled():
            return False
        if kind == PROPOSAL_KIND_THREADS:
            return self.threads
        if kind == PROPOSAL_KIND_GOALS:
            return self.goals
        if kind == PROPOSAL_KIND_MEMORY:
            return self.memory
        return False

    def to_profile_dict(self) -> dict[str, Any]:
        return {
            "auto_proposals_mode": self.mode,
            "auto_proposals_threads": self.threads,
            "auto_proposals_goals": self.goals,
            "auto_proposals_memory": self.memory,
            "response_style": self.response_style,
            "finance_edits_enabled": self.finance_edits_enabled,
        }


def _coerce_bool(value: Any, *, default: bool) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"1", "true", "yes", "on"}:
            return True
        if normalized in {"0", "false", "no", "off"}:
            return False
    return default


def parse_assistant_settings(raw: Optional[dict[str, Any]]) -> AssistantProposalSettings:
    payload = raw if isinstance(raw, dict) else {}
    mode = str(payload.get("auto_proposals_mode") or AUTO_PROPOSALS_CARD).strip().lower()
    if mode not in _VALID_MODES:
        mode = AUTO_PROPOSALS_CARD
    response_style = str(payload.get("response_style") or RESPONSE_STYLE_BALANCED).strip().lower()
    if response_style not in _VALID_RESPONSE_STYLES:
        response_style = RESPONSE_STYLE_BALANCED
    return AssistantProposalSettings(
        mode=mode,
        threads=_coerce_bool(payload.get("auto_proposals_threads"), default=True),
        goals=_coerce_bool(payload.get("auto_proposals_goals"), default=True),
        memory=_coerce_bool(payload.get("auto_proposals_memory"), default=True),
        response_style=response_style,
        finance_edits_enabled=_coerce_bool(
            payload.get("finance_edits_enabled"),
            default=True,
        ),
    )


def resolve_assistant_proposal_settings(
    profile_settings: Optional[dict[str, Any]] = None,
    *,
    settings: Optional[Settings] = None,
) -> AssistantProposalSettings:
    resolved = parse_assistant_settings(profile_settings)
    env = settings or get_settings()
    env_mode = (env.rex_auto_proposals_mode or "").strip().lower()
    if env_mode in _VALID_MODES:
        resolved = AssistantProposalSettings(
            mode=env_mode,
            threads=(
                env.rex_auto_proposals_threads
                if env.rex_auto_proposals_threads is not None
                else resolved.threads
            ),
            goals=(
                env.rex_auto_proposals_goals
                if env.rex_auto_proposals_goals is not None
                else resolved.goals
            ),
            memory=(
                env.rex_auto_proposals_memory
                if env.rex_auto_proposals_memory is not None
                else resolved.memory
            ),
            response_style=resolved.response_style,
            finance_edits_enabled=resolved.finance_edits_enabled,
        )
    return resolved
