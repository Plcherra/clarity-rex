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
    RexPendingActionContract,
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
    _scenario_simulation_terms = (
        "simulate",
        "simulation",
        "scenario",
        "what if",
        "if i",
        "if we",
        "payoff",
        "pay off",
        "debt payoff",
        "savings path",
        "spending tradeoff",
        "budget change",
        "cut spending",
        "reduce spending",
        "increase savings",
        "extra payment",
        "how long would it take",
        "projection",
    )
    _proactive_insight_terms = (
        "insight",
        "insights",
        "unusual spending",
        "budget drift",
        "drift",
        "upcoming commitment",
        "upcoming commitments",
        "goal risk",
        "goal risks",
        "risk to my goal",
        "financial blind spot",
        "financial blind spots",
        "red flag",
        "red flags",
        "warning signs",
        "what should i watch",
        "watch this month",
        "what needs attention",
        "surface",
        "flag",
    )
    _proactive_monitoring_terms = (
        "monitor",
        "keep an eye",
        "alert me",
        "notify me",
        "warn me",
        "proactive",
        "automatically",
        "background",
        "every day",
        "daily",
        "weekly",
    )
    _daily_focus_terms = (
        "what should i focus on today",
        "what should i focus on",
        "focus today",
        "today's focus",
        "todays focus",
        "daily focus",
        "what should i do today",
        "what matters today",
        "next best action",
        "where should i put my attention",
        "what should my priorities be",
        "today's priorities",
        "todays priorities",
        "personal operating system",
    )
    _planning_workspace_terms = (
        "planning workspace",
        "planning session",
        "structured plan",
        "build a plan",
        "make a plan",
        "create a plan",
        "draft a plan",
        "resume the plan",
        "resume my plan",
        "continue the plan",
        "continue my plan",
        "edit the plan",
        "update the plan",
        "revise the plan",
        "adjust the plan",
        "change the plan",
        "plan workspace",
        "milestone plan",
    )
    _planning_workspace_create_terms = (
        "build a plan",
        "make a plan",
        "create a plan",
        "draft a plan",
        "new plan",
        "planning session",
        "planning workspace",
    )
    _planning_workspace_resume_terms = (
        "resume the plan",
        "resume my plan",
        "continue the plan",
        "continue my plan",
        "pick up the plan",
        "go back to the plan",
    )
    _planning_workspace_edit_terms = (
        "edit the plan",
        "update the plan",
        "revise the plan",
        "adjust the plan",
        "change the plan",
        "modify the plan",
    )
    _long_term_review_terms = (
        "long term intelligence review",
        "long-term intelligence review",
        "review my long term context",
        "review my long-term context",
        "review my stored context",
        "review stale goals",
        "review outdated memories",
        "review duplicate commitments",
        "find financial blind spots",
        "financial blind spots",
        "stale goals",
        "outdated memories",
        "duplicate commitments",
        "memory cleanup",
        "clean up my memory",
        "cleanup memory",
        "clean up my goals",
        "cleanup goals",
        "clean up commitments",
        "cleanup commitments",
        "audit my memory",
        "audit my goals",
        "audit my commitments",
        "audit my finances",
        "review my goals",
        "review my commitments",
        "what needs cleanup",
    )
    _long_term_review_target_terms = {
        "goals": (
            "goal",
            "goals",
            "stale goals",
            "audit my goals",
            "review my goals",
            "cleanup goals",
        ),
        "memories": (
            "memory",
            "memories",
            "outdated memories",
            "audit my memory",
            "clean up my memory",
            "memory cleanup",
        ),
        "commitments": (
            "commitment",
            "commitments",
            "duplicate commitments",
            "audit my commitments",
            "review my commitments",
            "cleanup commitments",
        ),
        "financial_blind_spots": (
            "finance",
            "finances",
            "financial",
            "financial blind spot",
            "financial blind spots",
            "audit my finances",
        ),
    }
    _confirmed_action_terms = (
        "apply those changes",
        "apply these changes",
        "make those changes",
        "make these changes",
        "save those changes",
        "save these changes",
        "confirm those changes",
        "confirm these changes",
        "delete those",
        "delete these",
        "remove those",
        "remove these",
        "merge those",
        "merge these",
        "deactivate those",
        "deactivate these",
        "mark those",
        "mark these",
        "update those",
        "update these",
        "edit those",
        "edit these",
        "yes apply",
        "yes save",
        "yes delete",
        "yes remove",
        "yes merge",
        "go ahead and apply",
        "go ahead and save",
        "go ahead and delete",
        "go ahead and remove",
        "go ahead and merge",
    )
    _confirmed_action_intent_terms = {
        "delete": (
            "delete those",
            "delete these",
            "remove those",
            "remove these",
            "yes delete",
            "yes remove",
            "go ahead and delete",
            "go ahead and remove",
        ),
        "merge": (
            "merge those",
            "merge these",
            "yes merge",
            "go ahead and merge",
        ),
        "deactivate": (
            "deactivate those",
            "deactivate these",
            "archive those",
            "archive these",
        ),
        "update": (
            "update those",
            "update these",
            "edit those",
            "edit these",
            "make those changes",
            "make these changes",
            "apply those changes",
            "apply these changes",
            "yes apply",
            "go ahead and apply",
        ),
        "save": (
            "save those changes",
            "save these changes",
            "confirm those changes",
            "confirm these changes",
            "yes save",
            "go ahead and save",
        ),
        "complete": (
            "mark those",
            "mark these",
            "mark complete",
            "mark completed",
        ),
    }
    _confirmed_action_target_terms = {
        "memories": ("memory", "memories", "preference", "preferences"),
        "goals": ("goal", "goals"),
        "commitments": ("commitment", "commitments", "pending item", "pending items"),
        "budgets": ("budget", "budgets"),
        "categories": ("category", "categories"),
        "rules": ("rule", "rules", "merchant rule", "merchant rules"),
        "transactions": ("transaction", "transactions"),
        "plans": ("plan", "plans", "planning workspace"),
    }
    _allowed_response_style_profiles = {
        "default",
        "coach",
        "analyst",
        "concise",
        "direct",
        "supportive",
    }
    _response_style_terms = {
        "coach": (
            "coach mode",
            "coaching mode",
            "as my coach",
            "be my coach",
            "coach me",
        ),
        "analyst": (
            "analyst mode",
            "analysis mode",
            "as an analyst",
            "be analytical",
            "give me analyst",
        ),
        "concise": (
            "concise mode",
            "keep it concise",
            "be concise",
            "short answer",
            "brief answer",
            "quick answer",
        ),
        "direct": (
            "direct mode",
            "be direct",
            "tell me straight",
            "no sugarcoating",
            "straight answer",
        ),
        "supportive": (
            "supportive mode",
            "be supportive",
            "gentle tone",
            "encouraging tone",
            "soft tone",
        ),
    }
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
    _external_research_terms = (
        "latest",
        "current",
        "recent",
        "news",
        "online",
        "internet",
        "web",
        "real-time",
        "real time",
        "up to date",
        "up-to-date",
        "right now",
        "look up",
        "search",
        "browse",
        "research",
        "verify online",
        "check online",
        "market rate",
        "price now",
    )
    _research_opt_in_terms = (
        "search",
        "look up",
        "browse",
        "research online",
        "check the web",
        "check online",
        "use the web",
        "use internet",
        "verify online",
        "go online",
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
        response_style_profile, response_style_source = self._response_style_profile(
            normalized,
            brain_input.user_preference_profile,
        )
        if response_style_profile != "default":
            reasons.append("response_style_requested")
            reasons.append(f"response_style_{response_style_profile}")

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

        needs_scenario_simulation = self._contains_any(
            normalized,
            self._scenario_simulation_terms,
        )
        if needs_scenario_simulation:
            score += 3
            reasons.append("scenario_simulation_requested")

        needs_proactive_insight = self._contains_any(
            normalized,
            self._proactive_insight_terms,
        )
        proactive_monitoring_requested = self._contains_any(
            normalized,
            self._proactive_monitoring_terms,
        )
        if proactive_monitoring_requested:
            needs_proactive_insight = True
        requires_proactive_opt_in = (
            needs_proactive_insight
            and proactive_monitoring_requested
            and not brain_input.user_enabled_proactive_insights
        )
        if needs_proactive_insight:
            score += 3
            reasons.append("proactive_insight_requested")
            if proactive_monitoring_requested:
                reasons.append("proactive_monitoring_requested")
            if requires_proactive_opt_in:
                reasons.append("proactive_opt_in_required")

        needs_daily_focus = self._contains_any(normalized, self._daily_focus_terms)
        if needs_daily_focus:
            score += 4
            reasons.append("daily_focus_requested")

        needs_planning_workspace = self._contains_any(
            normalized,
            self._planning_workspace_terms,
        )
        planning_workspace_intent = "none"
        if needs_planning_workspace:
            planning_workspace_intent = self._planning_workspace_intent(normalized)
            score += 4
            reasons.append("planning_workspace_requested")
            reasons.append(f"planning_workspace_{planning_workspace_intent}")

        needs_long_term_review = self._contains_any(
            normalized,
            self._long_term_review_terms,
        )
        long_term_review_targets: tuple[str, ...] = ()
        if needs_long_term_review:
            long_term_review_targets = self._long_term_review_targets(normalized)
            score += 4
            reasons.append("long_term_review_requested")
            for target in long_term_review_targets:
                reasons.append(f"long_term_review_target_{target}")

        needs_confirmed_action_preview = self._contains_any(
            normalized,
            self._confirmed_action_terms,
        )
        confirmed_action_intent = "none"
        confirmed_action_targets: tuple[str, ...] = ()
        if needs_confirmed_action_preview:
            confirmed_action_intent = self._confirmed_action_intent(normalized)
            confirmed_action_targets = self._confirmed_action_targets(normalized)
            score += 4
            reasons.append("confirmed_action_preview_requested")
            reasons.append(f"confirmed_action_intent_{confirmed_action_intent}")
            for target in confirmed_action_targets:
                reasons.append(f"confirmed_action_target_{target}")

        if self._contains_any(normalized, self._reflective_terms):
            score += 4
            reasons.append("reflection_requested")

        if self._contains_any(normalized, self._coaching_terms):
            score += 2
            reasons.append("coaching_language")

        if self._contains_any(normalized, self._memory_terms):
            score += 1
            reasons.append("memory_recall_language")

        needs_external_research = self._contains_any(
            normalized,
            self._external_research_terms,
        )
        research_opted_in = (
            brain_input.user_opted_into_research
            or self._contains_any(normalized, self._research_opt_in_terms)
        )
        if needs_external_research:
            score += 2
            reasons.append("external_research_needed")
            if research_opted_in:
                reasons.append("research_opted_in")
            else:
                reasons.append("research_opt_in_required")

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
                response_style_profile=response_style_profile,
                response_style_source=response_style_source,
            )

        layer = self._layer_for(normalized, score, reasons, brain_input)
        needs_self_evaluation = self._needs_self_evaluation(
            layer=layer,
            score=score,
            reasons=reasons,
        )
        return self._decision(
            brain_input=brain_input,
            layer=layer,
            complexity_score=score,
            reasons=tuple(reasons or ["default_fast_route"]),
            needs_external_research=needs_external_research,
            requires_research_opt_in=(
                needs_external_research and not research_opted_in
            ),
            needs_scenario_simulation=needs_scenario_simulation,
            needs_proactive_insight=needs_proactive_insight,
            requires_proactive_opt_in=requires_proactive_opt_in,
            needs_daily_focus=needs_daily_focus,
            needs_planning_workspace=needs_planning_workspace,
            planning_workspace_intent=planning_workspace_intent,
            needs_self_evaluation=needs_self_evaluation,
            needs_long_term_review=needs_long_term_review,
            long_term_review_targets=long_term_review_targets,
            needs_confirmed_action_preview=needs_confirmed_action_preview,
            confirmed_action_intent=confirmed_action_intent,
            confirmed_action_targets=confirmed_action_targets,
            response_style_profile=response_style_profile,
            response_style_source=response_style_source,
        )

    def _decision(
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
        model_profile = self._model_profile_for(
            brain_input,
            layer,
            complexity_score,
            reasons,
        )
        context_budget = self._context_budget_for(
            brain_input,
            layer,
            complexity_score,
            reasons,
        )
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
            pending_action_contract=(
                RexPendingActionContract(
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
                if needs_confirmed_action_preview
                else RexPendingActionContract()
            ),
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
            if self._voice_intent_score(score, reasons) >= threshold:
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
        reasons: tuple[str, ...],
    ) -> RexContextBudget:
        if layer == RexThinkingLayer.FAST:
            return RexContextBudget.TINY
        if brain_input.channel == RexBrainChannel.VOICE:
            if brain_input.has_file:
                return RexContextBudget.MEDIUM
            if brain_input.user_requested_deep_thinking:
                return RexContextBudget.MEDIUM
            if self._voice_intent_score(score, reasons) >= (
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

    def _escalation_source(self, reasons: tuple[str, ...]) -> str:
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

    def _voice_intent_score(self, score: int, reasons: tuple[str, ...]) -> int:
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

    def _planning_workspace_intent(self, normalized: str) -> str:
        if self._contains_any(normalized, self._planning_workspace_resume_terms):
            return "resume"
        if self._contains_any(normalized, self._planning_workspace_edit_terms):
            return "edit"
        if self._contains_any(normalized, self._planning_workspace_create_terms):
            return "create"
        return "general"

    def _response_style_profile(
        self,
        normalized: str,
        user_preference_profile: str,
    ) -> tuple[str, str]:
        profile = (user_preference_profile or "default").strip().lower()
        if profile in self._allowed_response_style_profiles and profile != "default":
            return profile, "user_setting"

        for candidate, terms in self._response_style_terms.items():
            if self._contains_any(normalized, terms):
                return candidate, "explicit_message"

        return "default", "default"

    def _long_term_review_targets(self, normalized: str) -> tuple[str, ...]:
        targets = [
            target
            for target, terms in self._long_term_review_target_terms.items()
            if self._contains_any(normalized, terms)
        ]
        if not targets:
            targets = [
                "goals",
                "memories",
                "commitments",
                "financial_blind_spots",
            ]
        return tuple(dict.fromkeys(targets))

    def _confirmed_action_intent(self, normalized: str) -> str:
        for intent, terms in self._confirmed_action_intent_terms.items():
            if self._contains_any(normalized, terms):
                return intent
        return "general"

    def _confirmed_action_targets(self, normalized: str) -> tuple[str, ...]:
        targets = [
            target
            for target, terms in self._confirmed_action_target_terms.items()
            if self._contains_any(normalized, terms)
        ]
        return tuple(dict.fromkeys(targets or ["unspecified"]))

    def _needs_self_evaluation(
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


class RexBrain:
    def __init__(self, router: Optional[RexThinkingRouter] = None) -> None:
        self.router = router or RexThinkingRouter()

    def plan_turn(self, brain_input: RexBrainInput) -> RexBrainDecision:
        return self.router.route(brain_input)


def _normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())
