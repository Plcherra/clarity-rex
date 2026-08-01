"""Finance capability entry: fetch requests + confirmable finance changes."""

from __future__ import annotations

from typing import Iterable, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.brain_action_schema import BrainAction
from app.services.capabilities.finance_action_payload import (
    FINANCE_FETCH_ACTIONS,
    FINANCE_MUTATE_ACTIONS,
    FinanceFetchRequest,
    fetch_request_from_action,
)
from app.services.capabilities.finance_capability_mutate import (
    clarity_proposal_for_action,
    finance_mutate_allowed,
)
from app.services.capabilities.finance_mutate_outcome import (
    UNRESOLVED_TARGET,
    FinanceMutateOutcome,
)
from app.services.category_name_normalization import normalized_category_key


def is_finance_action(action: BrainAction) -> bool:
    return is_finance_fetch_action(action) or is_finance_mutate_action(action)


def is_finance_fetch_action(action: BrainAction) -> bool:
    return action.name in FINANCE_FETCH_ACTIONS


def is_finance_mutate_action(action: BrainAction) -> bool:
    return action.name in FINANCE_MUTATE_ACTIONS


def finance_fetch_requests(
    actions: Iterable[BrainAction],
) -> list[FinanceFetchRequest]:
    requests: list[FinanceFetchRequest] = []
    for action in actions:
        request = fetch_request_from_action(action)
        if request is not None:
            requests.append(request)
    return requests


def handle_finance_action(
    action: BrainAction,
    *,
    settings: AssistantProposalSettings,
    clarity_action_parser,
    financial_context: Optional[dict] = None,
    index: int = 1,
) -> Optional[dict]:
    """Return one confirmable clarity proposal for a finance mutate action."""
    if not is_finance_mutate_action(action):
        return None
    if not finance_mutate_allowed(action, settings):
        return None
    raw = clarity_proposal_for_action(action, financial_context=financial_context)
    if raw is None:
        return None
    return clarity_action_parser.normalize_proposal(raw, index=index)


def collect_finance_proposals(
    actions: Iterable[BrainAction],
    *,
    settings: AssistantProposalSettings,
    clarity_action_parser,
    financial_context: Optional[dict] = None,
) -> FinanceMutateOutcome:
    """Confirmable finance changes, plus why any requested change fell out."""
    proposals: list[dict] = []
    reasons: list[str] = []
    for action in actions:
        if not is_finance_mutate_action(action):
            continue
        if not finance_mutate_allowed(action, settings):
            # Off mode: Rex's own offer stays unspoken, which is the setting
            # working, not a change the user asked for going missing.
            continue
        raw = clarity_proposal_for_action(
            action,
            financial_context=financial_context,
        )
        if raw is None:
            reasons.append(UNRESOLVED_TARGET)
            continue
        proposals.append(
            clarity_action_parser.normalize_proposal(raw, index=len(proposals) + 1)
        )
    return FinanceMutateOutcome(
        proposals=without_redundant_category_creates(proposals),
        blocked_reasons=tuple(reasons),
    )


def without_redundant_category_creates(proposals: list[dict]) -> list[dict]:
    """Drop a create card whose category another card already creates.

    Asked to make a category and move rows into it, Grok names both capabilities
    and the move already carries `new_category`. Two cards for one intent read as
    two changes, and the second confirm looks like it failed once the first has
    made the category.
    """
    covered = {
        _created_category_key(proposal.get("payload"))
        for proposal in proposals
        if proposal.get("action") == "bulk_update_transaction_category"
    }
    covered.discard(None)
    if not covered:
        return proposals
    return [
        proposal
        for proposal in proposals
        if proposal.get("action") != "create_category"
        or _category_key(proposal.get("payload")) not in covered
    ]


def _created_category_key(payload: object) -> Optional[str]:
    if not isinstance(payload, dict):
        return None
    return _category_key(payload.get("new_category"))


def _category_key(payload: object) -> Optional[str]:
    if not isinstance(payload, dict):
        return None
    name = payload.get("name")
    key = normalized_category_key(name) if name else ""
    return key or None
