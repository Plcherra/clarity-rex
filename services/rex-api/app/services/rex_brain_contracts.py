"""Experimental layered Rex Brain contracts.

NON-PRODUCTION FOR LAUNCH.

MVP production chat and voice use ChatService + SimpleRexBrain. This module is
kept for experimental routing tests and future advanced brain work only.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional

from app.services.rex_channel import RexBrainChannel


class RexThinkingLayer(str, Enum):
    FAST = "layer_0_fast"
    CONTEXTUAL = "layer_1_contextual"
    ANALYTICAL = "layer_2_analytical"
    STRATEGIC = "layer_3_strategic"
    REFLECTIVE = "layer_4_reflective"
    COACHING = "layer_5_coaching"


class RexModelProfile(str, Enum):
    FAST = "fast"
    STANDARD = "standard"
    REASONING = "reasoning"


class RexContextBudget(str, Enum):
    TINY = "tiny"
    SMALL = "small"
    MEDIUM = "medium"
    HIGH = "high"


class RexOutputMode(str, Enum):
    CONCISE_TEXT = "concise_text"
    GROUNDED_TEXT = "grounded_text"
    ANALYSIS = "analysis"
    STRATEGIC_PLAN = "strategic_plan"
    REFLECTIVE_CHECK = "reflective_check"
    COACHING = "coaching"


class RexLatencyClass(str, Enum):
    REALTIME = "realtime"
    FAST = "fast"
    STANDARD = "standard"
    DEEP = "deep"


class RexCostTier(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class RexPendingActionStatus(str, Enum):
    PREVIEW_ONLY = "preview_only"
    AWAITING_USER = "awaiting_user"
    CONFIRMED = "confirmed"
    EXECUTED = "executed"
    FAILED = "failed"


@dataclass(frozen=True)
class RexPendingActionContract:
    pending_action_id: Optional[str] = None
    action_intent: str = "none"
    target_type: str = "unspecified"
    target_ids: tuple[str, ...] = field(default_factory=tuple)
    proposed_diff: tuple[dict[str, Any], ...] = field(default_factory=tuple)
    requires_confirmation: bool = True
    confirmed_at: Optional[str] = None
    executed_at: Optional[str] = None
    execution_result: Optional[dict[str, Any]] = None
    status: RexPendingActionStatus = RexPendingActionStatus.PREVIEW_ONLY

    @property
    def is_preview_only(self) -> bool:
        return self.status == RexPendingActionStatus.PREVIEW_ONLY

    @property
    def is_executable(self) -> bool:
        return bool(
            self.pending_action_id
            and self.action_intent != "none"
            and self.target_type != "unspecified"
            and self.target_ids
            and self.proposed_diff
            and self.requires_confirmation
            and self.confirmed_at
            and self.status == RexPendingActionStatus.CONFIRMED
        )

    def metadata(self) -> dict:
        return {
            "pending_action_id": self.pending_action_id,
            "action_intent": self.action_intent,
            "target_type": self.target_type,
            "target_ids": list(self.target_ids),
            "proposed_diff_count": len(self.proposed_diff),
            "requires_confirmation": self.requires_confirmation,
            "confirmed_at": self.confirmed_at,
            "executed_at": self.executed_at,
            "execution_result": self.execution_result,
            "status": self.status.value,
            "is_preview_only": self.is_preview_only,
            "is_executable": self.is_executable,
        }


@dataclass(frozen=True)
class RexBrainInput:
    message: str
    channel: RexBrainChannel = RexBrainChannel.CHAT
    conversation_id: Optional[str] = None
    has_file: bool = False
    has_financial_context: bool = False
    has_structured_memory: bool = False
    has_goals: bool = False
    has_pending_commitments: bool = False
    conversation_message_count: int = 0
    user_requested_deep_thinking: bool = False
    user_opted_into_research: bool = False
    user_enabled_proactive_insights: bool = False
    rex_brain_debug_enabled: bool = False
    user_preference_profile: str = "default"


@dataclass(frozen=True)
class RexBrainDecision:
    layer: RexThinkingLayer
    model_profile: RexModelProfile
    complexity_score: int
    context_budget: RexContextBudget
    output_mode: RexOutputMode
    latency_class: RexLatencyClass
    cost_tier: RexCostTier
    reasons: tuple[str, ...] = field(default_factory=tuple)
    escalation_source: str = "none"
    expected_context_sources: tuple[str, ...] = field(default_factory=tuple)
    needs_financial_context: bool = False
    needs_memory_context: bool = False
    needs_reflection: bool = False
    needs_external_research: bool = False
    requires_research_opt_in: bool = False
    needs_scenario_simulation: bool = False
    needs_proactive_insight: bool = False
    requires_proactive_opt_in: bool = False
    needs_daily_focus: bool = False
    needs_planning_workspace: bool = False
    planning_workspace_intent: str = "none"
    needs_self_evaluation: bool = False
    expose_self_evaluation: bool = False
    self_evaluation_dimensions: tuple[str, ...] = field(default_factory=tuple)
    response_style_profile: str = "default"
    response_style_source: str = "default"
    needs_long_term_review: bool = False
    long_term_review_targets: tuple[str, ...] = field(default_factory=tuple)
    requires_long_term_review_confirmation: bool = False
    needs_confirmed_action_preview: bool = False
    confirmed_action_intent: str = "none"
    confirmed_action_targets: tuple[str, ...] = field(default_factory=tuple)
    requires_action_confirmation: bool = False
    pending_action_contract: RexPendingActionContract = field(
        default_factory=RexPendingActionContract
    )

    @property
    def is_deep(self) -> bool:
        return self.model_profile == RexModelProfile.REASONING

    def metadata(self) -> dict:
        return {
            "layer": self.layer.value,
            "model_profile": self.model_profile.value,
            "complexity_score": self.complexity_score,
            "context_budget": self.context_budget.value,
            "output_mode": self.output_mode.value,
            "latency_class": self.latency_class.value,
            "cost_tier": self.cost_tier.value,
            "reasons": list(self.reasons),
            "escalation_source": self.escalation_source,
            "expected_context_sources": list(self.expected_context_sources),
            "needs_financial_context": self.needs_financial_context,
            "needs_memory_context": self.needs_memory_context,
            "needs_reflection": self.needs_reflection,
            "needs_external_research": self.needs_external_research,
            "requires_research_opt_in": self.requires_research_opt_in,
            "needs_scenario_simulation": self.needs_scenario_simulation,
            "needs_proactive_insight": self.needs_proactive_insight,
            "requires_proactive_opt_in": self.requires_proactive_opt_in,
            "needs_daily_focus": self.needs_daily_focus,
            "needs_planning_workspace": self.needs_planning_workspace,
            "planning_workspace_intent": self.planning_workspace_intent,
            "needs_self_evaluation": self.needs_self_evaluation,
            "expose_self_evaluation": self.expose_self_evaluation,
            "self_evaluation_dimensions": list(self.self_evaluation_dimensions),
            "response_style_profile": self.response_style_profile,
            "response_style_source": self.response_style_source,
            "needs_long_term_review": self.needs_long_term_review,
            "long_term_review_targets": list(self.long_term_review_targets),
            "requires_long_term_review_confirmation": (
                self.requires_long_term_review_confirmation
            ),
            "needs_confirmed_action_preview": self.needs_confirmed_action_preview,
            "confirmed_action_intent": self.confirmed_action_intent,
            "confirmed_action_targets": list(self.confirmed_action_targets),
            "requires_action_confirmation": self.requires_action_confirmation,
            "pending_action_contract": self.pending_action_contract.metadata(),
        }


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


def default_model_route(
    decision: RexBrainDecision,
    *,
    grok_model: Optional[str],
    reason: str = "simple_rex_brain_only",
) -> RexModelRoute:
    """Production and compatibility helper: always use the standard Grok model."""
    return RexModelRoute(
        routing_enabled=False,
        rollout_stage="disabled",
        requested_profile=decision.model_profile,
        effective_profile=RexModelProfile.STANDARD,
        selected_model=grok_model,
        fallback_model=grok_model,
        limits=PROFILE_LIMITS[RexModelProfile.STANDARD],
        cost_tier=RexCostTier.MEDIUM,
        reasons=(reason,),
    )
