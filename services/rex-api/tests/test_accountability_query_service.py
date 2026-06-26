import pytest

from app.routes.accountability_overview_builder import build_accountability_overview
from app.services.accountability_query_service import AccountabilityQueryService
from app.services.accountability_snapshot import (
    active_plans_for,
    open_commitments_for,
)


class FakeMemoryStore:
    def __init__(
        self,
        *,
        plans: list[dict] | None = None,
        commitments: list[dict] | None = None,
    ) -> None:
        self.plans = plans or []
        self.commitments = commitments or []
        self.plan_calls: list[dict] = []
        self.commitment_calls: list[dict] = []

    async def list_plans(self, **kwargs):
        self.plan_calls.append(kwargs)
        return self.plans

    async def list_commitments(self, **kwargs):
        self.commitment_calls.append(kwargs)
        return self.commitments


def _commitment(
    *,
    id: str,
    title: str,
    status: str = "open",
    active: bool = True,
) -> dict:
    return {
        "id": id,
        "title": title,
        "commitment_text": title,
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
async def test_list_open_commitments_matches_overview_snapshot_filters():
    store = FakeMemoryStore(
        commitments=[
            _commitment(id="open-1", title="Wake at 5 AM"),
            _commitment(id="done-1", title="Finished task", status="completed"),
            _commitment(id="inactive-1", title="Archived", active=False),
        ]
    )
    service = AccountabilityQueryService(store)

    open_rows = await service.list_open_commitments()

    overview = build_accountability_overview(
        message="What commitments do we have?",
        context={
            "commitments": store.commitments,
            "plans": [],
            "plan_milestones": [],
            "personal_rules": [],
            "entities": [],
        },
        signals=[],
        limit=25,
    )
    assert [row["id"] for row in open_rows] == [
        row["id"] for row in overview.open_commitments
    ]
    assert [row["id"] for row in open_rows] == ["open-1"]


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
            "commitments": [],
            "plans": store.plans,
            "plan_milestones": [],
            "personal_rules": [],
            "entities": [],
        },
        signals=[],
        limit=25,
    )
    assert [row["id"] for row in active_rows] == [
        row["id"] for row in overview.active_plans
    ]
    assert [row["id"] for row in active_rows] == ["plan-1"]


@pytest.mark.asyncio
async def test_load_inventory_respects_scope():
    store = FakeMemoryStore(
        plans=[_plan(id="plan-1", title="Buy RAM")],
        commitments=[_commitment(id="commitment-1", title="Wake at 5 AM")],
    )
    service = AccountabilityQueryService(store)

    goals_only = await service.load_inventory(scope="goals")
    commitments_only = await service.load_inventory(scope="commitments")
    both = await service.load_inventory(scope="both")

    assert [row["id"] for row in goals_only.active_plans] == ["plan-1"]
    assert goals_only.open_commitments == []
    assert commitments_only.active_plans == []
    assert [row["id"] for row in commitments_only.open_commitments] == [
        "commitment-1"
    ]
    assert [row["id"] for row in both.active_plans] == ["plan-1"]
    assert [row["id"] for row in both.open_commitments] == ["commitment-1"]


def test_format_inventory_response_lists_commitments_only():
    service = AccountabilityQueryService(FakeMemoryStore())
    response = service.format_inventory_response(
        plans=[],
        commitments=[_commitment(id="c-1", title="Be a goal/commitment")],
        scope="commitments",
    )

    assert "Open commitments:" in response
    assert "Be a goal/commitment" in response
    assert "Active goals:" not in response


def test_snapshot_filters_ignore_completed_and_inactive_rows():
    commitments = [
        _commitment(id="open-1", title="Open"),
        _commitment(id="done-1", title="Done", status="completed"),
        _commitment(id="inactive-1", title="Inactive", active=False),
    ]
    plans = [
        _plan(id="active-1", title="Active"),
        _plan(id="paused-1", title="Paused", status="paused"),
    ]

    assert [row["id"] for row in open_commitments_for(commitments)] == ["open-1"]
    assert [row["id"] for row in active_plans_for(plans)] == ["active-1"]
