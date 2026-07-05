from app.services.rex_channel import RexBrainChannel
from app.services.rex_intent_router import RexIntent, RexIntentDecision
from app.services.voice_stream_orchestrator_support import (
    stream_should_buffer_for_action_truth,
    voice_context_slim_intent,
    voice_delay_audio_until_done,
)


def test_voice_delay_audio_skips_recall():
    assert voice_delay_audio_until_done("memory_recall") is False


def test_voice_delay_audio_keeps_save_intents():
    assert voice_delay_audio_until_done("memory_save") is True


def test_voice_context_slim_intent_for_casual():
    decision = RexIntentDecision(intent=RexIntent.CASUAL, reasons=("casual_greeting",))
    assert voice_context_slim_intent(decision) is True


def test_voice_stream_buffer_disabled_for_voice_channel():
    decision = RexIntentDecision(intent=RexIntent.GOAL, reasons=("goal_terms",))
    assert stream_should_buffer_for_action_truth(decision, channel=RexBrainChannel.VOICE) is False
    assert stream_should_buffer_for_action_truth(decision, channel=RexBrainChannel.CHAT) is True
