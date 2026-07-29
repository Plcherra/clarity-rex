"""Phase D: memory / person Knows actions via gated Grok actions."""

from __future__ import annotations

import pytest

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import BrainAction, parse_brain_actions
from app.services.capability_dispatcher import dispatch_allowed_actions
from app.services.durable_write_service import DurableWriteService
from chat_service_fakes import FakeMemoryService


def _settings(**kwargs) -> AssistantProposalSettings:
    return AssistantProposalSettings(memory=True, threads=True, goals=True, **kwargs)


async def _dispatch(
    *,
    store: FakeMemoryService,
    settings: AssistantProposalSettings,
    action: BrainAction,
    user_text: str,
    assistant_reply: str = "Got it.",
) -> dict | None:
    durable = DurableWriteService(memory_service=store)
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message=user_text,
    )
    return await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": user_text},
        assistant_reply=assistant_reply,
    )


@pytest.mark.asyncio
async def test_card_soft_save_memory_emits_write_proposal() -> None:
    store = FakeMemoryService()
    action = BrainAction(
        name="save_memory",
        payload={"content": "I prefer dark mode", "memory_type": "preference"},
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=action,
        user_text="Remember I prefer dark mode",
        assistant_reply="Dark mode noted — I'll keep that.",
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes["created"] == 0
    assert changes["write_proposals"]
    assert changes["write_proposals"][0]["write_kind"] == "memory"
    assert store.long_term_memory == []
    assert "dark mode" in result["response"].lower()


@pytest.mark.asyncio
async def test_card_save_memory_confirm_applies() -> None:
    store = FakeMemoryService()
    durable = DurableWriteService(memory_service=store)
    settings = _settings(mode="card")
    action = BrainAction(
        name="save_memory",
        payload={"content": "I prefer dark mode", "memory_type": "preference"},
    )
    gate = apply_auto_suggestions_gate([action], settings, user_message="remember")
    proposed = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "Remember dark mode"},
        assistant_reply="Got it.",
    )
    assert proposed is not None
    proposal = proposed["memory_changes"]["write_proposals"][0]
    confirmed = await durable.try_handle_pending(
        "yes",
        pending_action=await store.get_conversation_pending_action("c1"),
        conversation_id="c1",
        user_message={"id": "u2", "content": "yes"},
        write_confirmation={"proposal_id": proposal["id"]},
    )
    assert confirmed is not None
    assert confirmed["memory_changes"]["created"] == 1
    assert len(store.long_term_memory) == 1
    assert "dark mode" in store.long_term_memory[0]["content"].lower()


@pytest.mark.asyncio
async def test_text_soft_save_memory_proposes_without_cards() -> None:
    store = FakeMemoryService()
    result = await _dispatch(
        store=store,
        settings=_settings(mode="text"),
        action=BrainAction(
            name="save_memory",
            payload={"content": "I hate cilantro"},
        ),
        user_text="Remember I hate cilantro",
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes.get("write_proposals") in (None, [])
    assert changes.get("text_confirmation_pending") is True
    assert "say yes" in result["response"].lower()
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_off_explicit_save_memory_applies_immediately() -> None:
    store = FakeMemoryService()
    result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="save_memory",
            payload={"content": "I prefer dark mode"},
            explicit=True,
            auto=False,
        ),
        user_text="Please save that I prefer dark mode",
        assistant_reply="Saving that preference.",
    )
    assert result is not None
    assert result["memory_changes"]["created"] == 1
    assert len(store.long_term_memory) == 1
    assert "knows" in result["response"].lower()


@pytest.mark.asyncio
async def test_off_soft_save_memory_is_dropped() -> None:
    store = FakeMemoryService()
    result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="save_memory",
            payload={"content": "I prefer dark mode"},
            explicit=False,
            auto=True,
        ),
        user_text="I prefer dark mode",
    )
    assert result is None
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_save_person_card_proposal() -> None:
    store = FakeMemoryService()
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="save_person",
            payload={
                "display_name": "Ana",
                "relationship": "mom",
            },
        ),
        user_text="My mom's name is Ana",
        assistant_reply="I can save Ana as your mom.",
    )
    assert result is not None
    proposal = result["memory_changes"]["write_proposals"][0]
    assert proposal.get("person_card") is not None
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_update_person_state_and_note() -> None:
    store = FakeMemoryService()
    entity = await store.create_entity(
        {
            "entity_type": "person",
            "display_name": "Ana",
            "normalized_name": "ana",
            "relationship": "mother",
            "summary": "Mom",
            "aliases": [],
            "metadata": {"attributes": {"notes": "Lives nearby"}},
            "active": True,
        }
    )
    state_result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="update_person_state",
            payload={
                "person_id": entity["id"],
                "state": "Visiting this week",
            },
        ),
        user_text="Mom is visiting this week",
    )
    assert state_result is not None
    assert state_result["memory_changes"]["confirmation_required"] == 1
    assert entity["summary"] == "Mom"

    durable = DurableWriteService(memory_service=store)
    proposal = state_result["memory_changes"]["write_proposals"][0]
    await durable.try_handle_pending(
        "yes",
        pending_action=await store.get_conversation_pending_action("c1"),
        conversation_id="c1",
        user_message={"id": "u2", "content": "yes"},
        write_confirmation={"proposal_id": proposal["id"]},
    )
    assert entity["summary"] == "Visiting this week"

    note_result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="add_person_note",
            payload={
                "person_id": entity["id"],
                "note": "Brought pasta",
            },
            explicit=True,
            auto=False,
        ),
        user_text="Add a note that mom brought pasta",
    )
    assert note_result is not None
    assert note_result["memory_changes"]["updated"] == 1
    notes = entity["metadata"]["attributes"]["notes"]
    assert "Lives nearby" in notes
    assert "Brought pasta" in notes


@pytest.mark.asyncio
async def test_delete_knows_item_by_id() -> None:
    store = FakeMemoryService()
    memory = await store.save_long_term_memory(
        memory_type="preference",
        content="I prefer dark mode",
        importance=3,
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="delete_knows_item",
            payload={
                "id": memory["id"],
                "table": "long_term_memory",
                "title": "I prefer dark mode",
            },
        ),
        user_text="Delete my dark mode preference",
    )
    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert memory.get("active", True) is True

    durable = DurableWriteService(memory_service=store)
    proposal = result["memory_changes"]["write_proposals"][0]
    confirmed = await durable.try_handle_pending(
        "yes",
        pending_action=await store.get_conversation_pending_action("c1"),
        conversation_id="c1",
        user_message={"id": "u2", "content": "yes"},
        write_confirmation={"proposal_id": proposal["id"]},
    )
    assert confirmed is not None
    assert confirmed["memory_changes"]["archived"] == 1
    assert all(row.get("id") != memory["id"] for row in store.long_term_memory)


def test_parse_save_memory_action_aliases() -> None:
    parsed = parse_brain_actions(
        'Sure.\n```rex_action\n{"action":"save_memory","content":"Tea over coffee"}\n```'
    )
    assert len(parsed.actions) == 1
    assert parsed.actions[0].name == "save_memory"
    assert parsed.actions[0].payload.get("content") == "Tea over coffee"
