from app.services.rex_brain import (
    RexBrain,
    RexBrainInput,
    RexThinkingRouter,
    RexThinkingRouterConfig,
)
from app.services.rex_brain_contracts import (
    RexContextBudget,
    RexModelProfile,
    RexPendingActionContract,
    RexPendingActionStatus,
    RexThinkingLayer,
)


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
