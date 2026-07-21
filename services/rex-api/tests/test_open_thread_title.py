from app.services.capabilities.open_thread_title import (
    normalize_open_thread_title,
    title_from_user_text,
    wake_title_from_text,
)


def test_wake_title_from_desire_sentence() -> None:
    assert (
        wake_title_from_text("I want to start waking up at 5am") == "Wake at 5am"
    )


def test_wake_title_from_thinking_sentence() -> None:
    assert (
        wake_title_from_text("Im thinking about changing my waking time for 5am")
        == "Wake at 5am"
    )


def test_normalize_rejects_pasted_user_message() -> None:
    title = normalize_open_thread_title(
        "I want to start waking up at 5am",
        user_text="I want to start waking up at 5am",
    )
    assert title == "Wake at 5am"


def test_typed_short_title_passes_through() -> None:
    assert title_from_user_text("Wake at 5:30am") == "Wake at 5:30am"


def test_good_habit_title_unchanged() -> None:
    assert (
        normalize_open_thread_title("Sleep Schedule and Wake Up Everyday At 5am")
        == "Sleep Schedule and Wake Up Everyday At 5am"
    )
