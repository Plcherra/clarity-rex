import pytest

from app.services.rex_brain import (
    RexBrain,
    RexBrainInput,
    RexThinkingRouter,
    RexThinkingRouterConfig,
)
from app.services.rex_brain_contracts import (
    RexBrainChannel,
    RexContextBudget,
    RexCostTier,
    RexLatencyClass,
    RexModelProfile,
    RexOutputMode,
    RexPendingActionContract,
    RexPendingActionStatus,
    RexThinkingLayer,
)


@pytest.mark.parametrize(
    ("brain_input", "expected_layer", "expected_profile", "expected_reason"),
    [
        (
            RexBrainInput(message="hey"),
            RexThinkingLayer.FAST,
            RexModelProfile.FAST,
            "casual_message",
        ),
        (
            RexBrainInput(message="thanks"),
            RexThinkingLayer.FAST,
            RexModelProfile.FAST,
            "casual_message",
        ),
        (
            RexBrainInput(message="Can you answer quickly?"),
            RexThinkingLayer.FAST,
            RexModelProfile.FAST,
            "default_fast_route",
        ),
        (
            RexBrainInput(
                message="What did we decide about dinner?",
                has_structured_memory=True,
                conversation_message_count=10,
            ),
            RexThinkingLayer.CONTEXTUAL,
            RexModelProfile.STANDARD,
            "memory_recall_language",
        ),
        (
            RexBrainInput(
                message="Remember what I said last time about Lara",
                has_structured_memory=True,
            ),
            RexThinkingLayer.CONTEXTUAL,
            RexModelProfile.STANDARD,
            "memory_recall_language",
        ),
        (
            RexBrainInput(
                message="Analyze my spending and compare it with my income",
                has_financial_context=True,
            ),
            RexThinkingLayer.ANALYTICAL,
            RexModelProfile.REASONING,
            "analytical_language",
        ),
        (
            RexBrainInput(
                message="Why is my cash flow negative?",
                has_financial_context=True,
            ),
            RexThinkingLayer.ANALYTICAL,
            RexModelProfile.REASONING,
            "analytical_language",
        ),
        (
            RexBrainInput(
                message="Calculate my subscriptions from these transactions",
                has_financial_context=True,
            ),
            RexThinkingLayer.ANALYTICAL,
            RexModelProfile.REASONING,
            "analytical_language",
        ),
        (
            RexBrainInput(
                message="Debug this API exception and SQL query",
                has_file=True,
            ),
            RexThinkingLayer.ANALYTICAL,
            RexModelProfile.REASONING,
            "code_or_debug_language",
        ),
        (
            RexBrainInput(message="Is this tax plan risky?"),
            RexThinkingLayer.ANALYTICAL,
            RexModelProfile.REASONING,
            "safety_sensitive_language",
        ),
        (
            RexBrainInput(
                message="Help me choose the next goal and trade-off for next month",
                has_financial_context=True,
                has_structured_memory=True,
                has_goals=True,
            ),
            RexThinkingLayer.STRATEGIC,
            RexModelProfile.REASONING,
            "strategic_language",
        ),
        (
            RexBrainInput(
                message="Build a roadmap for saving more next year",
                has_goals=True,
            ),
            RexThinkingLayer.STRATEGIC,
            RexModelProfile.REASONING,
            "strategic_language",
        ),
        (
            RexBrainInput(
                message="Deep think about my goals and pending commitments",
                has_goals=True,
                has_pending_commitments=True,
                user_requested_deep_thinking=True,
            ),
            RexThinkingLayer.STRATEGIC,
            RexModelProfile.REASONING,
            "user_requested_deep_thinking",
        ),
        (
            RexBrainInput(
                message="Double check this plan and tell me what I am missing",
                has_structured_memory=True,
            ),
            RexThinkingLayer.REFLECTIVE,
            RexModelProfile.REASONING,
            "reflection_requested",
        ),
        (
            RexBrainInput(message="Critique your answer for contradictions"),
            RexThinkingLayer.REFLECTIVE,
            RexModelProfile.REASONING,
            "reflection_requested",
        ),
        (
            RexBrainInput(message="Coach me through this habit change"),
            RexThinkingLayer.COACHING,
            RexModelProfile.STANDARD,
            "coaching_language",
        ),
        (
            RexBrainInput(
                message="I feel stuck and need accountability",
                has_structured_memory=True,
                has_pending_commitments=True,
            ),
            RexThinkingLayer.COACHING,
            RexModelProfile.STANDARD,
            "coaching_language",
        ),
        (
            RexBrainInput(
                message="What should I do first, second, and then after that?",
            ),
            RexThinkingLayer.CONTEXTUAL,
            RexModelProfile.STANDARD,
            "multi_step_request",
        ),
        (
            RexBrainInput(
                message="Summarize this file",
                has_file=True,
            ),
            RexThinkingLayer.CONTEXTUAL,
            RexModelProfile.STANDARD,
            "file_attached",
        ),
        (
            RexBrainInput(
                message="Compare this budget with my goals",
                has_financial_context=True,
                has_goals=True,
            ),
            RexThinkingLayer.STRATEGIC,
            RexModelProfile.REASONING,
            "strategic_language",
        ),
        (
            RexBrainInput(
                message="How much did I spend on food?",
                channel=RexBrainChannel.VOICE,
                has_financial_context=True,
            ),
            RexThinkingLayer.ANALYTICAL,
            RexModelProfile.STANDARD,
            "voice_channel",
        ),
        (
            RexBrainInput(
                message="Deep think and analyze my spending trend",
                channel=RexBrainChannel.VOICE,
                has_financial_context=True,
                user_requested_deep_thinking=True,
            ),
            RexThinkingLayer.ANALYTICAL,
            RexModelProfile.REASONING,
            "user_requested_deep_thinking",
        ),
        (
            RexBrainInput(
                message="Give me motivation to avoid impulse spending",
                channel=RexBrainChannel.VOICE,
                has_pending_commitments=True,
            ),
            RexThinkingLayer.COACHING,
            RexModelProfile.FAST,
            "voice_channel",
        ),
        (
            RexBrainInput(
                message="Before we continue, what did I say about Greece?",
                has_structured_memory=True,
            ),
            RexThinkingLayer.CONTEXTUAL,
            RexModelProfile.STANDARD,
            "memory_recall_language",
        ),
        (
            RexBrainInput(
                message="Plan my budget step by step and analyze risks",
                has_financial_context=True,
                has_structured_memory=True,
            ),
            RexThinkingLayer.STRATEGIC,
            RexModelProfile.REASONING,
            "strategic_language",
        ),
    ],
)
def test_router_examples_cover_phase_1_contracts(
    brain_input,
    expected_layer,
    expected_profile,
    expected_reason,
):
    decision = RexThinkingRouter().route(brain_input)

    assert decision.layer == expected_layer
    assert decision.model_profile == expected_profile
    assert expected_reason in decision.reasons


