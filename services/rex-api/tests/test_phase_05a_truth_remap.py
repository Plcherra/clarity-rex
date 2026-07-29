"""05a Phase 1: Truth remapping + surface-correct Knows/Goals copy via finalize."""

from __future__ import annotations

import pytest

from app.services.action_truth_memory import UNEXECUTED_MEMORY_FALLBACK
from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_finalize import finalize_grok_turn
from app.services.clarity_action_parser import ClarityActionParser
from app.services.durable_write_service import DurableWriteService
from app.services.grok_continuing_reply import (
    continuing_reply_for_goal_apply,
    continuing_reply_for_knows_apply,
    continuing_reply_for_propose,
)
from chat_service_fakes import FakeMemoryService


@pytest.mark.asyncio
async def test_finalize_knows_card_propose_scrubs_saved_claim_not_goals() -> None:
    store = FakeMemoryService()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "I've saved that preference in Knows.\n\n"
        "```rex_action\n"
        '{"action":"save_memory","payload":{'
        '"content":"I prefer dark mode","memory_type":"preference"}}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(
            mode="card", memory=True, goals=True, threads=True
        ),
        brain_message="Remember I prefer dark mode",
        user_message={"id": "u1", "content": "Remember I prefer dark mode"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    proposed = finalized.get("proposed_turn")
    assert proposed is not None
    lowered = proposed["response"].lower()
    assert "i've saved" not in lowered
    assert "i have saved" not in lowered
    assert "knows" in lowered
    assert "goals" not in lowered
    assert proposed["memory_changes"]["confirmation_required"] == 1
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_finalize_knows_text_propose_scrubs_saved_claim_not_goals() -> None:
    store = FakeMemoryService()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "Saved in Knows: I hate cilantro.\n\n"
        "```rex_action\n"
        '{"action":"save_memory","payload":{"content":"I hate cilantro"}}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(
            mode="text", memory=True, goals=True, threads=True
        ),
        brain_message="Remember I hate cilantro",
        user_message={"id": "u1", "content": "Remember I hate cilantro"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    proposed = finalized.get("proposed_turn")
    assert proposed is not None
    lowered = proposed["response"].lower()
    assert "saved in knows: i hate cilantro" not in lowered
    assert "knows" in lowered
    assert "goals" not in lowered
    assert "say yes" in lowered
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_finalize_knows_claim_with_confirm_language_still_scrubbed() -> None:
    store = FakeMemoryService()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "I've saved that in Knows. Want me to confirm?\n\n"
        "```rex_action\n"
        '{"action":"save_memory","payload":{'
        '"content":"I prefer dark mode","memory_type":"preference"}}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(
            mode="card", memory=True, goals=True, threads=True
        ),
        brain_message="Remember I prefer dark mode",
        user_message={"id": "u1", "content": "Remember I prefer dark mode"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    proposed = finalized.get("proposed_turn")
    assert proposed is not None
    lowered = proposed["response"].lower()
    assert "i've saved" not in lowered
    assert "i have saved" not in lowered
    assert "knows" in lowered
    assert "goals" not in lowered


@pytest.mark.asyncio
async def test_finalize_off_explicit_knows_apply_no_denial_preamble() -> None:
    store = FakeMemoryService()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "I've saved that preference in Knows.\n\n"
        "```rex_action\n"
        '{"action":"save_memory","payload":{'
        '"content":"I prefer dark mode","memory_type":"preference"},'
        '"explicit":true}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(
            mode="off", memory=True, goals=True, threads=True
        ),
        brain_message="Please save that I prefer dark mode",
        user_message={"id": "u1", "content": "Please save that I prefer dark mode"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    proposed = finalized.get("proposed_turn")
    assert proposed is not None
    assert proposed["memory_changes"]["created"] == 1
    lowered = proposed["response"].lower()
    assert "don't have a confirmed" not in lowered
    assert "knows" in lowered
    assert len(store.long_term_memory) == 1


@pytest.mark.asyncio
async def test_finalize_off_explicit_goal_apply_no_denial_preamble() -> None:
    store = FakeMemoryService()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "I've saved that commitment.\n\n"
        "```rex_action\n"
        '{"action":"create_goal","payload":{"title":"Buy dumbbells"},'
        '"explicit":true}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(
            mode="off", memory=True, goals=True, threads=True
        ),
        brain_message="Please save a goal to buy dumbbells",
        user_message={"id": "u1", "content": "Please save a goal to buy dumbbells"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    proposed = finalized.get("proposed_turn")
    assert proposed is not None
    assert proposed["memory_changes"]["created"] == 1
    lowered = proposed["response"].lower()
    assert "don't have a confirmed" not in lowered
    assert "i'll save it directly" not in lowered
    assert "goals" in lowered
    assert len(store.plans) == 1


@pytest.mark.asyncio
async def test_finalize_goals_off_soft_create_no_direct_save_promise() -> None:
    store = FakeMemoryService()
    durable = DurableWriteService(memory_service=store)
    rex = (
        "I've saved that commitment.\n\n"
        "```rex_action\n"
        '{"action":"create_goal","payload":{"title":"Buy dumbbells"}}\n'
        "```"
    )
    finalized = await finalize_grok_turn(
        rex,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=durable,
        proposal_settings=AssistantProposalSettings(
            mode="card", memory=True, goals=False, threads=True
        ),
        brain_message="I want to buy dumbbells someday",
        user_message={"id": "u1", "content": "I want to buy dumbbells someday"},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[],
    )
    assert finalized.get("proposed_turn") is None
    assert store.plans == []
    lowered = finalized["response"].lower()
    assert "i'll save it directly" not in lowered
    assert "saved that commitment" not in lowered
    assert "keep talking" in lowered or "happy to keep talking" in lowered


def test_propose_knows_surface_never_says_goals() -> None:
    reply = continuing_reply_for_propose(
        UNEXECUTED_MEMORY_FALLBACK,
        surface_client_cards=True,
        surface="knows",
    )
    assert "knows" in reply.lower()
    assert "goals" not in reply.lower()
    assert "don't have a confirmed" not in reply.lower()


def test_knows_apply_replaces_denial_preamble() -> None:
    reply = continuing_reply_for_knows_apply(
        UNEXECUTED_MEMORY_FALLBACK,
        title="Dark mode preference",
    )
    assert "don't have a confirmed" not in reply.lower()
    assert "knows" in reply.lower()
    assert "dark mode" in reply.lower()


def test_goal_apply_replaces_denial_preamble() -> None:
    from app.services.action_truth_policy import UNEXECUTED_GOAL_FALLBACK

    reply = continuing_reply_for_goal_apply(
        UNEXECUTED_GOAL_FALLBACK,
        title="Buy dumbbells",
        write_kind="plan",
    )
    assert "don't have a confirmed" not in reply.lower()
    assert "i'll save it directly" not in reply.lower()
    assert "goals" in reply.lower()
    assert "dumbbells" in reply.lower()
