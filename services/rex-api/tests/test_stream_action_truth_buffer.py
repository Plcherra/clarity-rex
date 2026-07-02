from app.services.chat_turn_orchestrator_support import stream_should_buffer_for_action_truth
from app.services.rex_intent_router import RexIntent, RexIntentDecision


def test_stream_buffers_tokens_for_memory_save_intent():
    decision = RexIntentDecision(intent=RexIntent.MEMORY_SAVE, reasons=("memory_save_language",))
    assert stream_should_buffer_for_action_truth(decision) is True


def test_stream_buffers_tokens_for_goal_intent():
    decision = RexIntentDecision(intent=RexIntent.GOAL_OR_COMMITMENT, reasons=("goal_terms",))
    assert stream_should_buffer_for_action_truth(decision) is True


def test_stream_does_not_buffer_casual_intent():
    decision = RexIntentDecision(intent=RexIntent.CASUAL, reasons=("casual_greeting",))
    assert stream_should_buffer_for_action_truth(decision) is False
