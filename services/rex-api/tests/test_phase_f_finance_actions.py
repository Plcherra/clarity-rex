"""Phase F: finance mutates become confirmable clarity proposals (never applied here)."""

from __future__ import annotations

import pytest

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.capability_catalog import CAPABILITY_NAMES
from app.services.clarity_control_service import MUTATING_ACTIONS
from app.services.tiny_system_prompt import build_tiny_system_prompt
from finance_turn_fakes import (
    clarity_proposals,
    finalize_finance_turn,
    financial_context,
    rex_action,
)

CARD = AssistantProposalSettings(mode="card")


@pytest.mark.asyncio
async def test_categorize_transaction_resolves_names_into_a_proposal() -> None:
    finalized = await finalize_finance_turn(
        "Want me to move those?\n"
        + rex_action(
            "categorize_transaction",
            {"merchant": "Starbucks", "category": "Coffee"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Recategorize my Starbucks charges as coffee",
    )
    proposals = clarity_proposals(finalized)
    assert len(proposals) == 1
    proposal = proposals[0]
    assert proposal["action"] == "bulk_update_transaction_category"
    assert proposal["action"] in MUTATING_ACTIONS
    # Merchant scope, not the sampled ids: the user's older Starbucks rows are
    # never in the context pack and still need to move.
    assert proposal["payload"] == {
        "merchant": "Starbucks",
        "category_id": "cat-coffee",
    }
    assert proposal["status"] == "pending"
    assert "Coffee" in proposal["confirmation_text"]
    assert "every transaction matching Starbucks" in proposal["confirmation_text"]


@pytest.mark.asyncio
async def test_single_transaction_id_uses_update_transaction() -> None:
    finalized = await finalize_finance_turn(
        rex_action(
            "categorize_transaction",
            {"transaction_id": "tx-3", "category": "Coffee"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Put that one in coffee",
    )
    proposal = clarity_proposals(finalized)[0]
    assert proposal["action"] == "update_transaction"
    assert proposal["payload"] == {"id": "tx-3", "category_id": "cat-coffee"}


@pytest.mark.asyncio
async def test_bulk_categorize_keeps_bulk_action_for_one_row() -> None:
    finalized = await finalize_finance_turn(
        rex_action(
            "bulk_categorize",
            {"transaction_ids": ["tx-1"], "category_id": "cat-coffee"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Move all of those to coffee",
    )
    proposal = clarity_proposals(finalized)[0]
    assert proposal["action"] == "bulk_update_transaction_category"
    assert proposal["payload"]["ids"] == ["tx-1"]


@pytest.mark.asyncio
async def test_unresolvable_target_is_spoken_instead_of_dropped() -> None:
    finalized = await finalize_finance_turn(
        "I can look at that.\n"
        + rex_action("categorize_transaction", {"category": "Coffee"}),
        settings=CARD,
        context=financial_context(),
        user_text="Change that charge's category",
    )
    assert clarity_proposals(finalized) == []
    assert "couldn't match that" in finalized["response"]
    assert "nothing there is prepared" in finalized["response"]


@pytest.mark.asyncio
async def test_moving_rows_into_a_new_category_is_one_confirmable_change() -> None:
    """Splitting a mixed bucket must not cost the user a second turn."""
    finalized = await finalize_finance_turn(
        "Here's the split.\n"
        + rex_action(
            "bulk_categorize",
            {"merchant": "Wingstop", "category": "Fast Food"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Split coffee and fast food into separate categories",
    )
    proposal = clarity_proposals(finalized)[0]
    assert proposal["action"] == "bulk_update_transaction_category"
    assert proposal["payload"] == {
        "merchant": "Wingstop",
        "new_category": {"name": "Fast Food", "type": "expense"},
    }
    assert (
        proposal["confirmation_text"]
        == "Create the Fast Food category and move every transaction matching "
        "Wingstop into it?"
    )
    assert "Here's the split." in finalized["response"]


@pytest.mark.asyncio
async def test_one_card_when_grok_names_the_create_and_the_move() -> None:
    """Asked for both, Grok emits both — but the move already makes the category.

    Two cards read as two changes, and confirming the second looked like a
    failure once the first had already created it.
    """
    finalized = await finalize_finance_turn(
        "Here's how I'd split it.\n"
        + rex_action("create_category", {"name": "Work Reimbursements"})
        + "\n"
        + rex_action(
            "bulk_categorize",
            {"merchant": "sultanas", "category": "work reimbursements"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Create that category and move this transaction into it",
    )
    proposals = clarity_proposals(finalized)
    assert [proposal["action"] for proposal in proposals] == [
        "bulk_update_transaction_category"
    ]
    # Matched on the normalized key, so Grok's casing does not split the pair.
    assert proposals[0]["payload"]["new_category"]["name"] == "work reimbursements"


@pytest.mark.asyncio
async def test_a_create_for_a_different_category_still_gets_its_own_card() -> None:
    finalized = await finalize_finance_turn(
        rex_action("create_category", {"name": "Coffee Runs"})
        + "\n"
        + rex_action(
            "bulk_categorize",
            {"merchant": "sultanas", "category": "Work Reimbursements"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Make a coffee runs category and move sultanas to work reimbursements",
    )
    assert [proposal["action"] for proposal in clarity_proposals(finalized)] == [
        "create_category",
        "bulk_update_transaction_category",
    ]


@pytest.mark.asyncio
async def test_create_category_defaults_to_expense() -> None:
    finalized = await finalize_finance_turn(
        rex_action("create_category", {"name": "Coffee Runs"}),
        settings=CARD,
        context=financial_context(),
        user_text="Create a coffee runs category",
    )
    proposal = clarity_proposals(finalized)[0]
    assert proposal["action"] == "create_category"
    assert proposal["payload"] == {"name": "Coffee Runs", "type": "expense"}
    assert proposal["risk_level"] == "low"


@pytest.mark.asyncio
async def test_update_category_rename_targets_the_existing_record() -> None:
    finalized = await finalize_finance_turn(
        rex_action(
            "update_category",
            {"reference": "Coffee", "new_name": "Coffee & Tea"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Rename my coffee category to Coffee & Tea",
    )
    proposal = clarity_proposals(finalized)[0]
    assert proposal["action"] == "update_category"
    assert proposal["payload"] == {"id": "cat-coffee", "name": "Coffee & Tea"}


@pytest.mark.asyncio
async def test_update_category_without_changes_makes_no_proposal() -> None:
    finalized = await finalize_finance_turn(
        rex_action("update_category", {"name": "Coffee"}),
        settings=CARD,
        context=financial_context(),
        user_text="Do something with my coffee category",
    )
    assert clarity_proposals(finalized) == []


@pytest.mark.asyncio
async def test_delete_category_resolves_by_name_and_is_high_risk() -> None:
    finalized = await finalize_finance_turn(
        rex_action("delete_category", {"name": "Groceries"}),
        settings=CARD,
        context=financial_context(),
        user_text="Delete the groceries category",
    )
    proposal = clarity_proposals(finalized)[0]
    assert proposal["action"] == "delete_category"
    assert proposal["payload"] == {"id": "cat-grocery"}
    assert proposal["risk_level"] == "high"


@pytest.mark.asyncio
async def test_create_budget_uses_monthly_default_and_resolved_category() -> None:
    finalized = await finalize_finance_turn(
        rex_action("create_budget", {"category": "Coffee", "amount": "$60"}),
        settings=CARD,
        context=financial_context(),
        user_text="Set a coffee budget of 60 a month",
    )
    proposal = clarity_proposals(finalized)[0]
    assert proposal["action"] == "create_budget"
    assert proposal["payload"] == {
        "name": "Coffee",
        "amount": 60.0,
        "period": "monthly",
        "category_id": "cat-coffee",
    }


@pytest.mark.asyncio
async def test_create_budget_without_amount_makes_no_proposal() -> None:
    finalized = await finalize_finance_turn(
        rex_action("create_budget", {"category": "Coffee"}),
        settings=CARD,
        context=financial_context(),
        user_text="I should budget coffee",
    )
    assert clarity_proposals(finalized) == []


@pytest.mark.asyncio
async def test_update_budget_amount_resolves_existing_record() -> None:
    finalized = await finalize_finance_turn(
        rex_action("update_budget", {"name": "Groceries", "amount": 450}),
        settings=AssistantProposalSettings(mode="text"),
        context=financial_context(),
        user_text="Raise my groceries budget to 450",
    )
    proposal = clarity_proposals(finalized)[0]
    assert proposal["action"] == "update_budget"
    assert proposal["payload"] == {"id": "budget-1", "amount": 450.0}


@pytest.mark.asyncio
async def test_delete_budget_resolves_by_name() -> None:
    finalized = await finalize_finance_turn(
        rex_action("delete_budget", {"name": "Groceries"}),
        settings=CARD,
        context=financial_context(),
        user_text="Delete my groceries budget",
    )
    proposal = clarity_proposals(finalized)[0]
    assert proposal["action"] == "delete_budget"
    assert proposal["payload"] == {"id": "budget-1"}
    assert proposal["risk_level"] == "high"


@pytest.mark.asyncio
async def test_a_finance_change_needs_no_permission_toggle() -> None:
    """There is no finance-edits switch: proposing is always allowed.

    The user confirms every change, so a setting that blocked the proposal only
    blocked changes they had explicitly asked for.
    """
    finalized = await finalize_finance_turn(
        "Moving those now.\n"
        + rex_action(
            "categorize_transaction",
            {"merchant": "Starbucks", "category": "Coffee"},
            explicit=True,
        ),
        settings=AssistantProposalSettings(mode="card"),
        context=financial_context(),
        user_text="Recategorize my Starbucks charges as coffee",
    )
    assert clarity_proposals(finalized)
    assert "Companion settings" not in finalized["response"]


@pytest.mark.asyncio
async def test_off_mode_still_prepares_a_change_the_user_asked_for() -> None:
    """Off means Rex stops offering, not that it stops doing what it is told."""
    for action in (
        rex_action(
            "categorize_transaction",
            {"merchant": "Starbucks", "category": "Coffee"},
            explicit=True,
        ),
        rex_action(
            "categorize_transaction",
            {"merchant": "Starbucks", "category": "Coffee"},
        ),
    ):
        finalized = await finalize_finance_turn(
            action,
            settings=AssistantProposalSettings(mode="off"),
            context=financial_context(),
            user_text="Recategorize my Starbucks charges as coffee",
        )
        assert len(clarity_proposals(finalized)) == 1


@pytest.mark.asyncio
async def test_off_mode_keeps_rex_own_finance_offer_to_itself() -> None:
    finalized = await finalize_finance_turn(
        "You could group those.\n"
        + rex_action(
            "categorize_transaction",
            {"merchant": "Starbucks", "category": "Coffee"},
            auto=True,
        ),
        settings=AssistantProposalSettings(mode="off"),
        context=financial_context(),
        user_text="My coffee spending feels messy",
    )
    assert clarity_proposals(finalized) == []
    assert "You could group those." in finalized["response"]


@pytest.mark.asyncio
async def test_text_and_card_modes_both_surface_the_confirm_proposal() -> None:
    for mode in ("text", "card"):
        finalized = await finalize_finance_turn(
            rex_action("create_category", {"name": "Coffee Runs"}),
            settings=AssistantProposalSettings(mode=mode),
            context=financial_context(),
            user_text="Create a coffee runs category",
        )
        assert len(clarity_proposals(finalized)) == 1, mode


@pytest.mark.asyncio
async def test_truth_blocks_recategorized_claim_without_a_proposal() -> None:
    finalized = await finalize_finance_turn(
        "Done — I recategorized that charge as Coffee.",
        settings=CARD,
        context=financial_context(),
        user_text="Recategorize that charge to coffee",
    )
    assert clarity_proposals(finalized) == []
    lowered = finalized["response"].lower()
    assert "i recategorized" not in lowered
    assert "confirmed change" in lowered or "confirmation" in lowered


@pytest.mark.asyncio
async def test_truth_blocks_a_promised_change_with_no_action_behind_it() -> None:
    """Grok promising work it never requested left the user waiting forever."""
    finalized = await finalize_finance_turn(
        "Sure, I'll create dedicated categories for coffee and fast food, then "
        "re-categorize the mismatched transactions accordingly.",
        settings=CARD,
        context=financial_context(),
        user_text=(
            "Can you change this category name from coffee / quick food? Coffee "
            "transactions stay coffee and the rest become fast food"
        ),
    )
    assert clarity_proposals(finalized) == []
    lowered = finalized["response"].lower()
    assert "i'll create" not in lowered
    assert "re-categorize the mismatched" not in lowered


@pytest.mark.asyncio
async def test_success_claim_with_pending_proposal_asks_for_confirm() -> None:
    finalized = await finalize_finance_turn(
        "Done — I moved them to Coffee.\n"
        + rex_action(
            "categorize_transaction",
            {"merchant": "Starbucks", "category": "Coffee"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Recategorize my Starbucks charges as coffee",
    )
    assert len(clarity_proposals(finalized)) == 1
    lowered = finalized["response"].lower()
    assert "tap confirm" in lowered
    assert "done — i moved" not in lowered


@pytest.mark.asyncio
async def test_create_transaction_is_not_a_finance_capability() -> None:
    finalized = await finalize_finance_turn(
        rex_action(
            "create_transaction",
            {"account_id": "acct-1", "amount": 12.0, "type": "expense"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Add a $12 coffee transaction",
    )
    assert clarity_proposals(finalized) == []
    assert "create_transaction" not in CAPABILITY_NAMES


def test_tiny_system_prompt_names_finance_fetch_and_change_rules() -> None:
    prompt = build_tiny_system_prompt(CARD)
    assert "fetch_spend_insight" in prompt
    assert "fetch_account_summary" in prompt
    assert "categorize_transaction" in prompt
    assert "answer only from what comes back" in prompt.lower()
    assert "cannot create transactions" in prompt.lower()
    assert "update_category" in prompt
    assert "describing it does nothing" in prompt.lower()
    assert "user's own buckets" in prompt.lower()

    off_prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="off"))
    assert "still runs finance changes the user asks for" in off_prompt.lower()