def test_router_keeps_simple_chat_on_fast_layer():
    decision = RexThinkingRouter().route(RexBrainInput(message="hey"))

    assert decision.layer == RexThinkingLayer.FAST
    assert decision.model_profile == RexModelProfile.FAST
    assert decision.complexity_score == 0
    assert decision.reasons == ("casual_message",)
    assert decision.context_budget == RexContextBudget.TINY
    assert decision.output_mode == RexOutputMode.CONCISE_TEXT
    assert decision.latency_class == RexLatencyClass.FAST
    assert decision.cost_tier == RexCostTier.LOW
    assert decision.needs_self_evaluation is False
    assert decision.self_evaluation_dimensions == ()
    assert decision.response_style_profile == "default"
    assert decision.response_style_source == "default"


def test_router_sends_financial_analysis_to_analytical_layer():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Analyze my spending and compare it with my income",
            has_financial_context=True,
        )
    )

    assert decision.layer == RexThinkingLayer.ANALYTICAL
    assert decision.model_profile == RexModelProfile.REASONING
    assert decision.context_budget == RexContextBudget.MEDIUM
    assert decision.output_mode == RexOutputMode.ANALYSIS
    assert decision.cost_tier == RexCostTier.HIGH
    assert decision.needs_financial_context is True
    assert "financial" in decision.expected_context_sources
    assert "financial_context_available" in decision.reasons
    assert "analytical_language" in decision.reasons
    assert decision.needs_self_evaluation is True
    assert decision.expose_self_evaluation is False
    assert decision.self_evaluation_dimensions == (
        "correctness",
        "usefulness",
        "missing_context",
        "tone_fit",
    )


