"""Phase G: Grok asks to read old chats or Knows, and the body actually reads."""

from __future__ import annotations

import pytest

from app.services.action_truth_policy import (
    DEGRADED_RECALL_FALLBACK,
    EMPTY_RECALL_FALLBACK,
)
from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_CARD,
    AUTO_PROPOSALS_OFF,
    AssistantProposalSettings,
)
from app.services.capabilities.recall_action_payload import recall_fetch_requests
from app.services.capabilities.recall_capability import (
    INVENTORY_UNAVAILABLE_REPLY,
    SEARCH_UNAVAILABLE_REPLY,
)
from app.services.brain_action_schema import parse_brain_actions
from app.services.capability_catalog import CAPABILITY_NAMES
from recall_turn_fakes import (
    FakeGrokBrain,
    FakeOverviewService,
    FakeRecallService,
    finalize_recall_turn,
    rex_action,
)

CARD = AssistantProposalSettings(mode=AUTO_PROPOSALS_CARD)
OFF = AssistantProposalSettings(mode=AUTO_PROPOSALS_OFF)


@pytest.mark.asyncio
async def test_search_chats_answers_from_what_the_search_returned():
    recall = FakeRecallService.with_hits(
        "user: I want a CBR600RR\nassistant: What's your budget?"
    )
    brain = FakeGrokBrain("You said you wanted a CBR600RR.")

    finalized = await finalize_recall_turn(
        "Let me look." + rex_action("search_chats", {"query": "motorcycle"}),
        settings=CARD,
        recall_service=recall,
        brain=brain,
    )

    assert finalized["response"] == "You said you wanted a CBR600RR."
    assert recall.calls[0]["query"] == "motorcycle"
    # The current thread is excluded — recall is for what is not on screen.
    assert recall.calls[0]["exclude_conversation_id"] == "c1"
    assert "CBR600RR" in brain.last_fetch_pack
    assert "Chat history, not saved memory:" in brain.last_fetch_pack


@pytest.mark.asyncio
async def test_a_search_with_no_terms_falls_back_to_what_the_user_said():
    recall = FakeRecallService.with_hits("user: payroll from Bom Dough")

    await finalize_recall_turn(
        rex_action("search_chats", {}),
        settings=CARD,
        recall_service=recall,
        user_text="what did I say about payroll?",
    )

    assert recall.calls[0]["query"] == "what did I say about payroll?"


@pytest.mark.asyncio
async def test_an_empty_search_says_so_instead_of_recalling():
    """The grounded pass is told the search found nothing, and Truth backs it."""
    recall = FakeRecallService.empty()
    brain = FakeGrokBrain("I couldn't find anything about that in our old chats.")

    finalized = await finalize_recall_turn(
        rex_action("search_chats", {"query": "sailing"}),
        settings=CARD,
        recall_service=recall,
        brain=brain,
    )

    assert "No past conversation matched" in brain.last_fetch_pack
    assert finalized["response"] == EMPTY_RECALL_FALLBACK


@pytest.mark.asyncio
async def test_a_broken_search_never_becomes_a_confident_no():
    """Search failing and finding nothing are different answers."""
    recall = FakeRecallService.broken()
    brain = FakeGrokBrain("should not be reached")

    finalized = await finalize_recall_turn(
        rex_action("search_chats", {"query": "sailing"}),
        settings=CARD,
        recall_service=recall,
        brain=brain,
    )

    assert brain.calls == []
    assert finalized["response"] == SEARCH_UNAVAILABLE_REPLY


@pytest.mark.asyncio
async def test_a_degraded_search_does_not_let_grok_claim_nothing_exists():
    recall = FakeRecallService(
        [
            {
                "_context_status": True,
                "source": "chat_search",
                "attempted": True,
                "succeeded": True,
                "result_count": 0,
                "raw_match_count": 0,
                "filtered_all_matches": False,
                "partial": True,
                "status": "empty",
            }
        ]
    )
    brain = FakeGrokBrain("I don't have anything about that.")

    finalized = await finalize_recall_turn(
        rex_action("search_chats", {"query": "sailing"}),
        settings=CARD,
        recall_service=recall,
        brain=brain,
    )

    assert finalized["response"] == DEGRADED_RECALL_FALLBACK


