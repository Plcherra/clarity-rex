import pytest

from app.services.goal_context_service import GoalContextService


class FakeGoalMemoryStore:
    def __init__(self):
        self.plans = [
            {
                "id": "plan-1",
                "title": "Plan A",
                "status": "active",
                "active": True,
            }
        ]
        self.milestones = [
            {
                "id": "milestone-1",
                "plan_id": "plan-1",
                "title": "Linked step",
                "active": True,
            },
            {
                "id": "milestone-2",
                "plan_id": "plan-99",
                "title": "Unrelated step",
                "active": True,
            },
        ]

    async def list_plans(self, **kwargs):
        return self.plans

    async def list_plan_milestones(self, **kwargs):
        return self.milestones


@pytest.mark.asyncio
async def test_goal_context_filters_milestones_to_active_plans():
    service = GoalContextService()
    store = FakeGoalMemoryStore()

    context = await service.fetch_goal_context(store, "How are my goals going?")

    assert [milestone["title"] for milestone in context["plan_milestones"]] == [
        "Linked step"
    ]
    assert context["goal_context"]["related_milestone_count"] == 1