def test_router_sends_goal_tradeoffs_to_strategic_layer():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Help me choose the next goal and trade-off for next month",
            has_financial_context=True,
            has_structured_memory=True,
            has_goals=True,
        )
    )

    assert decision.layer == RexThinkingLayer.STRATEGIC
    assert decision.model_profile == RexModelProfile.REASONING
    assert decision.context_budget == RexContextBudget.HIGH
    assert decision.output_mode == RexOutputMode.STRATEGIC_PLAN
    assert decision.needs_financial_context is True
    assert decision.needs_memory_context is True
    assert decision.expected_context_sources == ("financial", "memory", "goals")
    assert "strategic_language" in decision.reasons


def test_router_sends_self_check_requests_to_reflective_layer():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Double check this plan and tell me what I am missing",
            has_structured_memory=True,
        )
    )

    assert decision.layer == RexThinkingLayer.REFLECTIVE
    assert decision.model_profile == RexModelProfile.REASONING
    assert decision.output_mode == RexOutputMode.REFLECTIVE_CHECK
    assert decision.needs_reflection is True


def test_router_uses_contextual_layer_for_memory_heavy_normal_chat():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="What did we decide about dinner?",
            has_structured_memory=True,
            conversation_message_count=10,
        )
    )

    assert decision.layer == RexThinkingLayer.CONTEXTUAL
    assert decision.model_profile == RexModelProfile.STANDARD
    assert decision.context_budget == RexContextBudget.SMALL
    assert decision.needs_memory_context is True
    assert decision.expected_context_sources == ("memory",)


def test_voice_turns_default_to_realtime_latency_without_deep_escalation():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="How much did I spend on restaurants?",
            channel=RexBrainChannel.VOICE,
            has_financial_context=True,
        )
    )

    assert decision.layer == RexThinkingLayer.ANALYTICAL
    assert decision.model_profile == RexModelProfile.STANDARD
    assert decision.context_budget == RexContextBudget.SMALL
    assert decision.latency_class == RexLatencyClass.REALTIME
    assert decision.cost_tier == RexCostTier.MEDIUM


def test_voice_full_context_does_not_escalate_from_context_availability_alone():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Analyze my spending today",
            channel=RexBrainChannel.VOICE,
            has_financial_context=True,
            has_structured_memory=True,
            has_goals=True,
            has_pending_commitments=True,
        )
    )

    assert decision.layer == RexThinkingLayer.ANALYTICAL
    assert decision.complexity_score >= 8
    assert decision.model_profile == RexModelProfile.STANDARD
    assert decision.context_budget == RexContextBudget.SMALL
    assert decision.latency_class == RexLatencyClass.REALTIME
    assert decision.cost_tier == RexCostTier.MEDIUM
    assert "financial_context_available" in decision.reasons
    assert "structured_memory_available" in decision.reasons
    assert "goals_available" in decision.reasons
    assert "pending_commitments_available" in decision.reasons


def test_voice_explicit_deep_thinking_can_use_reasoning_but_not_deep_latency():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Deep think about my budget and analyze thoroughly",
            channel=RexBrainChannel.VOICE,
            has_financial_context=True,
            user_requested_deep_thinking=True,
        )
    )

    assert decision.layer == RexThinkingLayer.ANALYTICAL
    assert decision.model_profile == RexModelProfile.REASONING
    assert decision.latency_class == RexLatencyClass.STANDARD
    assert decision.escalation_source == "user_requested_deep_thinking"


def test_voice_high_intent_complexity_can_still_escalate_without_context_score():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message=(
                "Analyze thoroughly, compare, verify, and reason through my "
                "tax and bankruptcy budget risks step by step"
            ),
            channel=RexBrainChannel.VOICE,
        )
    )

    assert decision.model_profile == RexModelProfile.REASONING
    assert decision.context_budget == RexContextBudget.MEDIUM
    assert decision.latency_class == RexLatencyClass.STANDARD


def test_current_external_questions_require_research_opt_in_before_live_facts():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="What is the latest mortgage rate today?")
    )

    assert decision.layer == RexThinkingLayer.CONTEXTUAL
    assert decision.needs_external_research is True
    assert decision.requires_research_opt_in is True
    assert "external_research_needed" in decision.reasons
    assert "research_opt_in_required" in decision.reasons
    assert "research_opted_in" not in decision.reasons
    assert decision.escalation_source == "external_research_needed"


