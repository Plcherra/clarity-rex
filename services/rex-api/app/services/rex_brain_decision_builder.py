from app.services.rex_brain_config import RexThinkingRouterConfig
from app.services.rex_brain_contracts import (
    RexBrainChannel,
    RexBrainDecision,
    RexBrainInput,
    RexContextBudget,
    RexCostTier,
    RexLatencyClass,
    RexModelProfile,
    RexOutputMode,
    RexPendingActionContract,
    RexThinkingLayer,
)
from app.services.rex_brain_terms import looks_like_recall


class RexBrainDecisionBuilder:
    def __init__(self, config: RexThinkingRouterConfig) -> None:
        self.config = config

    def build(
        self,
        brain_input: RexBrainInput,
        layer: RexThinkingLayer,
        complexity_score: int,
        reasons: tuple[str, ...],
        needs_external_research: bool = False,
        requires_research_opt_in: bool = False,
        needs_scenario_simulation: bool = False,
        needs_proactive_insight: bool = False,
        requires_proactive_opt_in: bool = False,
        needs_daily_focus: bool = False,
        needs_planning_workspace: bool = False,
        planning_workspace_intent: str = "none",
        needs_self_evaluation: bool = False,
        needs_long_term_review: bool = False,
        long_term_review_targets: tuple[str, ...] = (),
        needs_confirmed_action_preview: bool = False,
        confirmed_action_intent: str = "none",
        confirmed_action_targets: tuple[str, ...] = (),
        response_style_profile: str = "default",
        response_style_source: str = "default",
    ) -> RexBrainDecision:
        model_profile = self.model_profile_for(
            brain_input,
            layer,
            complexity_score,
            reasons,
        )
        context_budget = self.context_budget_for(
            brain_input,
            layer,
            complexity_score,
            reasons,
        )
        expected_context_sources = self.expected_context_sources(brain_input, layer)
        return RexBrainDecision(
            layer=layer,
            model_profile=model_profile,
            complexity_score=complexity_score,
            context_budget=context_budget,
            output_mode=self.output_mode_for(layer),
            latency_class=self.latency_class_for(brain_input, model_profile, layer),
            cost_tier=self.cost_tier_for(model_profile, context_budget),
            reasons=reasons,
            escalation_source=self.escalation_source(reasons),
            expected_context_sources=expected_context_sources,
            needs_financial_context="financial" in expected_context_sources,
            needs_memory_context="memory" in expected_context_sources,
            needs_reflection=layer == RexThinkingLayer.REFLECTIVE
            or complexity_score >= self.config.deep_score_threshold + 2,
            needs_external_research=needs_external_research,
            requires_research_opt_in=requires_research_opt_in,
            needs_scenario_simulation=needs_scenario_simulation,
            needs_proactive_insight=needs_proactive_insight,
            requires_proactive_opt_in=requires_proactive_opt_in,
            needs_daily_focus=needs_daily_focus,
            needs_planning_workspace=needs_planning_workspace,
            planning_workspace_intent=planning_workspace_intent,
            needs_self_evaluation=needs_self_evaluation,
            expose_self_evaluation=(
                needs_self_evaluation and brain_input.rex_brain_debug_enabled
            ),
            self_evaluation_dimensions=(
                (
                    "correctness",
                    "usefulness",
                    "missing_context",
                    "tone_fit",
                )
                if needs_self_evaluation
                else ()
            ),
            response_style_profile=response_style_profile,
            response_style_source=response_style_source,
            needs_long_term_review=needs_long_term_review,
            long_term_review_targets=long_term_review_targets,
            requires_long_term_review_confirmation=needs_long_term_review,
            needs_confirmed_action_preview=needs_confirmed_action_preview,
            confirmed_action_intent=confirmed_action_intent,
            confirmed_action_targets=confirmed_action_targets,
            requires_action_confirmation=needs_confirmed_action_preview,
            pending_action_contract=pending_action_contract_for(
                needs_confirmed_action_preview=needs_confirmed_action_preview,
                confirmed_action_intent=confirmed_action_intent,
                confirmed_action_targets=confirmed_action_targets,
            ),
        )

    def layer_for(
        self,
        normalized: str,
        score: int,
        reasons: list[str],
        brain_input: RexBrainInput,
    ) -> RexThinkingLayer:
        if "reflection_requested" in reasons:
            return RexThinkingLayer.REFLECTIVE
        if "research_opt_in_required" in reasons:
            return RexThinkingLayer.CONTEXTUAL
        if "proactive_opt_in_required" in reasons:
            return RexThinkingLayer.CONTEXTUAL
        if "safety_sensitive_language" in reasons:
            return RexThinkingLayer.ANALYTICAL
        if "planning_workspace_requested" in reasons:
            return RexThinkingLayer.STRATEGIC
        if "long_term_review_requested" in reasons:
            return RexThinkingLayer.REFLECTIVE
        if "confirmed_action_preview_requested" in reasons:
            return RexThinkingLayer.REFLECTIVE
        if "daily_focus_requested" in reasons:
            return RexThinkingLayer.STRATEGIC
        if "proactive_insight_requested" in reasons:
            if (
                "strategic_language" in reasons
                or brain_input.has_goals
                or brain_input.has_pending_commitments
            ):
                return RexThinkingLayer.STRATEGIC
            return RexThinkingLayer.ANALYTICAL
        if "scenario_simulation_requested" in reasons:
            if (
                "strategic_language" in reasons
                or brain_input.has_goals
                or brain_input.has_pending_commitments
            ):
                return RexThinkingLayer.STRATEGIC
            return RexThinkingLayer.ANALYTICAL
        if "user_requested_deep_thinking" in reasons and (
            "strategic_language" in reasons
            or brain_input.has_goals
            or brain_input.has_pending_commitments
        ):
            return RexThinkingLayer.STRATEGIC
        if "strategic_language" in reasons:
            return RexThinkingLayer.STRATEGIC
        if "coaching_language" in reasons:
            return RexThinkingLayer.COACHING
        if "analytical_language" in reasons or "code_or_debug_language" in reasons:
            return RexThinkingLayer.ANALYTICAL
        if brain_input.has_financial_context and score >= 3:
            return RexThinkingLayer.ANALYTICAL
        if "memory_recall_language" in reasons or looks_like_recall(normalized):
            return RexThinkingLayer.CONTEXTUAL
        if "multi_step_request" in reasons or "file_attached" in reasons:
            return RexThinkingLayer.CONTEXTUAL
        if (
            brain_input.has_structured_memory
            or brain_input.conversation_message_count > 4
        ):
            return RexThinkingLayer.CONTEXTUAL
        if score <= 2 and len(normalized.split()) <= self.config.max_fast_words:
            return RexThinkingLayer.FAST
        return RexThinkingLayer.CONTEXTUAL

    def needs_self_evaluation(
        self,
        *,
        layer: RexThinkingLayer,
        score: int,
        reasons: list[str],
    ) -> bool:
        if layer == RexThinkingLayer.FAST:
            return False
        if layer in {
            RexThinkingLayer.ANALYTICAL,
            RexThinkingLayer.STRATEGIC,
            RexThinkingLayer.REFLECTIVE,
        }:
            return True
        if score >= self.config.deep_score_threshold:
            return True
        return any(
            reason in reasons
            for reason in (
                "safety_sensitive_language",
                "external_research_needed",
                "scenario_simulation_requested",
                "proactive_insight_requested",
                "daily_focus_requested",
                "planning_workspace_requested",
                "long_term_review_requested",
                "confirmed_action_preview_requested",
            )
        )

    def model_profile_for(
        self,
        brain_input: RexBrainInput,
        layer: RexThinkingLayer,
        score: int,
        reasons: tuple[str, ...],
    ) -> RexModelProfile:
        if layer == RexThinkingLayer.FAST:
            return RexModelProfile.FAST
        if brain_input.user_requested_deep_thinking:
            return RexModelProfile.REASONING
        if layer in {RexThinkingLayer.CONTEXTUAL, RexThinkingLayer.COACHING}:
            if brain_input.channel == RexBrainChannel.VOICE:
                return RexModelProfile.FAST
            return RexModelProfile.STANDARD
        if brain_input.channel == RexBrainChannel.VOICE:
            threshold = self.config.voice_deep_score_threshold
            if self.voice_intent_score(score, reasons) >= threshold:
                return RexModelProfile.REASONING
            return RexModelProfile.STANDARD
        if score >= self.config.deep_score_threshold:
            return RexModelProfile.REASONING
        if layer in {
            RexThinkingLayer.ANALYTICAL,
            RexThinkingLayer.STRATEGIC,
            RexThinkingLayer.REFLECTIVE,
        }:
            return RexModelProfile.REASONING
        return RexModelProfile.STANDARD

    def context_budget_for(
        self,
        brain_input: RexBrainInput,
        layer: RexThinkingLayer,
        score: int,
        reasons: tuple[str, ...],
    ) -> RexContextBudget:
        if layer == RexThinkingLayer.FAST:
            return RexContextBudget.TINY
        if brain_input.channel == RexBrainChannel.VOICE:
            if brain_input.has_file:
                return RexContextBudget.MEDIUM
            if brain_input.user_requested_deep_thinking:
                return RexContextBudget.MEDIUM
            if self.voice_intent_score(score, reasons) >= (
                self.config.voice_deep_score_threshold
            ):
                return RexContextBudget.MEDIUM
            return RexContextBudget.SMALL
        if layer in {RexThinkingLayer.CONTEXTUAL, RexThinkingLayer.COACHING}:
            return RexContextBudget.SMALL
        if (
            layer == RexThinkingLayer.STRATEGIC
            and brain_input.has_financial_context
            and brain_input.has_goals
        ):
            return RexContextBudget.HIGH
        if layer == RexThinkingLayer.REFLECTIVE:
            return RexContextBudget.MEDIUM
        if score >= 8 or brain_input.has_file:
            return RexContextBudget.HIGH
        return RexContextBudget.MEDIUM

    def expected_context_sources(
        self,
        brain_input: RexBrainInput,
        layer: RexThinkingLayer,
    ) -> tuple[str, ...]:
        sources: list[str] = []
        if layer in {RexThinkingLayer.ANALYTICAL, RexThinkingLayer.STRATEGIC}:
            if brain_input.has_financial_context:
                sources.append("financial")
        if layer in {
            RexThinkingLayer.CONTEXTUAL,
            RexThinkingLayer.STRATEGIC,
            RexThinkingLayer.COACHING,
            RexThinkingLayer.REFLECTIVE,
        }:
            if brain_input.has_structured_memory:
                sources.append("memory")
        if layer == RexThinkingLayer.STRATEGIC and brain_input.has_goals:
            sources.append("goals")
        if layer == RexThinkingLayer.REFLECTIVE and brain_input.has_goals:
            sources.append("goals")
        if layer in {RexThinkingLayer.STRATEGIC, RexThinkingLayer.COACHING} and (
            brain_input.has_pending_commitments
        ):
            sources.append("pending_commitments")
        if layer == RexThinkingLayer.REFLECTIVE:
            if brain_input.has_financial_context:
                sources.append("financial")
            if brain_input.has_pending_commitments:
                sources.append("pending_commitments")
            if brain_input.has_structured_memory:
                sources.append("memory")
            if brain_input.has_goals:
                sources.append("goals")
        if brain_input.has_file:
            sources.append("attachments")
        return tuple(dict.fromkeys(sources))

    def voice_intent_score(self, score: int, reasons: tuple[str, ...]) -> int:
        context_only_reasons = {
            "financial_context_available": 2,
            "structured_memory_available": 1,
            "goals_available": 1,
            "pending_commitments_available": 1,
        }
        context_score = sum(
            weight for reason, weight in context_only_reasons.items() if reason in reasons
        )
        return max(0, score - context_score)

    @staticmethod
    def output_mode_for(layer: RexThinkingLayer) -> RexOutputMode:
        if layer == RexThinkingLayer.CONTEXTUAL:
            return RexOutputMode.GROUNDED_TEXT
        if layer == RexThinkingLayer.ANALYTICAL:
            return RexOutputMode.ANALYSIS
        if layer == RexThinkingLayer.STRATEGIC:
            return RexOutputMode.STRATEGIC_PLAN
        if layer == RexThinkingLayer.REFLECTIVE:
            return RexOutputMode.REFLECTIVE_CHECK
        if layer == RexThinkingLayer.COACHING:
            return RexOutputMode.COACHING
        return RexOutputMode.CONCISE_TEXT

    @staticmethod
    def latency_class_for(
        brain_input: RexBrainInput,
        model_profile: RexModelProfile,
        layer: RexThinkingLayer,
    ) -> RexLatencyClass:
        if brain_input.channel == RexBrainChannel.VOICE:
            if model_profile == RexModelProfile.REASONING:
                return RexLatencyClass.STANDARD
            return RexLatencyClass.REALTIME
        if model_profile == RexModelProfile.REASONING:
            return RexLatencyClass.DEEP
        if layer == RexThinkingLayer.FAST:
            return RexLatencyClass.FAST
        return RexLatencyClass.STANDARD

    @staticmethod
    def cost_tier_for(
        model_profile: RexModelProfile,
        context_budget: RexContextBudget,
    ) -> RexCostTier:
        if model_profile == RexModelProfile.REASONING or context_budget in {
            RexContextBudget.HIGH,
        }:
            return RexCostTier.HIGH
        if model_profile == RexModelProfile.STANDARD or context_budget in {
            RexContextBudget.MEDIUM,
        }:
            return RexCostTier.MEDIUM
        return RexCostTier.LOW

    @staticmethod
    def escalation_source(reasons: tuple[str, ...]) -> str:
        for reason in (
            "user_requested_deep_thinking",
            "reflection_requested",
            "planning_workspace_requested",
            "long_term_review_requested",
            "confirmed_action_preview_requested",
            "daily_focus_requested",
            "proactive_insight_requested",
            "strategic_language",
            "analytical_language",
            "code_or_debug_language",
            "safety_sensitive_language",
            "scenario_simulation_requested",
            "external_research_needed",
            "file_attached",
        ):
            if reason in reasons:
                return reason
        return "none"


def pending_action_contract_for(
    *,
    needs_confirmed_action_preview: bool,
    confirmed_action_intent: str,
    confirmed_action_targets: tuple[str, ...],
) -> RexPendingActionContract:
    if not needs_confirmed_action_preview:
        return RexPendingActionContract()

    return RexPendingActionContract(
        action_intent=confirmed_action_intent,
        target_type=(
            confirmed_action_targets[0]
            if len(confirmed_action_targets) == 1
            else "multiple"
            if len(confirmed_action_targets) > 1
            else "unspecified"
        ),
        requires_confirmation=True,
    )
