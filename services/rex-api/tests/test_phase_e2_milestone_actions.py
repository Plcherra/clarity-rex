"""Phase E2: milestone create/update/delete via gated Grok actions."""

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
    defaults = {"memory": True, "threads": True, "goals": True}
    defaults.update(kwargs)
    return AssistantProposalSettings(**defaults)


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


async def _seed_goal(store: FakeMemoryService, title: str = "Buy 32GB RAM") -> dict:
    return await store.create_plan(
        {
            "title": title,
            "description": "Laptop upgrade",
            "desired_outcome": "Laptop upgrade",
            "plan_type": "personal",
        }
    )


@pytest.mark.asyncio
async def test_card_soft_create_milestone_emits_write_proposal() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="create_milestone",
            payload={
                "plan_id": plan["id"],
                "title": "Order RAM stick",
                "description": "Buy from trusted seller",
            },
        ),
        user_text="Add a step to order the RAM under my RAM goal",
        assistant_reply="Ordering the stick is a clear next step.",
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes["created"] == 0
    assert changes["write_proposals"]
    assert changes["write_proposals"][0]["write_kind"] == "milestone"
    assert store.plan_milestones == []
    assert "next step" in result["response"].lower()
    assert "tap confirm" not in result["response"].lower()
    assert "saved" not in result["response"].lower() or "until" in result["response"].lower()


@pytest.mark.asyncio
async def test_card_create_milestone_confirm_applies() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    durable = DurableWriteService(memory_service=store)
    settings = _settings(mode="card")
    action = BrainAction(
        name="create_milestone",
        payload={"plan_id": plan["id"], "title": "Order RAM stick"},
    )
    gate = apply_auto_suggestions_gate([action], settings, user_message="add step")
    proposed = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={"id": "u1", "content": "Add a step to order RAM"},
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
    assert len(store.plan_milestones) == 1
    assert store.plan_milestones[0]["plan_id"] == plan["id"]
    assert "order" in store.plan_milestones[0]["title"].lower()


@pytest.mark.asyncio
async def test_text_soft_create_milestone_proposes_without_cards() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    result = await _dispatch(
        store=store,
        settings=_settings(mode="text"),
        action=BrainAction(
            name="create_milestone",
            payload={"goal_title": plan["title"], "title": "Compare prices"},
        ),
        user_text="Add a step to compare RAM prices",
        assistant_reply="Comparing prices first makes sense.",
    )
    assert result is not None
    changes = result["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes.get("write_proposals") in (None, [])
    assert changes.get("text_confirmation_pending") is True
    assert "say yes" in result["response"].lower()
    assert store.plan_milestones == []


@pytest.mark.asyncio
async def test_off_explicit_create_milestone_applies_immediately() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="create_milestone",
            payload={"plan_id": plan["id"], "title": "Install RAM"},
            explicit=True,
            auto=False,
        ),
        user_text="Please add a milestone to install the RAM under Buy 32GB RAM",
        assistant_reply="Saving that step.",
    )
    assert result is not None
    assert result["memory_changes"]["created"] == 1
    assert len(store.plan_milestones) == 1
    assert "goals" in result["response"].lower()


@pytest.mark.asyncio
async def test_off_soft_create_milestone_is_dropped() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="create_milestone",
            payload={"plan_id": plan["id"], "title": "Install RAM"},
            explicit=False,
            auto=True,
        ),
        user_text="I might install the RAM someday",
    )
    assert result is None
    assert store.plan_milestones == []


@pytest.mark.asyncio
async def test_goals_false_drops_create_milestone() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card", goals=False),
        action=BrainAction(
            name="create_milestone",
            payload={"plan_id": plan["id"], "title": "Order RAM"},
        ),
        user_text="Add a step to order RAM",
    )
    assert result is None
    assert store.plan_milestones == []


@pytest.mark.asyncio
async def test_create_milestone_bare_reference_still_auto_picks_sole_goal() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="create_milestone",
            payload={"title": "Order RAM", "reference": "Order RAM"},
        ),
        user_text="Add a step to order RAM",
        assistant_reply="Ordering first makes sense.",
    )
    assert result is not None
    proposals = result["memory_changes"].get("write_proposals") or []
    assert len(proposals) == 1
    assert proposals[0]["write_kind"] == "milestone"
    assert proposals[0]["title"] == "Order RAM"
    assert proposals[0]["target_label"] == plan["title"]
    assert store.plan_milestones == []


