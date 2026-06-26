from app.services.goal_context_service import GoalContextService


def test_standalone_commitments_remain_when_active_plans_exist():
    service = GoalContextService()
    plan_ids = {"plan-1"}
    standalone = {
        "id": "commitment-1",
        "title": "Be a goal/commitment",
        "status": "open",
    }
    linked = {
        "id": "commitment-2",
        "title": "Review spending weekly",
        "status": "open",
        "plan_id": "plan-1",
    }
    unrelated = {
        "id": "commitment-3",
        "title": "Other plan task",
        "status": "open",
        "plan_id": "plan-99",
    }

    assert service._is_related_commitment(standalone, plan_ids)
    assert service._is_related_commitment(linked, plan_ids)
    assert not service._is_related_commitment(unrelated, plan_ids)
