from app.services.goal_command_parsing import (
    is_goals_inventory_query,
    is_meta_instruction_body,
    goals_inventory_scope,
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
    assert items[0].casefold().startswith("get 32")
    assert "ram" in items[0].casefold()
    assert "storage" in items[1].casefold() or "tb" in items[1].casefold()
    assert not items[0].startswith("1 ")
    assert not items[1].startswith("2 ")


def test_expand_goal_save_items_uses_title_or_body():
    from app.services.goal_command_parsing import expand_goal_save_items

    items = expand_goal_save_items(
        title="2 goals. 1 buy 32-64gb ram. 2 buy 1-2tb storage",
    )
    assert len(items) == 2


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


def test_goals_inventory_query_detects_commitment_list_question():
    assert is_goals_inventory_query("What commitments do we have saved?")
    assert goals_inventory_scope("What commitments do we have saved?") == "commitments"
    assert is_goals_inventory_query("What do you have saved on goals?")
    assert goals_inventory_scope("What do you have saved on goals?") == "goals"
    assert is_goals_inventory_query("What kind of commitment do I have then?")
    assert goals_inventory_scope("What kind of commitment do I have then?") == "commitments"


def test_goals_inventory_query_is_not_delete_clarification():
    history = [
        {
            "role": "assistant",
            "content": (
                "I couldn't find an active saved memory matching that, so I "
                "didn't delete anything."
            ),
        }
    ]
    from app.services.memory_delete_reference import is_delete_clarification_message

    assert not is_delete_clarification_message(
        "What commitments do we have saved?",
        history,
    )
