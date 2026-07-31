"""Phase F: fetch_spend_insight / fetch_account_summary grounded answers."""

from __future__ import annotations

import pytest

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.chat_financial_guard import FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
from finance_turn_fakes import (
    FakeGrokBrain,
    clarity_proposals,
    finalize_finance_turn,
    financial_context,
    rex_action,
)

CARD = AssistantProposalSettings(mode="card")


@pytest.mark.asyncio
async def test_fetch_spend_insight_answers_from_fetched_numbers() -> None:
    brain = FakeGrokBrain("You've spent about $42 on coffee this month.")
    finalized = await finalize_finance_turn(
        "Let me check.\n" + rex_action("fetch_spend_insight", {"category": "Coffee"}),
        settings=CARD,
        context=financial_context(),
        brain=brain,
    )
    assert finalized["response"] == "You've spent about $42 on coffee this month."
    assert len(brain.calls) == 1
    pack = brain.last_fetch_pack
    assert "fetch_spend_insight" in pack
    assert "Category Coffee: spent=42.5" in pack
    assert "only source for numbers" in pack
    assert "estimating" in pack
    assert clarity_proposals(finalized) == []


@pytest.mark.asyncio
async def test_fetch_spend_insight_by_merchant_lists_matching_rows() -> None:
    brain = FakeGrokBrain("Two Starbucks runs, $11.75 total.")
    await finalize_finance_turn(
        rex_action("fetch_spend_insight", {"merchant": "Starbucks"}),
        settings=CARD,
        context=financial_context(),
        user_text="How much at Starbucks?",
        brain=brain,
    )
    pack = brain.last_fetch_pack
    assert 'Matching transactions for "Starbucks": count=2' in pack
    assert "total=11.75" in pack
    assert "Whole Foods" not in pack


@pytest.mark.asyncio
async def test_fetch_spend_insight_says_when_a_category_has_no_spend() -> None:
    brain = FakeGrokBrain("Nothing recorded under travel this month.")
    await finalize_finance_turn(
        rex_action("fetch_spend_insight", {"category": "Travel"}),
        settings=CARD,
        context=financial_context(),
        user_text="How much on travel?",
        brain=brain,
    )
    pack = brain.last_fetch_pack
    assert 'No category named "Travel" has spend this month' in pack
    assert "Categories with spend this month: Coffee; Groceries" in pack


