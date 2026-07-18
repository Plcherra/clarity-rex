from app.services.open_thread_user_intent import classify_open_thread_user_intent


def test_soft_desire_is_soft() -> None:
    assert classify_open_thread_user_intent("I want to wake up everyday at 6am") == "soft"
    assert classify_open_thread_user_intent("I want to wake at 6am") == "soft"


def test_polite_update_ask() -> None:
    assert (
        classify_open_thread_user_intent(
            "Can you update my sleep thread to 6am?"
        )
        == "ask"
    )


def test_imperative_update_command() -> None:
    assert (
        classify_open_thread_user_intent("update my 3am thread to 5am")
        == "command"
    )
    assert (
        classify_open_thread_user_intent(
            "Change my wake sleep schedule to 5am"
        )
        == "command"
    )
