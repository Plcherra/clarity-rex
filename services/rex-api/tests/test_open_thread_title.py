from __future__ import annotations

import pytest

from app.services.open_thread_title import (
    build_thread_description,
    clamp_thread_title,
    infer_thread_title,
)


def test_infer_thread_title_from_vague_opener() -> None:
    title = infer_thread_title("About changing my night routine right now.")
    assert title == "New Night Routine Change"
    assert len(title) <= 60


def test_infer_thread_title_includes_sleep_purpose_from_context() -> None:
    history = [
        {"role": "user", "content": "About changing my night routine right now."},
        {
            "role": "user",
            "content": (
                "Yeah. It's just because I'm having some problem to sleep, "
                "so now I got a plan."
            ),
        },
    ]
    title = infer_thread_title(
        history[-1]["content"],
        conversation_history=history,
    )
    assert "Sleep" in title
    assert "Routine" in title
    assert len(title) <= 60


def test_infer_thread_title_from_morning_routine_message() -> None:
    title = infer_thread_title(
        "I've been trying to figure out a better morning routine lately.",
    )
    assert title == "Better Morning Routine"
    assert len(title) <= 60


def test_infer_thread_title_truncates_long_messages() -> None:
    message = " ".join(["workout"] * 20)
    title = infer_thread_title(message, max_length=40)
    assert len(title) <= 40


def test_clamp_thread_title_enforces_max_length() -> None:
    title = clamp_thread_title("A" * 80)
    assert len(title) <= 60


def test_build_thread_description_uses_readable_prose() -> None:
    description = build_thread_description(
        "I've been trying to figure out a better morning routine lately.",
    )
    assert description is not None
    assert description.startswith("Follow up on")
    assert "morning routine" in description.casefold()
    assert "I've been trying" not in description


def test_build_thread_description_includes_purpose_from_context() -> None:
    history = [
        {"role": "user", "content": "About changing my night routine right now."},
        {
            "role": "user",
            "content": (
                "Yeah. It's just because I'm having some problem to sleep, "
                "so now I got a plan."
            ),
        },
    ]
    description = build_thread_description(
        history[-1]["content"],
        conversation_history=history,
    )
    assert description is not None
    assert "sleep" in description.casefold()
    assert "Follow up on" in description


def test_infer_thread_title_from_workout_habit_is_not_raw_message() -> None:
    title = infer_thread_title(
        "I've been trying to rebuild my workout habit this month.",
    )
    assert title != "I've Been Trying To Rebuild My Workout Habit This Month"
    assert "workout" in title.casefold() or "habit" in title.casefold()
    assert len(title) <= 60
