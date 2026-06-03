from app.services.rex_brain import RexBrainInput, RexThinkingRouter
from app.services.rex_brain_contracts import RexThinkingLayer


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
