from app.services.goal_command_parsing import (
    is_meta_instruction_body,
    split_compound_goal_bodies,
    target_date_for_message,
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


def test_next_month_resolves_to_last_day():
    assert target_date_for_message(
        "by next month",
        time_context={"date": "2026-06-04"},
    ) == "July 31"
