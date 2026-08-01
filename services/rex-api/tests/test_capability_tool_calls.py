"""Actions arrive as tool calls, and a cut-off turn says so.

Grok used to append a ```rex_action``` fence after its prose. Long replies hit
the token cap before reaching the fence, so the user read "adding this goal"
and no goal ever appeared. A tool call is a separate field on the response —
it cannot be truncated off the end and it cannot be malformed JSON.
"""

from __future__ import annotations

import json

import pytest

from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_CARD,
    AUTO_PROPOSALS_OFF,
    AssistantProposalSettings,
)
from app.services.brain_action_schema import actions_from_tool_calls
from app.services.capability_tools import TOOL_NAME, capability_tools
from app.services.capability_catalog import CAPABILITY_NAMES
from app.services.grok_usage import GrokChatResult
from tests.turn_fetch_fakes import finalize_turn, rex_action, tool_call

CARD = AssistantProposalSettings(mode=AUTO_PROPOSALS_CARD)
OFF = AssistantProposalSettings(mode=AUTO_PROPOSALS_OFF)


def _proposals(turn: dict) -> list[dict]:
    proposed = turn.get("proposed_turn") or turn
    changes = proposed.get("memory_changes") or {}
    return changes.get("write_proposals") or []


def _reply(turn: dict) -> str:
    proposed = turn.get("proposed_turn") or turn
    return proposed.get("response") or ""


def test_the_tool_offers_every_capability_and_nothing_else():
    schema = capability_tools()[0]["function"]

    assert schema["name"] == TOOL_NAME
    assert schema["parameters"]["properties"]["action"]["enum"] == list(CAPABILITY_NAMES)
    assert schema["parameters"]["required"] == ["action"]


def test_a_tool_call_becomes_the_same_action_a_fence_would_have():
    from_tool = actions_from_tool_calls(
        [tool_call("create_goal", {"title": "Buy a motorcycle"}, explicit=True)]
    )

    assert len(from_tool) == 1
    assert from_tool[0].name == "create_goal"
    assert from_tool[0].payload["title"] == "Buy a motorcycle"
    assert from_tool[0].explicit is True


def test_arguments_that_are_not_valid_json_are_skipped_not_crashed():
    assert actions_from_tool_calls([tool_call("create_goal", arguments="{oops")]) == []


def test_calls_to_other_tools_are_ignored():
    other = {"type": "function", "function": {"name": "something_else", "arguments": "{}"}}

    assert actions_from_tool_calls([other]) == []


@pytest.mark.asyncio
async def test_a_goal_asked_for_by_tool_call_reaches_the_confirm_card():
    turn = await finalize_turn(
        "Adding this goal now.",
        settings=CARD,
        sources=(),
        user_text="Save a goal to buy a motorcycle",
        tool_calls=(tool_call("create_goal", {"title": "Buy a motorcycle"}, explicit=True),),
    )

    proposals = _proposals(turn)
    assert [proposal["title"] for proposal in proposals] == ["Buy a motorcycle"]


@pytest.mark.asyncio
async def test_a_fence_still_works_for_models_that_reach_for_one():
    turn = await finalize_turn(
        "Adding this goal now."
        + rex_action("create_goal", {"title": "Buy a motorcycle"}, explicit=True),
        settings=CARD,
        sources=(),
        user_text="Save a goal to buy a motorcycle",
    )

    assert [proposal["title"] for proposal in _proposals(turn)] == ["Buy a motorcycle"]


@pytest.mark.asyncio
async def test_a_promise_cut_off_before_the_action_admits_nothing_happened():
    turn = await finalize_turn(
        "Adding this goal for you and setting the date to",
        settings=CARD,
        sources=(),
        user_text="Save a goal to buy a motorcycle",
        was_cut_off=True,
    )

    reply = _reply(turn)
    assert _proposals(turn) == []
    assert "nothing has happened yet" in reply
    # Grok's own words still ship; the note is added, not swapped in.
    assert reply.startswith("Adding this goal for you")


@pytest.mark.asyncio
async def test_a_cut_off_reply_that_still_acted_says_only_that_it_is_short():
    turn = await finalize_turn(
        "Adding this goal and here is the long reasoning that ran",
        settings=CARD,
        sources=(),
        user_text="Save a goal to buy a motorcycle",
        tool_calls=(tool_call("create_goal", {"title": "Buy a motorcycle"}, explicit=True),),
        was_cut_off=True,
    )

    reply = _reply(turn)
    assert "cut short" in reply
    assert "nothing has happened yet" not in reply
    assert [proposal["title"] for proposal in _proposals(turn)] == ["Buy a motorcycle"]


@pytest.mark.asyncio
async def test_a_finished_turn_never_apologises_for_length():
    turn = await finalize_turn(
        "Here is what I think.",
        settings=CARD,
        sources=(),
        user_text="What do you think?",
    )

    assert "cut short" not in _reply(turn)


@pytest.mark.asyncio
async def test_auto_suggestions_off_still_gates_a_tool_call_the_user_did_not_ask_for():
    turn = await finalize_turn(
        "Want me to track that?",
        settings=OFF,
        sources=(),
        user_text="I had a rough day",
        tool_calls=(tool_call("create_goal", {"title": "Rest more"}, auto=True),),
    )

    assert _proposals(turn) == []


def test_the_client_reports_tool_calls_and_why_the_model_stopped():
    from app.services.ai_service import AIService

    payload = {
        "choices": [
            {
                "finish_reason": "length",
                "message": {
                    "content": "Adding this goal",
                    "tool_calls": [
                        {
                            "type": "function",
                            "function": {
                                "name": TOOL_NAME,
                                "arguments": json.dumps({"action": "create_goal"}),
                            },
                        }
                    ],
                },
            }
        ]
    }

    text, tool_calls, finish_reason = AIService()._parse_grok_choice(payload)

    assert text == "Adding this goal"
    assert len(tool_calls) == 1
    assert finish_reason == "length"
    assert GrokChatResult(text=text, finish_reason=finish_reason).was_cut_off is True


def test_a_normal_finish_is_not_treated_as_cut_off():
    assert GrokChatResult(text="Done.", finish_reason="stop").was_cut_off is False
