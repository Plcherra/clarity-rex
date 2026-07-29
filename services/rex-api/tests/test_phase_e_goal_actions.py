"""Phase E: goal create/update/delete via gated Grok actions."""

from __future__ import annotations

import pytest

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import BrainAction, parse_brain_actions
from app.services.capability_dispatcher import dispatch_allowed_actions
from app.services.durable_write_service import DurableWriteService
from app.services.tiny_system_prompt import build_tiny_system_prompt
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
async def test_card_soft_create_goal_emits_write_proposal() -> None:
    store = FakeMemoryService()
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="create_goal",
            payload={
                "title": "Buy 32GB RAM",
                "description": "Upgrade the Clarity laptop",
            },
        ),
        user_text="I want to buy 32GB of RAM for my laptop",
        assistant_reply="A RAM upgrade would help Clarity stay snappy.",
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes["created"] == 0
    assert changes["write_proposals"]
    assert changes["write_proposals"][0]["write_kind"] == "plan"
    assert store.plans == []
    assert "snappy" in result["response"].lower()
    assert "tap confirm" not in result["response"].lower()


@pytest.mark.asyncio
async def test_card_create_goal_confirm_applies() -> None:
    store = FakeMemoryService()
    durable = DurableWriteService(memory_service=store)
    settings = _settings(mode="card")
    action = BrainAction(
        name="create_goal",
        payload={"title": "Buy 32GB RAM", "description": "Laptop upgrade"},
    )
    gate = apply_auto_suggestions_gate([action], settings, user_message="buy ram")
    proposed = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "Save a goal to buy 32GB RAM"},
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
    assert len(store.plans) == 1
    assert "ram" in store.plans[0]["title"].lower()


@pytest.mark.asyncio
async def test_text_soft_create_goal_proposes_without_cards() -> None:
    store = FakeMemoryService()
    result = await _dispatch(
        store=store,
        settings=_settings(mode="text"),
        action=BrainAction(
            name="create_goal",
            payload={"title": "Launch Clarity"},
        ),
        user_text="I want to launch Clarity",
        assistant_reply="Launching Clarity is a solid finish line.",
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes.get("write_proposals") in (None, [])
    assert changes.get("text_confirmation_pending") is True
    assert "say yes" in result["response"].lower()
    assert store.plans == []


@pytest.mark.asyncio
async def test_off_explicit_create_goal_applies_immediately() -> None:
    store = FakeMemoryService()
    result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="create_goal",
            payload={"title": "Buy dumbbells"},
            explicit=True,
            auto=False,
        ),
        user_text="Please save a goal to buy dumbbells",
        assistant_reply="Saving that goal.",
    )
    assert result is not None
    assert result["memory_changes"]["created"] == 1
    assert len(store.plans) == 1
    assert "goals" in result["response"].lower()


@pytest.mark.asyncio
async def test_off_soft_create_goal_is_dropped() -> None:
    store = FakeMemoryService()
    result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="create_goal",
            payload={"title": "Buy dumbbells"},
            explicit=False,
            auto=True,
        ),
        user_text="I want to buy dumbbells someday",
    )
    assert result is None
    assert store.plans == []


@pytest.mark.asyncio
async def test_update_goal_card_then_confirm() -> None:
    store = FakeMemoryService()
    plan = await store.create_plan(
        {
            "title": "Buy 16GB RAM",
            "description": "Old target",
            "desired_outcome": "Old target",
            "plan_type": "personal",
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="update_goal",
            payload={
                "plan_id": plan["id"],
                "title": "Buy 32GB RAM",
                "description": "Need more memory for Clarity",
            },
        ),
        user_text="Update my RAM goal to 32GB",
        assistant_reply="32GB is a safer target for this build.",
    )
    assert result is not None
    proposal = result["memory_changes"]["write_proposals"][0]
    assert proposal["write_kind"] == "update_plan"
    assert plan["title"] == "Buy 16GB RAM"

    durable = DurableWriteService(memory_service=store)
    confirmed = await durable.try_handle_pending(
        "yes",
        pending_action=await store.get_conversation_pending_action("c1"),
        conversation_id="c1",
        user_message={"id": "u2", "content": "yes"},
        write_confirmation={"proposal_id": proposal["id"]},
    )
    assert confirmed is not None
    assert confirmed["memory_changes"]["updated"] == 1
    assert plan["title"] == "Buy 32GB RAM"
    assert "Clarity" in str(plan.get("description") or "")


@pytest.mark.asyncio
async def test_delete_goal_card_then_confirm() -> None:
    store = FakeMemoryService()
    plan = await store.create_plan(
        {
            "title": "Buy dumbbells",
            "description": "Home gym",
            "plan_type": "health",
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="delete_goal",
            payload={"plan_id": plan["id"], "title": "Buy dumbbells"},
        ),
        user_text="Delete the buy dumbbells goal",
        assistant_reply="I can remove that goal if you're done with it.",
    )
    assert result is not None
    proposal = result["memory_changes"]["write_proposals"][0]
    assert proposal["write_kind"] == "delete"
    assert len(store.plans) == 1

    durable = DurableWriteService(memory_service=store)
    confirmed = await durable.try_handle_pending(
        "yes",
        pending_action=await store.get_conversation_pending_action("c1"),
        conversation_id="c1",
        user_message={"id": "u2", "content": "yes"},
        write_confirmation={"proposal_id": proposal["id"]},
    )
    assert confirmed is not None
    assert confirmed["memory_changes"]["archived"] == 1
    assert store.plans == []


@pytest.mark.asyncio
async def test_off_explicit_delete_goal_applies() -> None:
    store = FakeMemoryService()
    plan = await store.create_plan(
        {
            "title": "Old visa paperwork",
            "description": "Done",
            "plan_type": "immigration",
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="delete_goal",
            payload={"reference": "Old visa paperwork"},
            explicit=True,
            auto=False,
        ),
        user_text="Please delete my old visa paperwork goal",
        assistant_reply="Removing that goal.",
    )
    assert result is not None
    assert result["memory_changes"]["archived"] == 1
    assert store.plans == []
    assert plan["id"] not in {row.get("id") for row in store.plans}
    assert "deleted" in result["response"].lower()
    assert "updated in goals" not in result["response"].lower()


def test_parse_create_goal_action_aliases() -> None:
    parsed = parse_brain_actions(
        'Sure.\n```rex_action\n'
        '{"action":"create_goal","title":"Buy RAM","description":"32GB"}\n'
        "```"
    )
    assert len(parsed.actions) == 1
    assert parsed.actions[0].name == "create_goal"
    # Top-level description aliases into payload.summary for shared parse path.
    assert parsed.actions[0].payload.get("title") == "Buy RAM"
    assert parsed.actions[0].payload.get("summary") == "32GB"


def test_tiny_system_phase_e_mentions_goal_dispatch() -> None:
    prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="card", goals=True))
    assert "create_goal" in prompt
    assert "update_goal" in prompt
    assert "delete_goal" in prompt
