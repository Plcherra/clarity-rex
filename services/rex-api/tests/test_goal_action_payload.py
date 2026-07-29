"""Unit tests for goal action payload identity (lookup vs new_title)."""

from __future__ import annotations

from app.services.capabilities.goal_action_payload import (
    update_goal_fields_from_payload,
)


def test_new_title_only_does_not_become_lookup() -> None:
    """new_title alone must not find a plan — rename without identity → None."""
    fields = update_goal_fields_from_payload({"new_title": "Buy 32GB RAM"})
    assert fields is None


def test_new_title_only_with_body_still_needs_identity() -> None:
    fields = update_goal_fields_from_payload(
        {
            "new_title": "Buy 32GB RAM",
            "description": "Need more memory",
        }
    )
    assert fields is None


def test_existing_title_plus_new_title_separates_lookup_and_rename() -> None:
    fields = update_goal_fields_from_payload(
        {
            "existing_title": "Buy 16GB RAM",
            "new_title": "Buy 32GB RAM",
            "description": "Upgrade Clarity laptop",
        }
    )
    assert fields is not None
    assert fields.plan_id is None
    assert fields.reference == "Buy 16GB RAM"
    assert fields.title == "Buy 32GB RAM"
    assert fields.body == "Upgrade Clarity laptop"


def test_reference_plus_new_title_separates_lookup_and_rename() -> None:
    fields = update_goal_fields_from_payload(
        {
            "reference": "Buy 16GB RAM",
            "new_title": "Buy 32GB RAM",
        }
    )
    assert fields is not None
    assert fields.reference == "Buy 16GB RAM"
    assert fields.title == "Buy 32GB RAM"


def test_title_plus_new_title_uses_title_as_lookup() -> None:
    fields = update_goal_fields_from_payload(
        {
            "title": "Buy 16GB RAM",
            "new_title": "Buy 32GB RAM",
        }
    )
    assert fields is not None
    assert fields.reference == "Buy 16GB RAM"
    assert fields.title == "Buy 32GB RAM"


def test_title_only_finds_goal_with_that_title() -> None:
    """Title-only without plan_id/reference: find the goal with this title."""
    fields = update_goal_fields_from_payload({"title": "Buy 16GB RAM"})
    assert fields is not None
    assert fields.reference == "Buy 16GB RAM"
    assert fields.title == "Buy 16GB RAM"


def test_plan_id_path_keeps_new_title_as_rename_only() -> None:
    fields = update_goal_fields_from_payload(
        {
            "plan_id": "plan-1",
            "new_title": "Buy 32GB RAM",
            "description": "Need more memory for Clarity",
        }
    )
    assert fields is not None
    assert fields.plan_id == "plan-1"
    assert fields.reference is None
    assert fields.title == "Buy 32GB RAM"
    assert fields.body == "Need more memory for Clarity"


def test_plan_id_plus_title_unchanged() -> None:
    fields = update_goal_fields_from_payload(
        {
            "plan_id": "plan-1",
            "title": "Buy 32GB RAM",
            "description": "Need more memory for Clarity",
        }
    )
    assert fields is not None
    assert fields.plan_id == "plan-1"
    assert fields.title == "Buy 32GB RAM"
    assert fields.body == "Need more memory for Clarity"


def test_target_title_is_lookup_not_new_title() -> None:
    fields = update_goal_fields_from_payload(
        {
            "target_title": "Buy 16GB RAM",
            "title": "Buy 32GB RAM",
        }
    )
    assert fields is not None
    assert fields.reference == "Buy 16GB RAM"
    assert fields.title == "Buy 32GB RAM"