def test_explicit_research_language_records_opt_in_without_enabling_web_adapter():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="Search the web for the latest mortgage rate today")
    )

    assert decision.needs_external_research is True
    assert decision.requires_research_opt_in is False
    assert "external_research_needed" in decision.reasons
    assert "research_opted_in" in decision.reasons


def test_budget_scenario_simulations_route_to_strategic_with_assumption_flag():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Simulate what happens if I cut spending by $200 next month",
            has_financial_context=True,
            has_goals=True,
        )
    )

    assert decision.layer == RexThinkingLayer.STRATEGIC
    assert decision.needs_scenario_simulation is True
    assert "scenario_simulation_requested" in decision.reasons
    assert decision.escalation_source == "strategic_language"
    assert decision.needs_financial_context is True


def test_debt_payoff_scenario_uses_analytical_layer_without_goals():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="What if I make an extra payment toward debt each month?",
            has_financial_context=True,
        )
    )

    assert decision.layer == RexThinkingLayer.ANALYTICAL
    assert decision.needs_scenario_simulation is True
    assert "scenario_simulation_requested" in decision.reasons


def test_requested_proactive_insights_route_to_strategic_when_goals_exist():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="What should I watch this month for unusual spending and goal risks?",
            has_financial_context=True,
            has_goals=True,
        )
    )

    assert decision.layer == RexThinkingLayer.STRATEGIC
    assert decision.needs_proactive_insight is True
    assert decision.requires_proactive_opt_in is False
    assert "proactive_insight_requested" in decision.reasons
    assert decision.escalation_source == "proactive_insight_requested"
    assert decision.needs_financial_context is True


def test_background_proactive_monitoring_requires_user_opt_in():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Alert me when budget drift gets risky",
            has_financial_context=True,
        )
    )

    assert decision.layer == RexThinkingLayer.CONTEXTUAL
    assert decision.needs_proactive_insight is True
    assert decision.requires_proactive_opt_in is True
    assert "proactive_monitoring_requested" in decision.reasons
    assert "proactive_opt_in_required" in decision.reasons


def test_enabled_proactive_monitoring_routes_to_analysis_without_opt_in_gate():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Alert me when budget drift gets risky",
            has_financial_context=True,
            user_enabled_proactive_insights=True,
        )
    )

    assert decision.layer == RexThinkingLayer.ANALYTICAL
    assert decision.needs_proactive_insight is True
    assert decision.requires_proactive_opt_in is False
    assert "proactive_monitoring_requested" in decision.reasons
    assert "proactive_opt_in_required" not in decision.reasons


def test_daily_focus_request_routes_to_strategic_personal_operating_system():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="What should I focus on today?",
            has_financial_context=True,
            has_structured_memory=True,
            has_goals=True,
            has_pending_commitments=True,
        )
    )

    assert decision.layer == RexThinkingLayer.STRATEGIC
    assert decision.needs_daily_focus is True
    assert decision.needs_external_research is False
    assert decision.requires_research_opt_in is False
    assert decision.expected_context_sources == (
        "financial",
        "memory",
        "goals",
        "pending_commitments",
    )
    assert decision.escalation_source == "daily_focus_requested"
    assert "daily_focus_requested" in decision.reasons


def test_daily_focus_still_routes_without_optional_context():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="What should my priorities be today?")
    )

    assert decision.layer == RexThinkingLayer.STRATEGIC
    assert decision.needs_daily_focus is True
    assert decision.expected_context_sources == ()


def test_planning_workspace_create_routes_to_strategic_with_resumable_intent():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Start a planning session and build a plan for my savings goal",
            has_financial_context=True,
            has_structured_memory=True,
            has_goals=True,
            has_pending_commitments=True,
        )
    )

    assert decision.layer == RexThinkingLayer.STRATEGIC
    assert decision.needs_planning_workspace is True
    assert decision.planning_workspace_intent == "create"
    assert decision.expected_context_sources == (
        "financial",
        "memory",
        "goals",
        "pending_commitments",
    )
    assert decision.escalation_source == "planning_workspace_requested"
    assert "planning_workspace_requested" in decision.reasons
    assert "planning_workspace_create" in decision.reasons