@pytest.mark.asyncio
async def test_list_knows_summary_reads_the_same_snapshot_as_the_knows_tab():
    overview = FakeOverviewService(
        {
            "people": [{"display_name": "Marcella", "metadata": {"relationship": "friend"}}],
            "places": [],
            "other_entities": [],
            "facts": [{"content": "Drinks oat milk"}],
            "rules": [],
            "plans": [],
            "counts": {"total": 2, "people": 1, "facts": 1},
        }
    )
    brain = FakeGrokBrain("I have Marcella saved, plus one preference.")

    finalized = await finalize_recall_turn(
        rex_action("list_knows_summary", {}),
        settings=CARD,
        overview_service=overview,
        user_text="what do you know about me?",
        brain=brain,
    )

    assert overview.calls == 1
    assert "Marcella" in brain.last_fetch_pack
    assert finalized["response"] == "I have Marcella saved, plus one preference."


@pytest.mark.asyncio
async def test_knows_read_failing_does_not_get_answered_from_thin_air():
    overview = FakeOverviewService(raises=True)
    brain = FakeGrokBrain("should not be reached")

    finalized = await finalize_recall_turn(
        rex_action("list_knows_summary", {}),
        settings=CARD,
        overview_service=overview,
        user_text="what do you know about me?",
        brain=brain,
    )

    assert brain.calls == []
    assert finalized["response"] == INVENTORY_UNAVAILABLE_REPLY


@pytest.mark.asyncio
async def test_reading_is_not_a_save_so_off_mode_still_searches():
    """Auto Suggestions gates saving, not looking."""
    recall = FakeRecallService.with_hits("user: I want a CBR600RR")
    brain = FakeGrokBrain("You mentioned wanting a CBR600RR.")

    finalized = await finalize_recall_turn(
        rex_action("search_chats", {"query": "motorcycle"}),
        settings=OFF,
        recall_service=recall,
        brain=brain,
    )

    assert recall.calls
    assert finalized["response"] == "You mentioned wanting a CBR600RR."


@pytest.mark.asyncio
async def test_no_recall_action_means_no_search_and_no_second_call():
    recall = FakeRecallService.with_hits("unused")
    brain = FakeGrokBrain("unused")

    finalized = await finalize_recall_turn(
        "Sounds like a good ride.",
        settings=CARD,
        recall_service=recall,
        brain=brain,
    )

    assert recall.calls == []
    assert brain.calls == []
    assert finalized["response"] == "Sounds like a good ride."


def test_the_same_search_named_twice_runs_once():
    actions = parse_brain_actions(
        rex_action("search_chats", {"query": "bike"})
        + rex_action("search_chats", {"query": "bike again"})
    ).actions

    assert len(recall_fetch_requests(actions)) == 1


def test_every_capability_name_is_something_the_body_can_run():
    """A name in the catalog is a promise; an unhandled one is a silent lie."""
    from app.services.capabilities.finance_action_payload import (
        FINANCE_FETCH_ACTIONS,
        FINANCE_MUTATE_ACTIONS,
    )
    from app.services.capabilities.goal_capability import is_goal_action
    from app.services.capabilities.memory_capability import is_memory_action
    from app.services.capabilities.milestone_capability import is_milestone_action
    from app.services.capabilities.open_thread_capability import is_open_thread_action
    from app.services.capabilities.recall_action_payload import RECALL_FETCH_ACTIONS
    from app.services.brain_action_schema import BrainAction

    conversational = {"just_chat", "unsupported"}
    dispatchable = FINANCE_FETCH_ACTIONS | FINANCE_MUTATE_ACTIONS | RECALL_FETCH_ACTIONS

    unhandled = [
        name
        for name in CAPABILITY_NAMES
        if name not in conversational
        and name not in dispatchable
        and not any(
            handles(BrainAction(name=name))
            for handles in (
                is_goal_action,
                is_memory_action,
                is_milestone_action,
                is_open_thread_action,
            )
        )
    ]

    assert unhandled == []
