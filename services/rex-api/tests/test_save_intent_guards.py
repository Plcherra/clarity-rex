import pytest

from app.services.save_intent_guards import (
    has_explicit_save_intent,
    is_advice_seeking_turn,
    purchase_clause_from_message,
)


@pytest.mark.parametrize(
    "message",
    [
        "How much weight should I buy for dumbbells?",
        "Okay. So if I'm gonna use dumbbells, how much weight do you think I should buy?",
        "What size kettlebell do you recommend?",
        "Should I get 50 or 60 pound dumbbells?",
    ],
)
def test_advice_questions_are_not_save_turns(message: str) -> None:
    assert is_advice_seeking_turn(message) is True
    assert has_explicit_save_intent(message) is False


@pytest.mark.parametrize(
    "message",
    [
        "Remember me to buy adjustable dumbbells up to 50 pounds.",
        "My goal is to save $10,000 for Europe",
        "Track morning workouts as a goal",
    ],
)
def test_explicit_save_intent_is_not_advice(message: str) -> None:
    assert has_explicit_save_intent(message) is True
    assert is_advice_seeking_turn(message) is False


def test_purchase_clause_extracts_remember_me_action() -> None:
    message = (
        "Great. I'm ready to commit. Can you remember me to buy dumbbells "
        "up to 50 or 60 pounds?"
    )
    assert purchase_clause_from_message(message) == (
        "buy dumbbells up to 50 or 60 pounds"
    )
