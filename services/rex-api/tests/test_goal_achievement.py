"""Finishing a goal: it leaves the active list, and Goals can still show it."""

from __future__ import annotations

from datetime import datetime, timezone

from app.routes.accountability_overview_builder import build_accountability_overview
from app.services.accountability_snapshot import achieved_plans_for
from app.services.plan_completion import with_completion_time


def _plan(**overrides) -> dict:
    return {
        "id": "plan-1",
        "title": "Buy dumbbells",
        "status": "active",
        "active": True,
        **overrides,
    }


def test_achieved_list_holds_only_finished_goals():
    achieved = achieved_plans_for(
        [
            _plan(),
            _plan(id="plan-2", status="completed"),
            _plan(id="plan-3", status="archived", active=False),
            _plan(id="plan-4", status="paused"),
        ]
    )

    assert [plan["id"] for plan in achieved] == ["plan-2"]


def test_most_recently_finished_goal_comes_first():
    achieved = achieved_plans_for(
        [
            _plan(id="older", status="completed", completed_at="2026-05-01T00:00:00Z"),
            _plan(id="newer", status="completed", completed_at="2026-07-30T00:00:00Z"),
            _plan(id="undated", status="completed", updated_at="2026-06-01T00:00:00Z"),
        ]
    )

    assert [plan["id"] for plan in achieved] == ["newer", "undated", "older"]


def test_a_finished_goal_is_dropped_from_active_and_kept_in_achieved():
    overview = build_accountability_overview(
        message="",
        context={
            "plans": [_plan()],
            "achieved_plans": [_plan(id="plan-2", status="completed")],
            "plan_milestones": [],
            "personal_rules": [],
            "entities": [],
            "open_threads": [],
        },
        signals=[],
        limit=10,
    )

    assert [plan["id"] for plan in overview.active_plans] == ["plan-1"]
    assert [plan["id"] for plan in overview.achieved_plans] == ["plan-2"]
    assert overview.metadata["achieved_plan_count"] == 1


def test_marking_complete_records_when():
    stamped = with_completion_time(
        {"status": "completed"},
        now=datetime(2026, 7, 31, 12, 0, tzinfo=timezone.utc),
    )

    assert stamped["completed_at"] == "2026-07-31T12:00:00+00:00"


def test_other_edits_never_stamp_a_completion():
    assert with_completion_time({"title": "Buy dumbbells"}) == {
        "title": "Buy dumbbells"
    }


def test_reopening_clears_the_completion_stamp():
    assert with_completion_time({"status": "active"}) == {
        "status": "active",
        "completed_at": None,
    }


def test_a_caller_supplied_completion_time_is_kept():
    payload = {"status": "completed", "completed_at": "2026-01-01T00:00:00Z"}

    assert with_completion_time(payload) == payload