@pytest.mark.asyncio
async def test_fetch_without_reliable_context_is_honest_and_skips_grok() -> None:
    brain = FakeGrokBrain("You spent $42 on coffee.")
    finalized = await finalize_finance_turn(
        "Sure.\n" + rex_action("fetch_spend_insight", {"category": "Coffee"}),
        settings=CARD,
        context=None,
        brain=brain,
    )
    assert finalized["response"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
    assert brain.calls == []
    assert "$42" not in finalized["response"]


@pytest.mark.asyncio
async def test_fetch_with_degraded_context_is_honest() -> None:
    brain = FakeGrokBrain("You spent $42 on coffee.")
    degraded = financial_context(
        data_status={
            "state": "degraded",
            "financial_context_complete": False,
            "load_errors": [{"source": "supabase", "message": "timeout"}],
        }
    )
    finalized = await finalize_finance_turn(
        rex_action("fetch_spend_insight", {"category": "Coffee"}),
        settings=CARD,
        context=degraded,
        brain=brain,
    )
    assert finalized["response"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
    assert brain.calls == []


def _size_capped_context(**overrides) -> dict:
    return financial_context(
        integration={
            "full_financial_context_included": False,
            "raw_transactions_included": False,
            "size_capped": True,
            "size_cap_reason": "shrunk_transaction_lists",
        },
        period={
            "reference_month": "2026-07",
            "transaction_count": 312,
            "included_transaction_count": 40,
        },
        **overrides,
    )


@pytest.mark.asyncio
async def test_size_capped_pack_still_answers_and_declares_what_is_missing() -> None:
    brain = FakeGrokBrain("Coffee is at $42.50 so far this month.")
    finalized = await finalize_finance_turn(
        rex_action("fetch_spend_insight", {"category": "Coffee"}),
        settings=CARD,
        context=_size_capped_context(),
        brain=brain,
    )
    assert finalized["response"] == "Coffee is at $42.50 so far this month."
    pack = brain.last_fetch_pack
    assert "Category Coffee: spent=42.5" in pack
    assert "Transaction detail coverage: 40 of 312 transactions this period" in pack
    assert "shrunk_transaction_lists" in pack


@pytest.mark.asyncio
async def test_trimmed_pack_never_reports_a_merchant_as_zero_spend() -> None:
    brain = FakeGrokBrain("I only see part of the detail.")
    await finalize_finance_turn(
        rex_action("fetch_spend_insight", {"merchant": "Blue Bottle"}),
        settings=CARD,
        context=_size_capped_context(),
        user_text="How much at Blue Bottle?",
        brain=brain,
    )
    pack = brain.last_fetch_pack
    assert "detail is partial" in pack
    assert "rather than that nothing was spent" in pack
    assert 'No transactions in this context match "Blue Bottle".' not in pack


@pytest.mark.asyncio
async def test_fetch_account_summary_focuses_named_account() -> None:
    brain = FakeGrokBrain("Everyday Checking is at $2,210.55.")
    finalized = await finalize_finance_turn(
        rex_action("fetch_account_summary", {"account": "Everyday Checking"}),
        settings=CARD,
        context=financial_context(),
        user_text="Give me a summary of my checking account",
        brain=brain,
    )
    pack = brain.last_fetch_pack
    assert "Everyday Checking" in pack
    assert "current_balance=2210.55" in pack
    assert "Travel Card" not in pack
    assert "Recent transactions on this account:" in pack
    assert finalized["response"] == "Everyday Checking is at $2,210.55."


@pytest.mark.asyncio
async def test_fetch_account_summary_by_id_lists_all_when_no_match() -> None:
    brain = FakeGrokBrain("Here is what Clarity has.")
    await finalize_finance_turn(
        rex_action("fetch_account_summary", {"account_id": "acct-missing"}),
        settings=CARD,
        context=financial_context(),
        user_text="Summary of my savings account",
        brain=brain,
    )
    pack = brain.last_fetch_pack
    assert "No account in Clarity matches" in pack
    assert "Everyday Checking" in pack
    assert "Travel Card" in pack


@pytest.mark.asyncio
async def test_no_fetch_action_keeps_the_first_reply_and_skips_second_call() -> None:
    brain = FakeGrokBrain("Second pass should not run.")
    finalized = await finalize_finance_turn(
        "Budgets are a good habit to build.",
        settings=CARD,
        context=financial_context(),
        user_text="Any thoughts on budgeting?",
        brain=brain,
    )
    assert finalized["response"] == "Budgets are a good habit to build."
    assert brain.calls == []


@pytest.mark.asyncio
async def test_fetch_pack_stays_within_the_turn_char_budget() -> None:
    brain = FakeGrokBrain("Grounded.")
    noisy = financial_context(
        transactions=[
            {
                "id": f"tx-{index}",
                "date": "2026-07-15",
                "account_id": "acct-1",
                "merchant": "Starbucks",
                "amount": 5.25,
                "category_name": "Uncategorized",
                "description": "Coffee run number " + str(index),
            }
            for index in range(200)
        ]
    )
    await finalize_finance_turn(
        rex_action("fetch_spend_insight", {"merchant": "Starbucks"}),
        settings=CARD,
        context=noisy,
        user_text="How much at Starbucks?",
        brain=brain,
    )
    pack = brain.last_fetch_pack
    assert "count=200" in pack
    assert "more rows not listed" in pack
    assert len(pack) < 4000
