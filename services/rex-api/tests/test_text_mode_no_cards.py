"""Text mode still proposes durable writes with confirm cards.

Confirm cards are the truth path — text mode must not hide them.
"""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.chat_service import ChatService
from app.services.durable_write_results import pending_memory_changes
from app.services.durable_write_proposal import DurableWriteProposal
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService
from durable_write_test_helpers import confirm_durable_write


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


def test_pending_memory_changes_can_omit_client_cards():
    proposal = DurableWriteProposal(
        write_kind="memory",
        title="Mom birthday",
        body="User's mom's birthday is June 18.",
    )
    with_cards = pending_memory_changes(proposal=proposal, surface_client_cards=True)
    without = pending_memory_changes(proposal=proposal, surface_client_cards=False)
    assert with_cards["confirmation_required"] == 1
    assert with_cards["write_proposals"]
    assert without["confirmation_required"] == 1
    assert without["write_proposals"] == []
    assert without["text_confirmation_pending"] is True
    assert without["pending_proposal_id"] == proposal.proposal_id


@pytest.mark.asyncio
async def test_text_mode_memory_propose_still_includes_write_proposals(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "text")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = ChatService(
        FakeAIService(),
        FileService(),
        FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )
    proposed = await chat_service.send_message("My mom's birthday is June 18")
    changes = proposed["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes.get("write_proposals")
    assert changes.get("text_confirmation_pending") is not True

    saved = await confirm_durable_write(chat_service, proposed)
    assert saved["memory_changes"]["created"] == 1 or saved["memory_changes"].get(
        "updated", 0
    ) >= 1
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_card_mode_memory_propose_includes_write_proposals(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = ChatService(
        FakeAIService(),
        FileService(),
        FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )
    proposed = await chat_service.send_message("My mom's birthday is June 18")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    assert proposed["memory_changes"]["write_proposals"]
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_text_mode_relationship_propose_includes_person_card(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "text")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = ChatService(
        FakeAIService(),
        FileService(),
        FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )
    proposed = await chat_service.send_message(
        "Can you save my mom's name as Ariadyna?"
    )
    changes = proposed["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes.get("write_proposals")
    assert "person_card" in str(changes).casefold() or any(
        (proposal.get("write_kind") == "person" or "person" in str(proposal).casefold())
        for proposal in (changes.get("write_proposals") or [])
        if isinstance(proposal, dict)
    )
    get_settings.cache_clear()
