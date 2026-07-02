from app.services.proactive_insight_guard import (
    proactive_monitoring_guard_text,
    requires_proactive_monitoring_opt_in,
)
from app.services.simple_rex_brain import SimpleRexBrain


class FakeChatContextService:
    def build_prompt_messages(self, **kwargs):
        return [{"role": "user", "content": kwargs["message"]}]


def test_requires_proactive_monitoring_opt_in_when_disabled():
    assert requires_proactive_monitoring_opt_in(
        "Please monitor my spending and alert me weekly",
        user_enabled_proactive_insights=False,
    )


def test_does_not_require_opt_in_when_enabled():
    assert not requires_proactive_monitoring_opt_in(
        "Please monitor my spending and alert me weekly",
        user_enabled_proactive_insights=True,
    )


def test_guard_text_empty_without_opt_in_requirement():
    assert proactive_monitoring_guard_text(requires_opt_in=False) == ""


def test_simple_rex_brain_appends_guard_for_monitoring_request():
    brain = SimpleRexBrain(chat_context_service=FakeChatContextService())
    messages = brain.build_prompt_messages(
        message="Monitor my budget and notify me every day",
        conversation_id="conv-1",
        conversation_history=[],
        long_term_memory=[],
        structured_context={},
        accountability_signals=[],
        file_text=None,
        time_context={},
        financial_context=None,
        channel=__import__(
            "app.services.rex_channel", fromlist=["RexBrainChannel"]
        ).RexBrainChannel.CHAT,
        user_enabled_proactive_insights=False,
    )
    assert any(message["role"] == "system" and "Ask opt-in" in message["content"] for message in messages)
