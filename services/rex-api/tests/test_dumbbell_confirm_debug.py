"""Regression: voice-style dumbbell goal propose + confirm saves to Goals."""

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import FakeAIService, FakeMemoryService
from app.services.chat_service import ChatService
from app.services.durable_write_pending import proposal_from_pending_action
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService


def _chat_service(memory_service: FakeMemoryService) -> ChatService:
    return ChatService(
        FakeAIService(),
        FileService(),
        memory_service,
        time_context_service=TimeContextService(
            timezone_name="America/New_York",
            now_provider=lambda: datetime(
                2026,
                6,
                1,
                12,
                0,
                tzinfo=ZoneInfo("America/New_York"),
            ),
        ),
    )


@pytest.mark.asyncio
async def test_dumbbell_goal_confirm_creates_plan():
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message(
        "Alright. So we agree on locked up on the go to buy dumbbells "
        "from maybe 40 to sixty pounds."
    )

    proposals = proposed["memory_changes"].get("write_proposals") or []
    assert proposals, proposed["response"]
    assert proposals[0]["write_kind"] == "plan"

    pending = memory_service.pending_actions.get(proposed["conversation_id"])
    assert pending is not None
    prop = proposal_from_pending_action(pending)
    payload = (prop.apply_snapshot or {}).get("payload") or {}
    assert payload.get("target_date") is None

    proposal = proposals[0]
    confirmed = await chat_service.send_message(
        "Yes",
        proposed["conversation_id"],
        write_confirmation={
            "proposal_id": proposal["id"],
            "edits": {"title": proposal["title"], "body": proposal["body"]},
        },
    )

    assert confirmed["memory_changes"]["created"] == 1, confirmed["response"]
    assert len(memory_service.plans) == 1
