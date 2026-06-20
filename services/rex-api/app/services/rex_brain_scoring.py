"""Experimental layered Rex Brain scoring.

NON-PRODUCTION FOR LAUNCH.

MVP production chat and voice use ChatService + SimpleRexBrain.
"""

from dataclasses import dataclass

from app.services.rex_brain_config import RexThinkingRouterConfig
from app.services.rex_brain_contracts import RexBrainChannel, RexBrainInput
from app.services.rex_brain_terms import (
    ALLOWED_RESPONSE_STYLE_PROFILES,
    ANALYTICAL_TERMS,
    CASUAL_PATTERN,
    CODE_TERMS,
    COACHING_TERMS,
    CONFIRMED_ACTION_INTENT_TERMS,
    CONFIRMED_ACTION_TARGET_TERMS,
    CONFIRMED_ACTION_TERMS,
    DAILY_FOCUS_TERMS,
    DEEP_PHRASES,
    EXTERNAL_RESEARCH_TERMS,
    LONG_TERM_REVIEW_TARGET_TERMS,
    LONG_TERM_REVIEW_TERMS,
    MEMORY_TERMS,
    PLANNING_WORKSPACE_CREATE_TERMS,
    PLANNING_WORKSPACE_EDIT_TERMS,
    PLANNING_WORKSPACE_RESUME_TERMS,
    PLANNING_WORKSPACE_TERMS,
    PROACTIVE_INSIGHT_TERMS,
    PROACTIVE_MONITORING_TERMS,
    REFLECTIVE_TERMS,
    RESEARCH_OPT_IN_TERMS,
    RESPONSE_STYLE_TERMS,
    SAFETY_SENSITIVE_TERMS,
    SCENARIO_SIMULATION_TERMS,
    STRATEGIC_TERMS,
    contains_any,
    looks_multi_step,
    normalize,
)


@dataclass(frozen=True)
class RexBrainRouteScore:
    message: str
    normalized: str
    score: int
    reasons: list[str]
    response_style_profile: str
    response_style_source: str
    needs_external_research: bool
    research_opted_in: bool
    needs_scenario_simulation: bool
    needs_proactive_insight: bool
    requires_proactive_opt_in: bool
    needs_daily_focus: bool
    needs_planning_workspace: bool
    planning_workspace_intent: str
    needs_long_term_review: bool
    long_term_review_targets: tuple[str, ...]
    needs_confirmed_action_preview: bool
    confirmed_action_intent: str
    confirmed_action_targets: tuple[str, ...]


