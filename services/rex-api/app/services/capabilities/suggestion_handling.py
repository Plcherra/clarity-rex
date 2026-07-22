"""Mode-specific handling plan for companion suggestions."""

from __future__ import annotations

from dataclasses import dataclass

from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_CARD,
    AUTO_PROPOSALS_OFF,
    AssistantProposalSettings,
)


@dataclass(frozen=True)
class SuggestionHandlingPlan:
    """How the body should surface or apply a structured suggestion."""

    apply_immediately: bool
    surface_client_cards: bool
    requires_confirmation: bool


def suggestion_handling_plan(
    settings: AssistantProposalSettings,
) -> SuggestionHandlingPlan:
    """Translate proposal settings into one reusable execution plan."""
    if settings.mode == AUTO_PROPOSALS_OFF:
        return SuggestionHandlingPlan(
            apply_immediately=True,
            surface_client_cards=False,
            requires_confirmation=False,
        )
    if settings.mode == AUTO_PROPOSALS_CARD:
        return SuggestionHandlingPlan(
            apply_immediately=False,
            surface_client_cards=True,
            requires_confirmation=True,
        )
    return SuggestionHandlingPlan(
        apply_immediately=False,
        surface_client_cards=False,
        requires_confirmation=True,
    )
