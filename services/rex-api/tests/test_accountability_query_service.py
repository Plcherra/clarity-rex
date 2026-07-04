import pytest

from app.routes.accountability_overview_builder import build_accountability_overview
from app.services.accountability_query_service import AccountabilityQueryService
from app.services.accountability_snapshot import (
    active_plans_for,
    open_milestones_for,
)


class FakeMemoryStore:
    def __init__(
        self,
        *,
        plans: list[dict] | None = None,
        milestones: list[dict] | None = None,
    ) -> None:
        self.plans = plans or []
        self.milestones = milestones or []
        self.plan_calls: list[dict] = []

    async def list_plans(self, **kwargs):
        self.plan_calls.append(kwargs)
        return self.plans


def _milestone(
    *,
    id: str,
    title: str,
    status: str = "open",
    active: bool = True,
) -> dict:
    return {
        "id": id,
        "plan_id": "plan-1",
        "title": title,
        "description": title,
        "status": status,
        "active": active,
    }


def _plan(
    *,
    id: str,
    title: str,
    status: str = "active",
    active: bool = True,
) -> dict:
    return {
        "id": id,
        "title": title,
        "description": title,
        "status": status,
        "active": active,
    }


@pytest.mark.asyncio
async def test_list_active_plans_matches_overview_snapshot_filters():
    store = FakeMemoryStore(
        plans=[
            _plan(id="plan-1", title="Buy RAM"),
            _plan(id="plan-2", title="Paused plan", status="paused"),
            _plan(id="plan-3", title="Archived plan", active=False),
        ]
    )
    service = AccountabilityQueryService(store)

    active_rows = await service.list_active_plans()

    overview = build_accountability_overview(
        message="What goals do we have?",
        context={
            "plans": store.plans,
            "plan_milestones": [],
            "personal_rules": [],
            "entities": [],
            "open_threads": [],
        },
        signals=[],
        limit=25,
    )
    assert [row["id"] for row in active_rows] == [
        row["id"] for row in overview.active_plans
    ]
    assert [row["id"] for row in active_rows] == ["plan-1"]


@pytest.mark.asyncio
async def test_load_inventory_returns_active_plans():
    store = FakeMemoryStore(
        plans=[_plan(id="plan-1", title="Buy RAM")],
    )
    service = AccountabilityQueryService(store)

    inventory = await service.load_inventory(scope="goals")

    assert [row["id"] for row in inventory.active_plans] == ["plan-1"]


def test_format_inventory_response_lists_active_goals():
    service = AccountabilityQueryService(FakeMemoryStore())
    response = service.format_inventory_response(
        plans=[_plan(id="p-1", title="Buy RAM")],
        scope="goals",
    )

    assert "Active goals:" in response
    assert "Buy RAM" in response


def test_snapshot_filters_ignore_completed_and_inactive_rows():
    milestones = [
        _milestone(id="open-1", title="Open"),
        _milestone(id="done-1", title="Done", status="completed"),
        _milestone(id="inactive-1", title="Inactive", active=False),
    ]
    plans = [
        _plan(id="active-1", title="Active"),
        _plan(id="paused-1", title="Paused", status="paused"),
    ]

    assert [row["id"] for row in open_milestones_for(milestones)] == ["open-1"]
    assert [row["id"] for row in active_plans_for(plans)] == ["active-1"]
