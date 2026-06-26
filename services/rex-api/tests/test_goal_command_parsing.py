from app.services.goal_command_parsing import (
    is_meta_instruction_body,
    split_compound_goal_bodies,
    target_date_for_message,
)
from app.services.memory_delete_reference import (
    pending_delete_target_from_history,
    should_defer_to_delete_confirmation,
)


def test_meta_instruction_body_is_rejected():
    assert is_meta_instruction_body("a goal/commitment")
    assert is_meta_instruction_body("be a goal/commitment")
    assert is_meta_instruction_body("goal or commitment")
    assert not is_meta_instruction_body("Get 32GB RAM by next month")


def test_split_compound_hardware_goals():
    items = split_compound_goal_bodies(
        "Get 32gb-64gb ram and 1tb-2tb storage"
    )
    assert len(items) == 2
    assert "ram" in items[0].casefold()
    assert "storage" in items[1].casefold() or "tb" in items[1].casefold()


def test_split_numbered_hardware_goals():
    items = split_compound_goal_bodies(
        "2 goals. 1 buy 32-64gb ram. 2 buy 1-2tb storage"
    )
    assert len(items) == 2
    assert "ram" in items[0].casefold()
    assert "storage" in items[1].casefold() or "tb" in items[1].casefold()


def test_should_defer_to_delete_confirmation():
    history = [
        {
            "role": "assistant",
            "content": (
                "Do you want me to delete the commitment 'Be a goal/commitment'?"
            ),
        }
    ]
    assert should_defer_to_delete_confirmation("Yes", history)


def test_pending_delete_target_from_llm_prompt():
    history = [
        {
            "role": "assistant",
            "content": (
                "Do you want me to delete the commitment 'Be a goal/commitment'?"
            ),
        }
    ]
    assert pending_delete_target_from_history(history) == "Be a goal/commitment"


def test_next_month_resolves_to_last_day():
    assert target_date_for_message(
        "by next month",
        time_context={"date": "2026-06-04"},
    ) == "July 31"
