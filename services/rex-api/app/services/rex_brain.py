"""Experimental layered Rex Brain router.

MVP production chat and voice use ChatService + SimpleRexBrain. This module is
kept outside the production path for future advanced routing work.
"""

from typing import Optional

from app.services.rex_brain_config import RexThinkingRouterConfig
from app.services.rex_brain_contracts import (
    RexBrainDecision,
    RexBrainInput,
    RexThinkingLayer,
)
from app.services.rex_brain_decision_builder import RexBrainDecisionBuilder
from app.services.rex_brain_scoring import RexBrainScorer


class RexThinkingRouter:
    """Cheap deterministic router for Rex's first brain pass.

    The public router stays intentionally small. Term matching and score
    calculation live in `rex_brain_scoring`, while final layer/model/context
    decisions live in `rex_brain_decision_builder`.
    """

    def __init__(self, config: Optional[RexThinkingRouterConfig] = None) -> None:
        self.config = config or RexThinkingRouterConfig()
        self.scorer = RexBrainScorer(self.config)
        self.decision_builder = RexBrainDecisionBuilder(self.config)

    def route(self, brain_input: RexBrainInput) -> RexBrainDecision:
        route_score = self.scorer.score(brain_input)

        if self.scorer.is_casual_fast_message(
            route_score.message,
            route_score.reasons,
        ):
            return self.decision_builder.build(
                brain_input=brain_input,
                layer=RexThinkingLayer.FAST,
                complexity_score=0,
                reasons=("casual_message",),
                needs_external_research=False,
                requires_research_opt_in=False,
                needs_scenario_simulation=False,
                needs_proactive_insight=False,
                requires_proactive_opt_in=False,
                needs_daily_focus=False,
                needs_planning_workspace=False,
                planning_workspace_intent="none",
                needs_self_evaluation=False,
                needs_long_term_review=False,
                long_term_review_targets=(),
                needs_confirmed_action_preview=False,
                confirmed_action_intent="none",
                confirmed_action_targets=(),
                response_style_profile=route_score.response_style_profile,
                response_style_source=route_score.response_style_source,
            )

        layer = self.decision_builder.layer_for(
            route_score.normalized,
            route_score.score,
            route_score.reasons,
            brain_input,
        )
        needs_self_evaluation = self.decision_builder.needs_self_evaluation(
            layer=layer,
            score=route_score.score,
            reasons=route_score.reasons,
        )
        return self.decision_builder.build(
            brain_input=brain_input,
            layer=layer,
            complexity_score=route_score.score,
            reasons=tuple(route_score.reasons or ["default_fast_route"]),
            needs_external_research=route_score.needs_external_research,
            requires_research_opt_in=(
                route_score.needs_external_research
                and not route_score.research_opted_in
            ),
            needs_scenario_simulation=route_score.needs_scenario_simulation,
            needs_proactive_insight=route_score.needs_proactive_insight,
            requires_proactive_opt_in=route_score.requires_proactive_opt_in,
            needs_daily_focus=route_score.needs_daily_focus,
            needs_planning_workspace=route_score.needs_planning_workspace,
            planning_workspace_intent=route_score.planning_workspace_intent,
            needs_self_evaluation=needs_self_evaluation,
            needs_long_term_review=route_score.needs_long_term_review,
            long_term_review_targets=route_score.long_term_review_targets,
            needs_confirmed_action_preview=(
                route_score.needs_confirmed_action_preview
            ),
            confirmed_action_intent=route_score.confirmed_action_intent,
            confirmed_action_targets=route_score.confirmed_action_targets,
            response_style_profile=route_score.response_style_profile,
            response_style_source=route_score.response_style_source,
        )


class RexBrain:
    def __init__(self, router: Optional[RexThinkingRouter] = None) -> None:
        self.router = router or RexThinkingRouter()

    def plan_turn(self, brain_input: RexBrainInput) -> RexBrainDecision:
        return self.router.route(brain_input)
