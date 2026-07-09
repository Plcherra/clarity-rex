from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import FakeAIService, FakeMemoryService
from durable_write_test_helpers import assert_companion_continuation_response, confirm_durable_write
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.plan_target_date_parsing import (
    looks_like_plan_target_date_update,
    resolve_plan_target_date_iso,
    selects_all_active_plans,
)
from app.services.time_context_service import TimeContextService


def _fixed_time_context_service():
    return TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: datetime(
            2026,
            6,
            1,
            12,
            0,
            tzinfo=ZoneInfo("America/New_York"),
        ),
    )


def _time_context() -> dict:
    return {"date": "2026-06-01", "timezone": "America/New_York"}


def _chat_service(memory_service: FakeMemoryService) -> ChatService:
    return ChatService(
        FakeAIService(response="Rex normal response"),
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )


def test_plan_target_date_parsing_detects_bulk_update_request():
    message = (
        "Can you add a date for the goal I saved and the other 2 goals? "
        "Set end of July for all three goals."
    )
    assert looks_like_plan_target_date_update(message)
    assert selects_all_active_plans(message)
    assert resolve_plan_target_date_iso(message, time_context=_time_context()) == "2026-07-31"


@pytest.mark.asyncio
async def test_bulk_plan_target_date_proposes_and_applies_on_confirm():
    memory_service = FakeMemoryService()
    for index, title in enumerate(("Buy dumbbells", "Run 5k", "Save $500"), start=1):
        memory_service.plans.append(
            {
                "id": f"plan-{index}",
                "plan_type": "personal",
                "title": title,
                "active": True,
                "status": "active",
            }
        )
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message(
        "Set end of July for all three goals."
    )

    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = proposed["memory_changes"]["write_proposals"][0]
    assert proposal["write_kind"] == "update_plan"
    assert "July 31, 2026" in proposal["body"]
    assert "Tap confirm to save" in proposed["response"]
    assert "nothing is saved until you confirm" in proposed["response"]

    confirmed = await confirm_durable_write(chat_service, proposed)

    assert_companion_continuation_response(
        confirmed,
        expected_response="Rex normal response",
    )
    assert confirmed["memory_changes"]["updated"] == 3
    for plan in memory_service.plans:
        assert plan.get("target_date") == "2026-07-31"


@pytest.mark.asyncio
async def test_plan_target_date_update_targets_goals_missing_dates():
    memory_service = FakeMemoryService()
    memory_service.plans.extend(
        [
            {
                "id": "plan-dated",
                "plan_type": "personal",
                "title": "Already dated",
                "active": True,
                "status": "active",
                "target_date": "2026-08-01",
            },
            {
                "id": "plan-missing",
                "plan_type": "personal",
                "title": "Needs a date",
                "active": True,
                "status": "active",
            },
        ]
    )
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("Add a target date of end of July.")

    proposal = proposed["memory_changes"]["write_proposals"][0]
    assert "Needs a date" in proposal["body"]
    assert "Already dated" not in proposal["body"]
