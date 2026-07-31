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
from app.services.clarity_action_proposal_filter import (
    filter_clarity_action_proposals,
)


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
) -> list[dict]:
    """Finance proposals allowed by Auto Suggestions and the finance edits gate."""
    proposals: list[dict] = []
    for action in actions:
        proposal = handle_finance_action(
            action,
            settings=settings,
            clarity_action_parser=clarity_action_parser,
            financial_context=financial_context,
            index=len(proposals) + 1,
        )
        if proposal is not None:
            proposals.append(proposal)
    return filter_clarity_action_proposals(
        proposals,
        finance_edits_enabled=settings.finance_edits_enabled,
    )
