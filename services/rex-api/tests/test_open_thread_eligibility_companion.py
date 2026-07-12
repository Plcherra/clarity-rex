from app.services.open_thread_eligibility import (
    is_one_off_commitment,
    is_stress_only_vent,
    message_might_need_open_thread_offer,
)


def test_cannot_sleep_vent_is_not_thread_offer() -> None:
    message = (
        "i cant sleep too much on my mind, I wake up around 11am so i just "
        "starting get sleep but I dont want to sleep because I gotta wake up around 6:30am"
    )
    assert is_stress_only_vent(message)
    assert is_one_off_commitment(message)
    assert not message_might_need_open_thread_offer(
        message,
        already_offered=False,
        already_declined=False,
    )


def test_habit_sleep_schedule_can_still_offer_thread() -> None:
    message = "I want to change my sleep schedule and wake up every day at 6am."
    assert not is_stress_only_vent(message)
    assert not is_one_off_commitment(message)
    assert message_might_need_open_thread_offer(
        message,
        already_offered=False,
        already_declined=False,
    )


def test_remember_that_after_start_waking_offers_thread() -> None:
    history = [
        {"role": "user", "content": "what if I start waking up around 4am?"},
        {
            "role": "assistant",
            "content": "Waking up at 4am can give you several extra focused hours.",
        },
    ]
    message = "can you remember me that?"
    assert not is_one_off_commitment(message, conversation_history=history)
    assert message_might_need_open_thread_offer(
        message,
        already_offered=False,
        already_declined=False,
        conversation_history=history,
    )
