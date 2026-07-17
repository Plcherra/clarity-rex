from app.services.open_thread_overlap import (
    find_overlapping_active_thread,
    find_thread_for_explicit_update,
)


SLEEP_THREAD = {
    "id": "thread-1",
    "title": "Sleep Schedule and Wake Up Everyday At 3am",
    "summary": "wake up every day at 3am",
}


def test_find_overlapping_active_thread_matches_wake_schedule_change():
    message = (
        "I want to change my sleep schedule and wake up every day at 6am instead."
    )
    hit = find_overlapping_active_thread(message, [SLEEP_THREAD])
    assert hit is not None
    assert hit["id"] == "thread-1"


def test_explicit_update_matches_by_clock_time_in_title():
    message = "update my 3am thread to 5am instead"
    hit = find_thread_for_explicit_update(message, [SLEEP_THREAD])
    assert hit is not None
    assert hit["id"] == "thread-1"


def test_explicit_update_single_thread_fallback():
    message = "update my thread to wake at 5am instead"
    hit = find_thread_for_explicit_update(
        message,
        [{"id": "only", "title": "Night routine", "summary": "stay consistent"}],
    )
    assert hit is not None
    assert hit["id"] == "only"
