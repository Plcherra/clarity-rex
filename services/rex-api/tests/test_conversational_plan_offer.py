"""Unit tests for conversational plan/goal offer detection helpers."""

from app.services.conversational_plan_offer import (
    is_plan_offer_affirmation,
    is_plan_offer_decline,
    plan_offer_state_from_history,
)


def test_detects_assistant_goal_save_offer():
    history = [
        {
            "role": "user",
            "content": (
                "I'm trying to build a consistent strength training routine "
                "three times per week."
            ),
        },
        {
            "role": "assistant",
            "content": (
                'I can save "Build a consistent strength training routine" '
                "as a goal in Goals if you want — just say the word."
            ),
        },
    ]

    offer = plan_offer_state_from_history(history)

    assert offer["offered"] is True
    assert offer["declined"] is False
    assert offer["offered_title"] == "Build a consistent strength training routine"
    assert "strength training" in (offer["topic_message"] or "")


def test_affirmation_yes_please_matches_when_offer_present():
    offer = {
        "offered": True,
        "declined": False,
        "offered_title": "Strength training",
        "topic_message": "I'm trying to build a consistent strength training routine.",
    }

    assert is_plan_offer_affirmation("yes please", offer) is True
    assert is_plan_offer_affirmation("yes please", {"offered": False}) is False
    assert is_plan_offer_affirmation(
        "yes please",
        {"offered": True, "declined": True},
    ) is False


def test_decline_no_matches_when_offer_present():
    offer = {
        "offered": True,
        "declined": False,
        "offered_title": "Strength training",
        "topic_message": "I'm trying to build a consistent strength training routine.",
    }

    assert is_plan_offer_decline("no", offer) is True
    assert is_plan_offer_decline("no", {"offered": False}) is False