@pytest.mark.asyncio
async def test_create_milestone_without_parent_lists_goals() -> None:
    store = FakeMemoryService()
    await _seed_goal(store, "Buy 32GB RAM")
    await _seed_goal(store, "Launch Clarity")
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="create_milestone",
            payload={"title": "Order parts"},
        ),
        user_text="Add a step to order parts",
        assistant_reply="Happy to track that step.",
    )
    assert result is not None
    assert result["memory_changes"].get("write_proposals") in (None, [])
    assert store.plan_milestones == []
    lowered = result["response"].lower()
    assert "which goal" in lowered or "active goals" in lowered
    assert "buy 32gb ram" in lowered or "launch clarity" in lowered


@pytest.mark.asyncio
async def test_update_milestone_merges_existing_metadata() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    milestone = await store.create_plan_milestone(
        {
            "plan_id": plan["id"],
            "title": "Order 16GB",
            "description": "Old step",
            "metadata": {
                "source": "prior",
                "discipline_write_channel": "confirmed_plan_service",
                "keep_me": "yes",
            },
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="update_milestone",
            payload={
                "milestone_id": milestone["id"],
                "title": "Order 32GB",
            },
            explicit=True,
            auto=False,
        ),
        user_text="Please rename the order step to 32GB",
        assistant_reply="Renaming that step.",
    )
    assert result is not None
    assert result["memory_changes"]["updated"] == 1
    assert milestone["title"] == "Order 32GB"
    meta = milestone.get("metadata") or {}
    assert meta.get("keep_me") == "yes"
    assert meta.get("discipline_write_channel") == "confirmed_plan_service"
    assert meta.get("source") == "durable_write_confirmed"


@pytest.mark.asyncio
async def test_update_milestone_card_then_confirm() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    milestone = await store.create_plan_milestone(
        {
            "plan_id": plan["id"],
            "title": "Order 16GB",
            "description": "Old step",
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="update_milestone",
            payload={
                "milestone_id": milestone["id"],
                "title": "Order 32GB",
                "description": "Need the full stick",
            },
        ),
        user_text="Update the order step to 32GB",
        assistant_reply="32GB matches the goal.",
    )
    assert result is not None
    proposal = result["memory_changes"]["write_proposals"][0]
    assert proposal["write_kind"] == "update_milestone"
    assert "Order 32GB" in proposal["confirmation_text"]
    assert milestone["title"] == "Order 16GB"

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
    assert milestone["title"] == "Order 32GB"
    assert "updated" in confirmed["response"].lower()
    assert "saved order 32gb" not in confirmed["response"].lower()


@pytest.mark.asyncio
async def test_update_milestone_rename_confirm_shows_new_title() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    milestone = await store.create_plan_milestone(
        {
            "plan_id": plan["id"],
            "title": "Order 16GB",
            "description": "Old step",
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="update_milestone",
            payload={
                "milestone_id": milestone["id"],
                "title": "Order 32GB",
            },
        ),
        user_text="Rename the order step to 32GB",
        assistant_reply="32GB matches the goal.",
    )
    assert result is not None
    proposal = result["memory_changes"]["write_proposals"][0]
    confirm = proposal["confirmation_text"]
    assert "Order 32GB" in confirm
    # Old description may still appear as body detail, but new title must lead.
    assert confirm.index("Order 32GB") < confirm.lower().index("old step")


@pytest.mark.asyncio
async def test_update_milestone_new_title_only_clarifies() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    milestone = await store.create_plan_milestone(
        {
            "plan_id": plan["id"],
            "title": "Order 16GB",
            "description": "Old step",
        }
    )
    other = await store.create_plan_milestone(
        {
            "plan_id": plan["id"],
            "title": "Order 32GB",
            "description": "Already exists",
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="update_milestone",
            payload={"new_title": "Order 32GB"},
        ),
        user_text="Rename my order step to 32GB",
        assistant_reply="32GB is better.",
    )
    assert result is not None
    assert result["memory_changes"].get("write_proposals") in (None, [])
    assert milestone["title"] == "Order 16GB"
    assert other["title"] == "Order 32GB"
    assert "need" in result["response"].lower() or "which" in result["response"].lower()