def test_planning_workspace_resume_and_edit_intents_are_tracked():
    resume = RexThinkingRouter().route(
        RexBrainInput(message="Resume my plan from last time")
    )
    edit = RexThinkingRouter().route(
        RexBrainInput(message="Revise the plan and adjust the milestones")
    )

    assert resume.layer == RexThinkingLayer.STRATEGIC
    assert resume.needs_planning_workspace is True
    assert resume.planning_workspace_intent == "resume"
    assert "planning_workspace_resume" in resume.reasons
    assert edit.layer == RexThinkingLayer.STRATEGIC
    assert edit.needs_planning_workspace is True
    assert edit.planning_workspace_intent == "edit"
    assert "planning_workspace_edit" in edit.reasons


def test_self_evaluation_can_be_exposed_only_when_debug_enabled():
    debug_decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Analyze my spending trend",
            has_financial_context=True,
            rex_brain_debug_enabled=True,
        )
    )
    normal_decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Analyze my spending trend",
            has_financial_context=True,
        )
    )

    assert debug_decision.needs_self_evaluation is True
    assert debug_decision.expose_self_evaluation is True
    assert normal_decision.needs_self_evaluation is True
    assert normal_decision.expose_self_evaluation is False


def test_response_style_profile_can_come_from_explicit_message():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="Be concise and analyze my spending trend")
    )

    assert decision.response_style_profile == "concise"
    assert decision.response_style_source == "explicit_message"
    assert "response_style_requested" in decision.reasons
    assert "response_style_concise" in decision.reasons
    assert decision.layer == RexThinkingLayer.ANALYTICAL


def test_response_style_profile_can_come_from_user_setting():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Analyze my spending trend",
            user_preference_profile="direct",
        )
    )

    assert decision.response_style_profile == "direct"
    assert decision.response_style_source == "user_setting"
    assert "response_style_direct" in decision.reasons


def test_invalid_response_style_profile_falls_back_to_default():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Analyze my spending trend",
            user_preference_profile="pirate",
        )
    )

    assert decision.response_style_profile == "default"
    assert decision.response_style_source == "default"
    assert "response_style_requested" not in decision.reasons


def test_long_term_intelligence_review_routes_to_reflective_layer():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message=(
                "Review my stale goals, outdated memories, duplicate "
                "commitments, and financial blind spots"
            ),
            has_financial_context=True,
            has_structured_memory=True,
            has_goals=True,
            has_pending_commitments=True,
        )
    )

    assert decision.layer == RexThinkingLayer.REFLECTIVE
    assert decision.model_profile == RexModelProfile.REASONING
    assert decision.needs_long_term_review is True
    assert decision.long_term_review_targets == (
        "goals",
        "memories",
        "commitments",
        "financial_blind_spots",
    )
    assert decision.requires_long_term_review_confirmation is True
    assert decision.needs_self_evaluation is True
    assert decision.expected_context_sources == (
        "memory",
        "goals",
        "financial",
        "pending_commitments",
    )
    assert "long_term_review_requested" in decision.reasons
    assert "long_term_review_target_memories" in decision.reasons


def test_generic_long_term_review_defaults_to_all_review_targets():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="What needs cleanup in my stored context?")
    )

    assert decision.needs_long_term_review is True
    assert decision.long_term_review_targets == (
        "goals",
        "memories",
        "commitments",
        "financial_blind_spots",
    )


def test_confirmed_action_preview_routes_to_reflective_layer():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Go ahead and merge these duplicate commitments",
            has_structured_memory=True,
            has_pending_commitments=True,
        )
    )

    assert decision.layer == RexThinkingLayer.REFLECTIVE
    assert decision.needs_confirmed_action_preview is True
    assert decision.confirmed_action_intent == "merge"
    assert decision.confirmed_action_targets == ("commitments",)
    assert decision.requires_action_confirmation is True
    assert decision.pending_action_contract.status == RexPendingActionStatus.PREVIEW_ONLY
    assert decision.pending_action_contract.action_intent == "merge"
    assert decision.pending_action_contract.target_type == "commitments"
    assert decision.pending_action_contract.is_preview_only is True
    assert decision.pending_action_contract.is_executable is False
    assert decision.needs_self_evaluation is True
    assert decision.expected_context_sources == ("memory", "pending_commitments")
    assert "confirmed_action_preview_requested" in decision.reasons
    assert "confirmed_action_intent_merge" in decision.reasons
    assert "confirmed_action_target_commitments" in decision.reasons


