"""Filter clarity_action proposals based on companion settings."""

from __future__ import annotations

FINANCE_CONTROL_ACTIONS = frozenset(
    {
        "create_transaction",
        "update_transaction",
        "delete_transaction",
        "bulk_update_transaction_category",
        "delete_import_batch",
        "create_category",
        "update_category",
        "delete_category",
        "create_budget",
        "update_budget",
        "delete_budget",
    }
)


def filter_clarity_action_proposals(
    proposals: list[dict],
    *,
    finance_edits_enabled: bool,
) -> list[dict]:
    if finance_edits_enabled:
        return proposals
    return [
        proposal
        for proposal in proposals
        if str(proposal.get("action") or "").strip() not in FINANCE_CONTROL_ACTIONS
    ]
