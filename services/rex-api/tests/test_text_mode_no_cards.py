"""Auto Suggestions modes change how a write is confirmed, never whether it is.

Text mode asks in prose and Card mode sends a confirm card, but neither may
save before the user agrees.
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
from chat_service_fakes import FakeMemoryService
from durable_write_test_helpers import confirm_durable_write
from scripted_brain_fakes import ScriptedAIService, reply_with_action

SAVE_BRAIN = {
    "mom's birthday": reply_with_action(
        "June 18 — good to know.",
        "save_memory",
        {"content": "User's mom's birthday is June 18.", "memory_type": "fact"},
    ),
    "mom's name": reply_with_action(
        "I can save Ariadyna as your mom.",
        "save_person",
        {"display_name": "Ariadyna", "relationship": "mom"},
    ),
}


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


def _chat_service(memory_service: FakeMemoryService) -> ChatService:
    return ChatService(
        ScriptedAIService(SAVE_BRAIN),
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )


@pytest.fixture
def proposals_mode(monkeypatch):
    from app.config import get_settings

    def _set(mode: str) -> None:
        monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", mode)
        get_settings.cache_clear()

    yield _set
    get_settings.cache_clear()


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
async def test_text_mode_asks_in_prose_and_sends_no_cards(proposals_mode):
    proposals_mode("text")
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    changes = proposed["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes["write_proposals"] == []
    assert changes["text_confirmation_pending"] is True
    assert changes["pending_proposal_id"]
    assert memory_service.long_term_memory == []
    assert "say yes" in proposed["response"].casefold()


@pytest.mark.asyncio
async def test_text_mode_confirmation_still_saves(proposals_mode):
    proposals_mode("text")
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    saved = await confirm_durable_write(chat_service, proposed)

    changes = saved["memory_changes"]
    assert changes["confirmation_required"] == 0
    assert changes["created"] + changes.get("updated", 0) >= 1
    assert memory_service.long_term_memory or memory_service.entities


@pytest.mark.asyncio
async def test_card_mode_sends_a_confirm_card(proposals_mode):
    proposals_mode("card")
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    changes = proposed["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes["write_proposals"]
    assert changes["write_proposals"][0]["write_kind"] == "memory"
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_card_mode_person_proposal_carries_the_person_card(proposals_mode):
    proposals_mode("card")
    memory_service = FakeMemoryService()
    chat_service = _chat_service(memory_service)

    proposed = await chat_service.send_message("Can you save my mom's name as Ariadyna?")
    proposal = proposed["memory_changes"]["write_proposals"][0]
    person_card = proposal.get("person_card") or {}

    assert person_card.get("display_name") == "Ariadyna"
    assert person_card.get("relationship") == "mother"
    assert memory_service.entities == []
