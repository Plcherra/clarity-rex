"""Voice-specific streaming helpers for chat turn orchestration."""

from __future__ import annotations

from typing import Any, Optional

from app.services.rex_channel import RexBrainChannel


def stream_should_buffer_for_action_truth(intent_decision, *, channel: RexBrainChannel) -> bool:
    _ = intent_decision
    return False


def voice_delay_audio_until_done(intent: str) -> bool:
    """Voice streams TTS incrementally; confirm cards use voice_speakable_text at end."""
    _ = intent
    return False


def voice_speakable_text(
    response_text: str,
    memory_changes: Optional[dict[str, Any]],
) -> str:
    text = (response_text or "").strip()
    if text:
        return text
    for proposal in (memory_changes or {}).get("write_proposals") or []:
        if not isinstance(proposal, dict):
            continue
        if str(proposal.get("status") or "pending").strip().lower() != "pending":
            continue
        spoken = (
            str(proposal.get("confirmation_text") or proposal.get("title") or "")
            .strip()
        )
        if spoken:
            return spoken
    return ""


def voice_context_slim_intent(intent_decision) -> bool:
    _ = intent_decision
    return True