@pytest.mark.asyncio
async def test_update_milestone_by_reference_under_plan() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    milestone = await store.create_plan_milestone(
        {
            "plan_id": plan["id"],
            "title": "Compare prices",
            "description": "Shop around",
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="update_milestone",
            payload={
                "plan_id": plan["id"],
                "existing_title": "Compare prices",
                "new_title": "Compare Amazon and Best Buy",
            },
        ),
        user_text="Rename compare prices under my RAM goal",
        assistant_reply="More specific helps.",
    )
    assert result is not None
    proposal = result["memory_changes"]["write_proposals"][0]
    assert proposal["write_kind"] == "update_milestone"
    durable = DurableWriteService(memory_service=store)
    confirmed = await durable.try_handle_pending(
        "yes",
        pending_action=await store.get_conversation_pending_action("c1"),
        conversation_id="c1",
        user_message={"id": "u2", "content": "yes"},
        write_confirmation={"proposal_id": proposal["id"]},
    )
    assert confirmed is not None
    assert milestone["title"] == "Compare Amazon and Best Buy"


@pytest.mark.asyncio
async def test_delete_milestone_card_then_confirm() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    milestone = await store.create_plan_milestone(
        {
            "plan_id": plan["id"],
            "title": "Old research step",
            "description": "Done",
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="delete_milestone",
            payload={"milestone_id": milestone["id"], "title": "Old research step"},
        ),
        user_text="Delete the old research step",
        assistant_reply="I can remove that step if you're done.",
    )
    assert result is not None
    proposal = result["memory_changes"]["write_proposals"][0]
    assert proposal["write_kind"] == "delete"
    assert len(store.plan_milestones) == 1

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
    assert store.plan_milestones == []


@pytest.mark.asyncio
async def test_off_explicit_delete_milestone_applies() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    await store.create_plan_milestone(
        {
            "plan_id": plan["id"],
            "title": "Done research",
            "description": "Done",
        }
    )
    result = await _dispatch(
        store=store,
        settings=_settings(mode="off"),
        action=BrainAction(
            name="delete_milestone",
            payload={
                "plan_id": plan["id"],
                "reference": "Done research",
            },
            explicit=True,
            auto=False,
        ),
        user_text="Please delete the done research milestone under Buy 32GB RAM",
        assistant_reply="Removing that step.",
    )
    assert result is not None
    assert result["memory_changes"]["archived"] == 1
    assert store.plan_milestones == []
    assert "deleted" in result["response"].lower()


@pytest.mark.asyncio
async def test_truth_scrub_on_milestone_propose() -> None:
    store = FakeMemoryService()
    plan = await _seed_goal(store)
    result = await _dispatch(
        store=store,
        settings=_settings(mode="card"),
        action=BrainAction(
            name="create_milestone",
            payload={"plan_id": plan["id"], "title": "Order RAM"},
        ),
        user_text="Add a step to order RAM",
        assistant_reply="Done — I saved that milestone in Goals.",
    )
    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert store.plan_milestones == []
    lowered = result["response"].lower()
    assert "saved" not in lowered or "until" in lowered or "confirm" in lowered
    assert "done — i saved" not in lowered


def test_parse_create_milestone_action_aliases() -> None:
    parsed = parse_brain_actions(
        "Sure.\n```rex_action\n"
        '{"action":"create_milestone","planId":"p1","title":"Order RAM",'
        '"description":"Buy stick"}\n'
        "```"
    )
    assert len(parsed.actions) == 1
    assert parsed.actions[0].name == "create_milestone"
    assert parsed.actions[0].payload.get("plan_id") == "p1"
    assert parsed.actions[0].payload.get("title") == "Order RAM"
    assert parsed.actions[0].payload.get("summary") == "Buy stick"


def test_tiny_system_phase_e2_mentions_milestone_dispatch() -> None:
    prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="card", goals=True))
    assert "create_milestone" in prompt
    assert "update_milestone" in prompt
    assert "delete_milestone" in prompt
    assert "open thread" in prompt.lower() or "habit" in prompt.lower()