class RexBrainScorer:
    def __init__(self, config: RexThinkingRouterConfig) -> None:
        self.config = config

    def score(self, brain_input: RexBrainInput) -> RexBrainRouteScore:
        message = brain_input.message.strip()
        normalized = normalize(message)
        reasons: list[str] = []
        score = 0
        response_style_profile, response_style_source = response_style_profile_for(
            normalized,
            brain_input.user_preference_profile,
        )
        if response_style_profile != "default":
            reasons.append("response_style_requested")
            reasons.append(f"response_style_{response_style_profile}")

        if brain_input.channel == RexBrainChannel.VOICE:
            reasons.append("voice_channel")

        if brain_input.user_requested_deep_thinking or contains_any(
            normalized,
            DEEP_PHRASES,
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

        if contains_any(normalized, ANALYTICAL_TERMS):
            score += 3
            reasons.append("analytical_language")

        if contains_any(normalized, STRATEGIC_TERMS):
            score += 3
            reasons.append("strategic_language")

        needs_scenario_simulation = contains_any(
            normalized,
            SCENARIO_SIMULATION_TERMS,
        )
        if needs_scenario_simulation:
            score += 3
            reasons.append("scenario_simulation_requested")

        needs_proactive_insight = contains_any(normalized, PROACTIVE_INSIGHT_TERMS)
        proactive_monitoring_requested = contains_any(
            normalized,
            PROACTIVE_MONITORING_TERMS,
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

        needs_daily_focus = contains_any(normalized, DAILY_FOCUS_TERMS)
        if needs_daily_focus:
            score += 4
            reasons.append("daily_focus_requested")

        needs_planning_workspace = contains_any(normalized, PLANNING_WORKSPACE_TERMS)
        planning_workspace_intent = "none"
        if needs_planning_workspace:
            planning_workspace_intent = planning_workspace_intent_for(normalized)
            score += 4
            reasons.append("planning_workspace_requested")
            reasons.append(f"planning_workspace_{planning_workspace_intent}")

        needs_long_term_review = contains_any(normalized, LONG_TERM_REVIEW_TERMS)
        long_term_review_targets: tuple[str, ...] = ()
        if needs_long_term_review:
            long_term_review_targets = long_term_review_targets_for(normalized)
            score += 4
            reasons.append("long_term_review_requested")
            for target in long_term_review_targets:
                reasons.append(f"long_term_review_target_{target}")

        needs_confirmed_action_preview = contains_any(
            normalized,
            CONFIRMED_ACTION_TERMS,
        )
        confirmed_action_intent = "none"
        confirmed_action_targets: tuple[str, ...] = ()
        if needs_confirmed_action_preview:
            confirmed_action_intent = confirmed_action_intent_for(normalized)
            confirmed_action_targets = confirmed_action_targets_for(normalized)
            score += 4
            reasons.append("confirmed_action_preview_requested")
            reasons.append(f"confirmed_action_intent_{confirmed_action_intent}")
            for target in confirmed_action_targets:
                reasons.append(f"confirmed_action_target_{target}")

        if contains_any(normalized, REFLECTIVE_TERMS):
            score += 4
            reasons.append("reflection_requested")

        if contains_any(normalized, COACHING_TERMS):
            score += 2
            reasons.append("coaching_language")

        if contains_any(normalized, MEMORY_TERMS):
            score += 1
            reasons.append("memory_recall_language")

        needs_external_research = contains_any(normalized, EXTERNAL_RESEARCH_TERMS)
        research_opted_in = brain_input.user_opted_into_research or contains_any(
            normalized,
            RESEARCH_OPT_IN_TERMS,
        )
        if needs_external_research:
            score += 2
            reasons.append("external_research_needed")
            if research_opted_in:
                reasons.append("research_opted_in")
            else:
                reasons.append("research_opt_in_required")

        if contains_any(normalized, SAFETY_SENSITIVE_TERMS):
            score += 2
            reasons.append("safety_sensitive_language")

        if contains_any(normalized, CODE_TERMS):
            score += 3
            reasons.append("code_or_debug_language")

        if looks_multi_step(normalized):
            score += 2
            reasons.append("multi_step_request")

        if len(message) > 500:
            score += 2
            reasons.append("long_message")

        return RexBrainRouteScore(
            message=message,
            normalized=normalized,
            score=score,
            reasons=reasons,
            response_style_profile=response_style_profile,
            response_style_source=response_style_source,
            needs_external_research=needs_external_research,
            research_opted_in=research_opted_in,
            needs_scenario_simulation=needs_scenario_simulation,
            needs_proactive_insight=needs_proactive_insight,
            requires_proactive_opt_in=requires_proactive_opt_in,
            needs_daily_focus=needs_daily_focus,
            needs_planning_workspace=needs_planning_workspace,
            planning_workspace_intent=planning_workspace_intent,
            needs_long_term_review=needs_long_term_review,
            long_term_review_targets=long_term_review_targets,
            needs_confirmed_action_preview=needs_confirmed_action_preview,
            confirmed_action_intent=confirmed_action_intent,
            confirmed_action_targets=confirmed_action_targets,
        )

    def is_casual_fast_message(self, message: str, reasons: list[str]) -> bool:
        return bool(
            not reasons
            and len(message) <= self.config.max_fast_message_length
            and len(message.split()) <= 8
            and CASUAL_PATTERN.match(message)
        )


def planning_workspace_intent_for(normalized: str) -> str:
    if contains_any(normalized, PLANNING_WORKSPACE_RESUME_TERMS):
        return "resume"
    if contains_any(normalized, PLANNING_WORKSPACE_EDIT_TERMS):
        return "edit"
    if contains_any(normalized, PLANNING_WORKSPACE_CREATE_TERMS):
        return "create"
    return "general"


def response_style_profile_for(
    normalized: str,
    user_preference_profile: str,
) -> tuple[str, str]:
    profile = (user_preference_profile or "default").strip().lower()
    if profile in ALLOWED_RESPONSE_STYLE_PROFILES and profile != "default":
        return profile, "user_setting"

    for candidate, terms in RESPONSE_STYLE_TERMS.items():
        if contains_any(normalized, terms):
            return candidate, "explicit_message"

    return "default", "default"


def long_term_review_targets_for(normalized: str) -> tuple[str, ...]:
    targets = [
        target
        for target, terms in LONG_TERM_REVIEW_TARGET_TERMS.items()
        if contains_any(normalized, terms)
    ]
    if not targets:
        targets = [
            "goals",
            "memories",
            "commitments",
            "financial_blind_spots",
        ]
    return tuple(dict.fromkeys(targets))


def confirmed_action_intent_for(normalized: str) -> str:
    for intent, terms in CONFIRMED_ACTION_INTENT_TERMS.items():
        if contains_any(normalized, terms):
            return intent
    return "general"


def confirmed_action_targets_for(normalized: str) -> tuple[str, ...]:
    targets = [
        target
        for target, terms in CONFIRMED_ACTION_TARGET_TERMS.items()
        if contains_any(normalized, terms)
    ]
    return tuple(dict.fromkeys(targets or ["unspecified"]))
