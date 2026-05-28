import re
from dataclasses import dataclass
from typing import Optional

from app.services.rex_brain_contracts import (
    RexBrainChannel,
    RexBrainDecision,
    RexBrainInput,
    RexContextBudget,
    RexCostTier,
    RexLatencyClass,
    RexModelProfile,
    RexOutputMode,
    RexThinkingLayer,
)


@dataclass(frozen=True)
class RexThinkingRouterConfig:
    deep_score_threshold: int = 6
    max_fast_words: int = 20
    max_fast_message_length: int = 240
    voice_deep_score_threshold: int = 8


class RexThinkingRouter:
    """Cheap deterministic router for Rex's first brain pass.

    Phase 1 keeps routing fully local and predictable. The router only returns a
    plan; it does not change prompts, model calls, or production chat behavior.
    """

    _deep_phrases = (
        "deep think",
        "think deeply",
        "analyze thoroughly",
        "full analysis",
        "reason through",
        "what am i missing",
        "long term",
        "long-term",
    )
    _analytical_terms = (
        "analyze",
        "analysis",
        "calculate",
        "compare",
        "why",
        "budget",
        "spending",
        "spend",
        "income",
        "cash flow",
        "cashflow",
        "transaction",
        "tax",
        "debt",
        "investment",
        "forecast",
        "subscription",
        "category",
        "finance",
    )
    _strategic_terms = (
        "plan",
        "strategy",
        "goal",
        "goals",
        "priority",
        "tradeoff",
        "trade-off",
        "choose",
        "roadmap",
        "next month",
        "next year",
        "milestone",
        "timeline",
    )
    _reflective_terms = (
        "check yourself",
        "double check",
        "verify",
        "critique",
        "contradiction",
        "consistent",
        "mistake",
        "wrong",
        "audit",
    )
    _coaching_terms = (
        "motivate",
        "motivation",
        "coach",
        "help me stay",
        "habit",
        "craving",
        "accountability",
        "encourage",
        "overwhelmed",
        "stuck",
    )
    _memory_terms = (
        "remember",
        "recall",
        "what did we decide",
        "what did i say",
        "last time",
        "before",
    )
    _safety_sensitive_terms = (
        "tax",
        "legal",
        "lawsuit",
        "irs",
        "bankruptcy",
        "medical",
        "diagnose",
    )
    _code_terms = (
        "code",
        "debug",
        "stack trace",
        "exception",
        "function",
        "api",
        "sql",
    )
    _casual_pattern = re.compile(
        (
            r"^(hi|hey|hello|yo|thanks|thank you|ok|okay|cool|nice|lol|"
            r"good morning|good night)[!.\s]*$"
        ),
        re.IGNORECASE,
    )

    def __init__(self, config: Optional[RexThinkingRouterConfig] = None) -> None:
        self.config = config or RexThinkingRouterConfig()

    def route(self, brain_input: RexBrainInput) -> RexBrainDecision:
        message = brain_input.message.strip()
        normalized = _normalize(message)
        reasons: list[str] = []
        score = 0

        if brain_input.channel == RexBrainChannel.VOICE:
            reasons.append("voice_channel")

        if brain_input.user_requested_deep_thinking or self._contains_any(
            normalized,
            self._deep_phrases,
        ):
            score += 5
            reasons.append("user_requested_deep_thinking")

        if brain_input.has_file:
            score += 3
            reasons.append("file_attached")

        if brain_input.has_financial_context:
            score += 2
            reasons.append("financial_context_available")

        if brain_input.has_structured_memory:
            score += 1
            reasons.append("structured_memory_available")

        if brain_input.has_goals:
            score += 1
            reasons.append("goals_available")

        if brain_input.has_pending_commitments:
            score += 1
            reasons.append("pending_commitments_available")

        if self._contains_any(normalized, self._analytical_terms):
            score += 3
            reasons.append("analytical_language")

        if self._contains_any(normalized, self._strategic_terms):
            score += 3
            reasons.append("strategic_language")

        if self._contains_any(normalized, self._reflective_terms):
            score += 4
            reasons.append("reflection_requested")

        if self._contains_any(normalized, self._coaching_terms):
            score += 2
            reasons.append("coaching_language")

        if self._contains_any(normalized, self._memory_terms):
            score += 1
            reasons.append("memory_recall_language")

        if self._contains_any(normalized, self._safety_sensitive_terms):
            score += 2
            reasons.append("safety_sensitive_language")

        if self._contains_any(normalized, self._code_terms):
            score += 3
            reasons.append("code_or_debug_language")

        if self._looks_multi_step(normalized):
            score += 2
            reasons.append("multi_step_request")

        if len(message) > 500:
            score += 2
            reasons.append("long_message")

        if self._is_casual_fast_message(message, reasons):
            return self._decision(
                brain_input=brain_input,
                layer=RexThinkingLayer.FAST,
                complexity_score=0,
                reasons=("casual_message",),
            )

        layer = self._layer_for(normalized, score, reasons, brain_input)
        return self._decision(
            brain_input=brain_input,
            layer=layer,
            complexity_score=score,
            reasons=tuple(reasons or ["default_fast_route"]),
        )

    def _decision(
        self,
        brain_input: RexBrainInput,
        layer: RexThinkingLayer,
        complexity_score: int,
        reasons: tuple[str, ...],
    ) -> RexBrainDecision:
        model_profile = self._model_profile_for(brain_input, layer, complexity_score)
        context_budget = self._context_budget_for(brain_input, layer, complexity_score)
        output_mode = self._output_mode_for(layer)
        latency_class = self._latency_class_for(brain_input, model_profile, layer)
        expected_context_sources = self._expected_context_sources(brain_input, layer)
        return RexBrainDecision(
            layer=layer,
            model_profile=model_profile,
            complexity_score=complexity_score,
            context_budget=context_budget,
            output_mode=output_mode,
            latency_class=latency_class,
            cost_tier=self._cost_tier_for(model_profile, context_budget),
            reasons=reasons,
            escalation_source=self._escalation_source(reasons),
            expected_context_sources=expected_context_sources,
            needs_financial_context="financial" in expected_context_sources,
            needs_memory_context="memory" in expected_context_sources,
            needs_reflection=layer == RexThinkingLayer.REFLECTIVE
            or complexity_score >= self.config.deep_score_threshold + 2,
        )

    def _layer_for(
        self,
        normalized: str,
        score: int,
        reasons: list[str],
        brain_input: RexBrainInput,
    ) -> RexThinkingLayer:
        if "reflection_requested" in reasons:
            return RexThinkingLayer.REFLECTIVE
        if "safety_sensitive_language" in reasons:
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
        if "memory_recall_language" in reasons or self._looks_like_recall(normalized):
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

    def _model_profile_for(
        self,
        brain_input: RexBrainInput,
        layer: RexThinkingLayer,
        score: int,
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
            if brain_input.user_requested_deep_thinking or score >= threshold:
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

    def _context_budget_for(
        self,
        brain_input: RexBrainInput,
        layer: RexThinkingLayer,
        score: int,
    ) -> RexContextBudget:
        if layer == RexThinkingLayer.FAST:
            return RexContextBudget.TINY
        if brain_input.channel == RexBrainChannel.VOICE and score < 8:
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

    def _output_mode_for(self, layer: RexThinkingLayer) -> RexOutputMode:
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

    def _latency_class_for(
        self,
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

    def _cost_tier_for(
        self,
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

    def _expected_context_sources(
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
        if layer in {RexThinkingLayer.STRATEGIC, RexThinkingLayer.COACHING} and (
            brain_input.has_pending_commitments
        ):
            sources.append("pending_commitments")
        if brain_input.has_file:
            sources.append("attachments")
        return tuple(dict.fromkeys(sources))

    def _escalation_source(self, reasons: tuple[str, ...]) -> str:
        for reason in (
            "user_requested_deep_thinking",
            "reflection_requested",
            "strategic_language",
            "analytical_language",
            "code_or_debug_language",
            "safety_sensitive_language",
            "file_attached",
        ):
            if reason in reasons:
                return reason
        return "none"

    def _is_casual_fast_message(self, message: str, reasons: list[str]) -> bool:
        return bool(
            not reasons
            and len(message) <= self.config.max_fast_message_length
            and len(message.split()) <= 8
            and self._casual_pattern.match(message)
        )

    def _contains_any(self, normalized: str, terms: tuple[str, ...]) -> bool:
        for term in terms:
            if " " in term or "-" in term:
                if term in normalized:
                    return True
                continue
            if re.search(rf"\b{re.escape(term)}\b", normalized):
                return True
        return False

    def _looks_multi_step(self, normalized: str) -> bool:
        return bool(
            re.search(
                r"\b(first|second|third|then|after that|step by step)\b",
                normalized,
            )
            or normalized.count("?") >= 2
        )

    def _looks_like_recall(self, normalized: str) -> bool:
        return bool(re.search(r"\b(we|i) (decided|said|talked about)\b", normalized))


class RexBrain:
    def __init__(self, router: Optional[RexThinkingRouter] = None) -> None:
        self.router = router or RexThinkingRouter()

    def plan_turn(self, brain_input: RexBrainInput) -> RexBrainDecision:
        return self.router.route(brain_input)


def _normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())
