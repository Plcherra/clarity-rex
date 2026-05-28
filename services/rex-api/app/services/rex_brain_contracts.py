from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class RexBrainChannel(str, Enum):
    CHAT = "chat"
    VOICE = "voice"


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
        }
