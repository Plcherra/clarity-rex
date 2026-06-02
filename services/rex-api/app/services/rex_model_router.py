from dataclasses import dataclass, field
from typing import Optional

from app.config import Settings, get_settings
from app.services.rex_brain_contracts import (
    RexBrainDecision,
    RexContextBudget,
    RexCostTier,
    RexModelProfile,
    RexThinkingLayer,
)


@dataclass(frozen=True)
class RexModelLimits:
    max_prompt_characters: int
    max_output_tokens: int


@dataclass(frozen=True)
class RexModelRoute:
    routing_enabled: bool
    rollout_stage: str
    requested_profile: RexModelProfile
    effective_profile: RexModelProfile
    selected_model: Optional[str]
    fallback_model: Optional[str]
    limits: RexModelLimits
    cost_tier: RexCostTier
    reasons: tuple[str, ...] = field(default_factory=tuple)

    def metadata(self) -> dict:
        return {
            "routing_enabled": self.routing_enabled,
            "rollout_stage": self.rollout_stage,
            "requested_profile": self.requested_profile.value,
            "effective_profile": self.effective_profile.value,
            "selected_model": self.selected_model,
            "fallback_model": self.fallback_model,
            "max_prompt_characters": self.limits.max_prompt_characters,
            "max_output_tokens": self.limits.max_output_tokens,
            "cost_tier": self.cost_tier.value,
            "reasons": list(self.reasons),
        }


PROFILE_LIMITS: dict[RexModelProfile, RexModelLimits] = {
    RexModelProfile.FAST: RexModelLimits(
        max_prompt_characters=6000,
        max_output_tokens=700,
    ),
    RexModelProfile.STANDARD: RexModelLimits(
        max_prompt_characters=14000,
        max_output_tokens=1400,
    ),
    RexModelProfile.REASONING: RexModelLimits(
        max_prompt_characters=28000,
        max_output_tokens=3000,
    ),
}


class RexModelRouter:
    def __init__(self, settings: Optional[Settings] = None) -> None:
        self.settings = settings or get_settings()

    def route_for_decision(self, decision: RexBrainDecision) -> RexModelRoute:
        if not self.settings.rex_brain_routing_enabled:
            return self._disabled_route(decision, rollout_stage=self._rollout_stage())

        rollout_stage = self._rollout_stage()
        if rollout_stage in {"disabled", "logging_only"}:
            return self._disabled_route(
                decision,
                reason=f"rex_brain_rollout_{rollout_stage}",
                rollout_stage=rollout_stage,
            )
        if not self._stage_allows_decision(rollout_stage, decision):
            return self._disabled_route(
                decision,
                reason=f"rex_brain_rollout_{rollout_stage}_blocked_{decision.layer.value}",
                rollout_stage=rollout_stage,
            )

        requested_profile = self._profile_for_decision(decision)
        selected_model = self._model_for_profile(requested_profile)
        reasons = [f"requested_profile:{requested_profile.value}"]
        effective_profile = requested_profile

        if not selected_model:
            selected_model = self.settings.grok_model
            effective_profile = RexModelProfile.STANDARD
            reasons.append("profile_model_missing_fallback_to_grok_model")

        if not selected_model:
            reasons.append("no_model_configured")

        return RexModelRoute(
            routing_enabled=True,
            rollout_stage=rollout_stage,
            requested_profile=requested_profile,
            effective_profile=effective_profile,
            selected_model=selected_model,
            fallback_model=self.settings.grok_model,
            limits=PROFILE_LIMITS[effective_profile],
            cost_tier=self._cost_tier_for_profile(
                effective_profile,
                decision.context_budget,
            ),
            reasons=tuple(reasons),
        )

    def _disabled_route(
        self,
        decision: RexBrainDecision,
        reason: str = "rex_brain_routing_disabled",
        rollout_stage: str = "disabled",
    ) -> RexModelRoute:
        return RexModelRoute(
            routing_enabled=False,
            rollout_stage=rollout_stage,
            requested_profile=decision.model_profile,
            effective_profile=RexModelProfile.STANDARD,
            selected_model=self.settings.grok_model,
            fallback_model=self.settings.grok_model,
            limits=PROFILE_LIMITS[RexModelProfile.STANDARD],
            cost_tier=RexCostTier.MEDIUM,
            reasons=(reason,),
        )

    def _rollout_stage(self) -> str:
        stage = (self.settings.rex_brain_rollout_stage or "disabled").strip().lower()
        aliases = {
            "off": "disabled",
            "log": "logging_only",
            "logs": "logging_only",
            "fast": "fast_contextual",
            "contextual": "fast_contextual",
            "mvp": "launch_safe",
            "launch": "launch_safe",
            "production": "launch_safe",
            "prod": "launch_safe",
            "full": "deep_think_ui",
        }
        return aliases.get(stage, stage)

    def _stage_allows_decision(
        self,
        rollout_stage: str,
        decision: RexBrainDecision,
    ) -> bool:
        allowed_layers = {
            "fast_contextual": {
                RexThinkingLayer.FAST,
                RexThinkingLayer.CONTEXTUAL,
            },
            "analytical": {
                RexThinkingLayer.FAST,
                RexThinkingLayer.CONTEXTUAL,
                RexThinkingLayer.ANALYTICAL,
            },
            "launch_safe": {
                RexThinkingLayer.FAST,
                RexThinkingLayer.CONTEXTUAL,
                RexThinkingLayer.ANALYTICAL,
            },
            "strategic_reflective": set(RexThinkingLayer),
            "deep_think_ui": set(RexThinkingLayer),
        }
        return decision.layer in allowed_layers.get(rollout_stage, set())

    def _profile_for_decision(self, decision: RexBrainDecision) -> RexModelProfile:
        if decision.model_profile == RexModelProfile.REASONING:
            return RexModelProfile.REASONING
        if decision.escalation_source == "user_requested_deep_thinking":
            return RexModelProfile.REASONING
        if decision.needs_reflection:
            return RexModelProfile.REASONING
        if decision.complexity_score >= 8:
            return RexModelProfile.REASONING
        return decision.model_profile

    def _model_for_profile(self, profile: RexModelProfile) -> Optional[str]:
        if profile == RexModelProfile.FAST:
            return self.settings.grok_fast_model or self.settings.grok_model
        if profile == RexModelProfile.STANDARD:
            return self.settings.grok_standard_model or self.settings.grok_model
        return self.settings.grok_reasoning_model or self.settings.grok_model

    def _cost_tier_for_profile(
        self,
        profile: RexModelProfile,
        context_budget: RexContextBudget,
    ) -> RexCostTier:
        if (
            profile == RexModelProfile.REASONING
            or context_budget == RexContextBudget.HIGH
        ):
            return RexCostTier.HIGH
        if (
            profile == RexModelProfile.STANDARD
            or context_budget == RexContextBudget.MEDIUM
        ):
            return RexCostTier.MEDIUM
        return RexCostTier.LOW
