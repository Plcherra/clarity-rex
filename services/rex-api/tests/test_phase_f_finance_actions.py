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
    assert proposal["payload"] == {
        "ids": ["tx-1", "tx-2"],
        "category_id": "cat-coffee",
    }
    assert proposal["status"] == "pending"
    assert "Coffee" in proposal["confirmation_text"]


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
async def test_categorize_without_resolvable_records_makes_no_proposal() -> None:
    finalized = await finalize_finance_turn(
        "I can look at that.\n"
        + rex_action(
            "categorize_transaction",
            {"merchant": "Unknown Diner", "category": "Coffee"},
        ),
        settings=CARD,
        context=financial_context(),
        user_text="Change the diner charge category",
    )
    assert clarity_proposals(finalized) == []


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
async def test_finance_edits_disabled_strips_every_finance_proposal() -> None:
    finalized = await finalize_finance_turn(
        rex_action(
            "categorize_transaction",
            {"merchant": "Starbucks", "category": "Coffee"},
        ),
        settings=AssistantProposalSettings(mode="card", finance_edits_enabled=False),
        context=financial_context(),
        user_text="Recategorize my Starbucks charges as coffee",
    )
    assert clarity_proposals(finalized) == []


@pytest.mark.asyncio
async def test_off_mode_needs_an_explicit_finance_command() -> None:
    auto_turn = await finalize_finance_turn(
        "You could group those.\n"
        + rex_action(
            "categorize_transaction",
            {"merchant": "Starbucks", "category": "Coffee"},
        ),
        settings=AssistantProposalSettings(mode="off"),
        context=financial_context(),
        user_text="My coffee spending feels messy",
    )
    assert clarity_proposals(auto_turn) == []

    explicit_turn = await finalize_finance_turn(
        rex_action(
            "categorize_transaction",
            {"merchant": "Starbucks", "category": "Coffee"},
            explicit=True,
        ),
        settings=AssistantProposalSettings(mode="off"),
        context=financial_context(),
        user_text="Recategorize my Starbucks charges as coffee",
    )
    assert len(clarity_proposals(explicit_turn)) == 1


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
    assert "never invent amounts" in prompt.lower()
    assert "cannot create transactions" in prompt.lower()

    off_prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="off"))
    assert "finance changes need a clear command" in off_prompt.lower()
