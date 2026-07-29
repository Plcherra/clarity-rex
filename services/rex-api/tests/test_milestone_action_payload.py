"""Unit tests for milestone action payload identity vs rename."""

from __future__ import annotations

from app.services.capabilities.milestone_action_payload import (
    create_milestone_fields_from_payload,
    delete_milestone_fields_from_payload,
    update_milestone_fields_from_payload,
)


def test_create_requires_title() -> None:
    assert create_milestone_fields_from_payload({"plan_id": "p1"}) is None
    fields = create_milestone_fields_from_payload(
        {"title": "Order RAM", "plan_id": "p1", "description": "Buy stick"}
    )
    assert fields is not None
    assert fields.title == "Order RAM"
    assert fields.plan_id == "p1"
    assert fields.description == "Buy stick"


def test_create_accepts_goal_title_parent() -> None:
    fields = create_milestone_fields_from_payload(
        {"title": "Order RAM", "goal_title": "Buy 32GB RAM"}
    )
    assert fields is not None
    assert fields.parent_reference == "Buy 32GB RAM"
    assert fields.plan_id is None


def test_create_ignores_bare_reference_as_parent() -> None:
    fields = create_milestone_fields_from_payload(
        {"title": "Order RAM", "reference": "Order RAM"}
    )
    assert fields is not None
    assert fields.parent_reference is None
    assert fields.title == "Order RAM"


def test_update_new_title_alone_returns_none() -> None:
    assert update_milestone_fields_from_payload({"new_title": "Order 32GB"}) is None


def test_update_existing_plus_new_title() -> None:
    fields = update_milestone_fields_from_payload(
        {
            "existing_title": "Order 16GB",
            "new_title": "Order 32GB",
            "plan_id": "p1",
        }
    )
    assert fields is not None
    assert fields.reference == "Order 16GB"
    assert fields.title == "Order 32GB"
    assert fields.plan_id == "p1"


def test_update_milestone_id_with_title_rename() -> None:
    fields = update_milestone_fields_from_payload(
        {"milestone_id": "m1", "title": "Renamed step"}
    )
    assert fields is not None
    assert fields.milestone_id == "m1"
    assert fields.title == "Renamed step"


def test_delete_requires_identity() -> None:
    assert delete_milestone_fields_from_payload({}) is None
    fields = delete_milestone_fields_from_payload(
        {"reference": "Order RAM", "plan_id": "p1"}
    )
    assert fields is not None
    assert fields.reference == "Order RAM"
    assert fields.plan_id == "p1"