def test_confirmed_action_preview_keeps_unspecified_targets_explicit():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="Yes apply those changes")
    )

    assert decision.needs_confirmed_action_preview is True
    assert decision.confirmed_action_intent == "update"
    assert decision.confirmed_action_targets == ("unspecified",)
    assert decision.requires_action_confirmation is True


def test_pending_action_contract_requires_id_targets_diff_and_confirmation():
    preview = RexPendingActionContract(
        action_intent="delete",
        target_type="memories",
    )
    executable = RexPendingActionContract(
        pending_action_id="pending-1",
        action_intent="delete",
        target_type="memories",
        target_ids=("memory-1",),
        proposed_diff=({"op": "delete", "id": "memory-1"},),
        requires_confirmation=True,
        confirmed_at="2026-05-28T12:00:00Z",
        status=RexPendingActionStatus.CONFIRMED,
    )

    assert preview.is_preview_only is True
    assert preview.is_executable is False
    assert preview.metadata()["proposed_diff_count"] == 0
    assert executable.is_preview_only is False
    assert executable.is_executable is True
    assert executable.metadata()["target_ids"] == ["memory-1"]
    assert executable.metadata()["proposed_diff_count"] == 1


def test_missing_optional_context_never_crashes_routing():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="What did we decide about my budget plan?",
            has_financial_context=False,
            has_structured_memory=False,
        )
    )

    assert decision.layer in {
        RexThinkingLayer.CONTEXTUAL,
        RexThinkingLayer.STRATEGIC,
    }
    assert decision.metadata()["expected_context_sources"] == []


def test_route_metadata_is_serializable_and_safe_for_logs():
    decision = RexBrain().plan_turn(
        RexBrainInput(
            message="Plan my budget step by step and analyze risks",
            has_financial_context=True,
            has_structured_memory=True,
            has_goals=True,
        )
    )

    assert decision.metadata() == {
        "layer": "layer_3_strategic",
        "model_profile": "reasoning",
        "complexity_score": decision.complexity_score,
        "context_budget": decision.context_budget.value,
        "output_mode": "strategic_plan",
        "latency_class": "deep",
        "cost_tier": "high",
        "reasons": list(decision.reasons),
        "escalation_source": "strategic_language",
        "expected_context_sources": ["financial", "memory", "goals"],
        "needs_financial_context": True,
        "needs_memory_context": True,
        "needs_reflection": decision.needs_reflection,
        "needs_external_research": False,
        "requires_research_opt_in": False,
        "needs_scenario_simulation": False,
        "needs_proactive_insight": False,
        "requires_proactive_opt_in": False,
        "needs_daily_focus": False,
        "needs_planning_workspace": False,
        "planning_workspace_intent": "none",
        "needs_self_evaluation": True,
        "expose_self_evaluation": False,
        "self_evaluation_dimensions": [
            "correctness",
            "usefulness",
            "missing_context",
            "tone_fit",
        ],
        "response_style_profile": "default",
        "response_style_source": "default",
        "needs_long_term_review": False,
        "long_term_review_targets": [],
        "requires_long_term_review_confirmation": False,
        "needs_confirmed_action_preview": False,
        "confirmed_action_intent": "none",
        "confirmed_action_targets": [],
        "requires_action_confirmation": False,
        "pending_action_contract": {
            "pending_action_id": None,
            "action_intent": "none",
            "target_type": "unspecified",
            "target_ids": [],
            "proposed_diff_count": 0,
            "requires_confirmation": True,
            "confirmed_at": None,
            "executed_at": None,
            "execution_result": None,
            "status": "preview_only",
            "is_preview_only": True,
            "is_executable": False,
        },
    }
    assert "budget" not in decision.metadata()
    assert "transaction" not in decision.metadata()


def test_router_config_can_override_fast_message_threshold():
    router = RexThinkingRouter(
        RexThinkingRouterConfig(max_fast_words=3, max_fast_message_length=20)
    )

    decision = router.route(RexBrainInput(message="Can you answer quickly?"))

    assert decision.layer == RexThinkingLayer.CONTEXTUAL
    assert decision.context_budget == RexContextBudget.SMALL


def test_explicit_chat_deep_think_uses_reasoning_profile_for_short_prompt():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="hey Rex", user_requested_deep_thinking=True)
    )

    assert decision.model_profile == RexModelProfile.REASONING
    assert decision.escalation_source == "user_requested_deep_thinking"
    assert "user_requested_deep_thinking" in decision.reasons
