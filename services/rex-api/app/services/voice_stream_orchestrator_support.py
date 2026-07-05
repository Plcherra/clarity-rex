"""Voice-specific streaming helpers for chat turn orchestration."""

from __future__ import annotations

from app.services.rex_channel import RexBrainChannel
from app.services.rex_intent_router import RexIntent


_ACTION_TRUTH_STREAM_INTENTS = {
    RexIntent.MEMORY_SAVE,
    RexIntent.MEMORY_UPDATE,
    RexIntent.GOAL,
}


def stream_should_buffer_for_action_truth(intent_decision, *, channel: RexBrainChannel) -> bool:
    if channel == RexBrainChannel.VOICE:
        return False
    return intent_decision.intent in _ACTION_TRUTH_STREAM_INTENTS


def voice_delay_audio_until_done(intent: str) -> bool:
    normalized = (intent or "").strip().lower()
    return normalized in {
        "memory_save",
        "memory_update",
        "goal",
    }


def voice_context_slim_intent(intent_decision) -> bool:
    if intent_decision is None:
        return False
    return intent_decision.intent in {
        RexIntent.CASUAL,
        RexIntent.FINANCE,
        RexIntent.UNKNOWN,
    }
