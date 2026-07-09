"""Person confirm-card proposal, mode gating, and apply field gate."""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.memory_intent_models import SimpleMemoryIntent
from app.services.memory_turn_handle import (
    MemoryTurnHandleMixin,
    _missing_person_field_prompt,
)
from app.services.person_confirm_proposal import (
    count_person_card_fields,
    person_card_from_intent,
    proposal_from_relationship_memory,
)
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


def _relationship_intent(*, name: str = "Ariadyna", relationship: str = "mother"):
    return SimpleMemoryIntent(
        memory_type="fact",
        content=f"User's {relationship} is {name}.",
        importance=8,
        metadata={
            "fact_kind": "relationship",
            "relationship": relationship,
            "entity_label": name.casefold(),
            "memory_category": "People",
            "topic_fingerprint": f"fact:relationship:{relationship}",
        },
    )


def _relationship_only_intent(*, relationship: str = "mother"):
    return SimpleMemoryIntent(
        memory_type="fact",
        content=f"User has a {relationship}.",
        importance=8,
        metadata={
            "fact_kind": "relationship",
            "relationship": relationship,
            "memory_category": "People",
            "topic_fingerprint": f"fact:relationship:{relationship}",
        },
    )


def test_person_card_from_intent_counts_inferred_relationship():
    intent = _relationship_intent()
    card = person_card_from_intent(intent)
    assert card["relationship"] == "mother"
    assert card["display_name"] == "Ariadyna"
    assert count_person_card_fields(card) == 2


def test_proposal_includes_person_card_and_merge_hint():
    intent = _relationship_intent()
    proposal = proposal_from_relationship_memory(
        intent,
        related={
            "birthday": "June 18",
            "merge_hint": "We already have related info about your mother.",
            "related_summary": "birthday June 18",
        },
    )
    client = proposal.to_client_dict()
    assert client["person_card"]["display_name"] == "Ariadyna"
    assert client["person_card"]["relationship"] == "mother"
    assert client["person_card"]["birthday"] == "June 18"
    assert "related info" in (client["person_card"].get("merge_hint") or "").casefold()
    assert "display_name" in client["editable_fields"]


def test_text_mode_missing_field_prompt_asks_for_name():
    card = person_card_from_intent(_relationship_only_intent())
    assert count_person_card_fields(card) == 1
    prompt = _missing_person_field_prompt(card)
    assert "name" in prompt.casefold()


@pytest.mark.asyncio
async def test_text_mode_gate_asks_for_second_field():
    class _Harness(MemoryTurnHandleMixin):
        def __init__(self):
            self.memory_service = FakeMemoryService()

    harness = _Harness()
    result = await harness._gate_relationship_person_intent(
        _relationship_only_intent(),
        conversation_id="conv-1",
        user_message={"id": "m1", "content": "save my mom"},
        proposal_settings=AssistantProposalSettings(mode="text"),
    )
    assert isinstance(result, dict)
    assert "name" in result["response"].casefold()
    assert result["memory_changes"]["confirmation_required"] == 0


@pytest.mark.asyncio
async def test_card_mode_relationship_proposal_includes_person_card(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
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
    assert proposed["memory_changes"]["confirmation_required"] == 1
    proposal = proposed["memory_changes"]["write_proposals"][0]
    assert proposal["person_card"]["display_name"] == "Ariadyna"
    assert proposal["person_card"]["relationship"] == "mother"
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_off_mode_skips_chat_people_propose(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "off")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = ChatService(
        FakeAIService(response="Rex companion reply"),
        FileService(),
        FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )
    result = await chat_service.send_message(
        "Can you save my mom's name as Ariadyna?"
    )
    memory_changes = result.get("memory_changes") or {}
    proposals = memory_changes.get("write_proposals") or []
    assert not proposals
    assert memory_changes.get("confirmation_required", 0) == 0
    assert chat_service.ai_service.generate_calls == 1
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_person_card_apply_rejects_insufficient_fields(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
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
    failed = await confirm_durable_write(
        chat_service,
        proposed,
        edits={
            "display_name": "Ariadyna",
            "relationship": "",
            "birthday": "",
            "notes": "",
        },
    )
    assert "two person details" in failed["response"].casefold()
    proposals = failed["memory_changes"].get("write_proposals") or []
    assert proposals and proposals[0].get("status") == "failed"
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_card_mode_merge_hint_when_birthday_flat_exists(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
    from app.config import get_settings

    get_settings.cache_clear()
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "mem-bday",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "active": True,
            "metadata": {
                "fact_kind": "birthday",
                "relationship": "mother",
                "normalized_date": "June 18",
                "memory_category": "Events",
            },
        }
    )
    chat_service = ChatService(
        FakeAIService(),
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )
    proposed = await chat_service.send_message(
        "Can you save my mom's name as Ariadyna?"
    )
    proposal = proposed["memory_changes"]["write_proposals"][0]
    assert proposal["person_card"]["birthday"] == "June 18"
    assert proposal["person_card"].get("merge_hint")
    get_settings.cache_clear()


def test_with_edits_rewrites_person_snapshot():
    intent = _relationship_intent()
    proposal = proposal_from_relationship_memory(intent)
    edited = proposal.with_edits(
        {
            "display_name": "Maria",
            "relationship": "mother",
            "birthday": "June 18",
            "notes": "Loves tea",
        }
    )
    assert edited.person_card["display_name"] == "Maria"
    assert edited.person_card["birthday"] == "June 18"
    payload = edited.apply_snapshot["payload"]
    assert "Maria" in payload["content"]
    assert payload["metadata"]["relationship"] == "mother"
    assert payload["metadata"]["person_card"]["notes"] == "Loves tea"


def test_settings_helpers_for_modes():
    assert AssistantProposalSettings(mode="card").uses_confirm_cards()
    assert AssistantProposalSettings(mode="text").uses_text_offers()
    assert not AssistantProposalSettings(mode="off").allows_kind("memory")
