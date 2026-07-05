from app.services.rex_channel import RexBrainChannel
from app.services.rex_intent_router import RexIntent, RexIntentDecision
from app.services.voice_stream_orchestrator_support import (
    stream_should_buffer_for_action_truth,
    voice_context_slim_intent,
    voice_delay_audio_until_done,
    voice_speakable_text,
)


def test_voice_delay_audio_never_defers_on_voice():
    assert voice_delay_audio_until_done("memory_recall") is False
    assert voice_delay_audio_until_done("memory_save") is False
    assert voice_delay_audio_until_done("goal") is False


def test_voice_speakable_text_uses_pending_proposal_confirmation():
    spoken = voice_speakable_text(
        "",
        {
            "write_proposals": [
                {
                    "status": "pending",
                    "confirmation_text": "Track as an open thread in Goals?",
                    "title": "Morning Routine",
                }
            ]
        },
    )
    assert spoken == "Track as an open thread in Goals?"


def test_voice_speakable_text_prefers_assistant_response():
    spoken = voice_speakable_text(
        "Want me to keep track of this?",
        {"write_proposals": [{"status": "pending", "confirmation_text": "Other"}]},
    )
    assert spoken == "Want me to keep track of this?"


def test_voice_context_slim_intent_for_casual():
    decision = RexIntentDecision(intent=RexIntent.CASUAL, reasons=("casual_greeting",))
    assert voice_context_slim_intent(decision) is True


def test_voice_stream_buffer_disabled_for_voice_channel():
    decision = RexIntentDecision(intent=RexIntent.GOAL, reasons=("goal_terms",))
    assert stream_should_buffer_for_action_truth(decision, channel=RexBrainChannel.VOICE) is False
    assert stream_should_buffer_for_action_truth(decision, channel=RexBrainChannel.CHAT) is True
