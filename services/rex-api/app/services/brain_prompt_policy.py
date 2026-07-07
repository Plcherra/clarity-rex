"""Env-driven prompt layering for Grok (production vs raw experiments)."""

from app.config import get_settings

BRAIN_PROMPT_MODE_PRODUCTION = "production"
BRAIN_PROMPT_MODE_RAW = "raw"
BRAIN_PROMPT_MODE_RAW_TRUTH = "raw_truth"

_VALID_MODES = {
    BRAIN_PROMPT_MODE_PRODUCTION,
    BRAIN_PROMPT_MODE_RAW,
    BRAIN_PROMPT_MODE_RAW_TRUTH,
}


def brain_prompt_mode() -> str:
    raw = (get_settings().rex_brain_prompt_mode or BRAIN_PROMPT_MODE_PRODUCTION).strip().lower()
    if raw in _VALID_MODES:
        return raw
    return BRAIN_PROMPT_MODE_PRODUCTION


def include_personality_prompt() -> bool:
    return brain_prompt_mode() == BRAIN_PROMPT_MODE_PRODUCTION


def include_action_truth_prompt() -> bool:
    return brain_prompt_mode() in {
        BRAIN_PROMPT_MODE_PRODUCTION,
        BRAIN_PROMPT_MODE_RAW_TRUTH,
    }


def include_memory_discipline_prompt() -> bool:
    return brain_prompt_mode() == BRAIN_PROMPT_MODE_PRODUCTION


def include_proactive_monitoring_guard() -> bool:
    return brain_prompt_mode() == BRAIN_PROMPT_MODE_PRODUCTION


def should_append_voice_instructions() -> bool:
    settings = get_settings()
    if not settings.rex_voice_instructions_enabled:
        return False
    return brain_prompt_mode() == BRAIN_PROMPT_MODE_PRODUCTION
