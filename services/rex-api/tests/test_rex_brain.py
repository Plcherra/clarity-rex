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
