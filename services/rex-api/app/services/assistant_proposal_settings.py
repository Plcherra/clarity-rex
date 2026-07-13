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

SETTINGS_LOAD_OK = "ok"
SETTINGS_LOAD_FAIL_CLOSED = "fail_closed"
SETTINGS_LOAD_MISSING_AUTH = "missing_auth"
SETTINGS_LOAD_EMPTY_PROFILE = "empty_profile"

_VALID_MODES = {AUTO_PROPOSALS_OFF, AUTO_PROPOSALS_TEXT, AUTO_PROPOSALS_CARD}
_VALID_RESPONSE_STYLES = {
    RESPONSE_STYLE_CONCISE,
    RESPONSE_STYLE_BALANCED,
    RESPONSE_STYLE_DETAILED,
}


@dataclass(frozen=True)
class AssistantProposalSettings:
    # Safe default: no automatic proposals until the user chooses Text/Card.
    mode: str = AUTO_PROPOSALS_OFF
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
        """Auto-inferred proposals only. Explicit user commands are separate."""
        if not self.auto_proposals_enabled():
            return False
        if kind == PROPOSAL_KIND_THREADS:
            return self.threads
        if kind == PROPOSAL_KIND_GOALS:
            return self.goals
        if kind == PROPOSAL_KIND_MEMORY:
            return self.memory
        return False

    def enabled_kinds(self) -> list[str]:
        if not self.auto_proposals_enabled():
            return []
        kinds: list[str] = []
        if self.threads:
            kinds.append(PROPOSAL_KIND_THREADS)
        if self.goals:
            kinds.append(PROPOSAL_KIND_GOALS)
        if self.memory:
            kinds.append(PROPOSAL_KIND_MEMORY)
        return kinds

    def to_profile_dict(self) -> dict[str, Any]:
        return {
            "auto_proposals_mode": self.mode,
            "auto_proposals_threads": self.threads,
            "auto_proposals_goals": self.goals,
            "auto_proposals_memory": self.memory,
            "response_style": self.response_style,
            "finance_edits_enabled": self.finance_edits_enabled,
        }


@dataclass(frozen=True)
class ProposalSettingsResolution:
    settings: AssistantProposalSettings
    profile_mode: Optional[str]
    env_mode: Optional[str]
    settings_load_status: str

    @property
    def effective_mode(self) -> str:
        return self.settings.mode


def fail_closed_proposal_settings() -> AssistantProposalSettings:
    """Autos Off when settings cannot be loaded — never fail open to Card."""
    return AssistantProposalSettings(mode=AUTO_PROPOSALS_OFF)


def fail_closed_resolution(
    *,
    settings_load_status: str = SETTINGS_LOAD_FAIL_CLOSED,
    settings: Optional[Settings] = None,
) -> ProposalSettingsResolution:
    return ProposalSettingsResolution(
        settings=fail_closed_proposal_settings(),
        profile_mode=None,
        env_mode=_read_env_mode(settings),
        settings_load_status=settings_load_status,
    )


def _read_env_mode(settings: Optional[Settings] = None) -> Optional[str]:
    env = settings or get_settings()
    env_mode = (env.rex_auto_proposals_mode or "").strip().lower()
    if env_mode in _VALID_MODES:
        return env_mode
    return None


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


def _raw_profile_mode(payload: dict[str, Any]) -> Optional[str]:
    if "auto_proposals_mode" not in payload:
        return None
    raw = payload.get("auto_proposals_mode")
    if raw is None:
        return None
    mode = str(raw).strip().lower()
    return mode or None


def parse_assistant_settings(raw: Optional[dict[str, Any]]) -> AssistantProposalSettings:
    """Parse profile settings. Missing/invalid mode fails closed to Off."""
    payload = raw if isinstance(raw, dict) else {}
    raw_mode = _raw_profile_mode(payload)
    if raw_mode in _VALID_MODES:
        mode = raw_mode
    else:
        # Empty {}, missing key, blank, or invalid → Off (never silent Card).
        mode = AUTO_PROPOSALS_OFF
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
    return resolve_proposal_settings_resolution(
        profile_settings,
        settings=settings,
    ).settings


def resolve_proposal_settings_resolution(
    profile_settings: Optional[dict[str, Any]] = None,
    *,
    settings: Optional[Settings] = None,
    settings_load_status: Optional[str] = None,
) -> ProposalSettingsResolution:
    """Resolve profile mode, then optional env override.

    Policy:
    - Missing/empty/invalid profile mode → Off (never silent Card).
    - Explicit profile Off always wins over env Card/Text.
    - Env may override empty/default Off (ops + tests) and may force Off.
    - Leave ``REX_AUTO_PROPOSALS_MODE`` unset in production.
    """
    payload = profile_settings if isinstance(profile_settings, dict) else {}
    profile_mode = _raw_profile_mode(payload)
    explicit_mode = profile_mode if profile_mode in _VALID_MODES else None
    resolved = parse_assistant_settings(payload)
    env = settings or get_settings()
    env_mode = _read_env_mode(env)
    load_status = settings_load_status
    if load_status is None:
        if explicit_mode is None:
            load_status = SETTINGS_LOAD_EMPTY_PROFILE
        else:
            load_status = SETTINGS_LOAD_OK

    if env_mode is None:
        return ProposalSettingsResolution(
            settings=resolved,
            profile_mode=explicit_mode,
            env_mode=None,
            settings_load_status=load_status,
        )

    # Explicit user Off cannot be overwritten by env Card/Text.
    if explicit_mode == AUTO_PROPOSALS_OFF and env_mode != AUTO_PROPOSALS_OFF:
        return ProposalSettingsResolution(
            settings=resolved,
            profile_mode=AUTO_PROPOSALS_OFF,
            env_mode=env_mode,
            settings_load_status=load_status,
        )

    overridden = AssistantProposalSettings(
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
    return ProposalSettingsResolution(
        settings=overridden,
        profile_mode=explicit_mode,
        env_mode=env_mode,
        settings_load_status=load_status,
    )
