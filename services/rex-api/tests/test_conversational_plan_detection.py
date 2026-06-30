import pytest

from app.services.conversational_plan_detection import ConversationalPlanDetector


@pytest.fixture
def detector() -> ConversationalPlanDetector:
    return ConversationalPlanDetector()


@pytest.mark.parametrize(
    "message",
    [
        "I'm working on building a consistent morning routine.",
        "I want to reach 10k in savings this year.",
        "My next step is to finish the portfolio website.",
        "I need to complete the certification exam by August.",
        "This month I'm trying to reduce dining out spending.",
        "I'm making progress on my strength training plan.",
        "My focus is to launch the coaching offer.",
    ],
)
def test_detects_generic_conversational_plan_phrases(
    detector: ConversationalPlanDetector,
    message: str,
):
    assert detector.looks_like_conversational_plan(message) is True


@pytest.mark.parametrize(
    "message",
    [
        "Can you remind me about my budget?",
        "Track Europe savings as a goal",
        "Save morning routine as a commitment",
        "What did I say about work?",
        "short",
        "Tonight I'm going to watch the new episode",
    ],
)
def test_skips_non_conversational_plan_messages(
    detector: ConversationalPlanDetector,
    message: str,
):
    assert detector.looks_like_conversational_plan(message) is False


def test_skips_explicit_goal_command(detector: ConversationalPlanDetector):
    assert (
        detector.should_skip_for_explicit_command(
            "My goal is to save $10,000 for Europe",
            conversation_history=[],
            time_context={},
        )
        is True
    )
