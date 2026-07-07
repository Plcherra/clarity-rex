from app.services.clarity_action_proposal_filter import (
    FINANCE_CONTROL_ACTIONS,
    filter_clarity_action_proposals,
)


def test_filter_clarity_action_proposals_keeps_finance_actions_when_enabled():
    proposals = [
        {"action": "update_transaction", "payload": {"id": "tx-1"}},
        {"action": "save_plan", "payload": {"title": "Goal"}},
    ]

    filtered = filter_clarity_action_proposals(
        proposals,
        finance_edits_enabled=True,
    )

    assert filtered == proposals


def test_filter_clarity_action_proposals_strips_finance_actions_when_disabled():
    proposals = [
        {"action": "update_transaction", "payload": {"id": "tx-1"}},
        {"action": "create_budget", "payload": {"name": "Food"}},
    ]

    filtered = filter_clarity_action_proposals(
        proposals,
        finance_edits_enabled=False,
    )

    assert filtered == []


def test_finance_control_actions_cover_transaction_and_budget_writes():
    assert "update_transaction" in FINANCE_CONTROL_ACTIONS
    assert "create_budget" in FINANCE_CONTROL_ACTIONS
    assert "create_account" not in FINANCE_CONTROL_ACTIONS
