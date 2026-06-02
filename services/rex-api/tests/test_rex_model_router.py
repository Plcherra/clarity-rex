from app.config import Settings
from app.services.rex_brain import RexBrainInput, RexThinkingRouter
from app.services.rex_brain_contracts import (
    RexBrainChannel,
    RexContextBudget,
    RexCostTier,
    RexModelProfile,
)
from app.services.rex_model_router import PROFILE_LIMITS, RexModelRouter


def test_model_router_uses_fallback_model_when_routing_disabled():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="Analyze my spending", has_financial_context=True)
    )
    route = RexModelRouter(
        Settings(
            grok_api_key="key",
            grok_model="grok-default",
            grok_fast_model="grok-fast",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=False,
        )
    ).route_for_decision(decision)

    assert route.routing_enabled is False
    assert route.requested_profile == RexModelProfile.REASONING
    assert route.effective_profile == RexModelProfile.STANDARD
    assert route.selected_model == "grok-default"
    assert route.limits == PROFILE_LIMITS[RexModelProfile.STANDARD]
    assert route.reasons == ("rex_brain_routing_disabled",)
    assert route.rollout_stage == "disabled"


def test_model_router_maps_fast_standard_and_reasoning_profiles_when_enabled():
    settings = Settings(
        grok_api_key="key",
        grok_model="grok-default",
        grok_fast_model="grok-fast",
        grok_standard_model="grok-standard",
        grok_reasoning_model="grok-reasoning",
        rex_brain_routing_enabled=True,
        rex_brain_rollout_stage="deep_think_ui",
    )
    router = RexModelRouter(settings)

    fast_decision = RexThinkingRouter().route(RexBrainInput(message="hey"))
    standard_decision = RexThinkingRouter().route(
        RexBrainInput(
            message="What did we decide?",
            has_structured_memory=True,
        )
    )
    reasoning_decision = RexThinkingRouter().route(
        RexBrainInput(message="Analyze my spending", has_financial_context=True)
    )

    assert router.route_for_decision(fast_decision).selected_model == "grok-fast"
    assert (
        router.route_for_decision(standard_decision).selected_model == "grok-standard"
    )
    assert (
        router.route_for_decision(reasoning_decision).selected_model == "grok-reasoning"
    )


def test_model_router_falls_back_when_profile_model_is_missing():
    decision = RexThinkingRouter().route(RexBrainInput(message="hey"))

    route = RexModelRouter(
        Settings(
            grok_api_key="key",
            grok_model="grok-default",
            grok_fast_model=None,
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="deep_think_ui",
        )
    ).route_for_decision(decision)

    assert route.selected_model == "grok-default"
    assert route.effective_profile == RexModelProfile.FAST
    assert route.fallback_model == "grok-default"


def test_model_router_reports_missing_model_without_crashing():
    decision = RexThinkingRouter().route(RexBrainInput(message="hey"))

    route = RexModelRouter(
        Settings(
            grok_api_key="key",
            grok_model=None,
            grok_fast_model=None,
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="deep_think_ui",
        )
    ).route_for_decision(decision)

    assert route.selected_model is None
    assert "no_model_configured" in route.reasons


def test_model_router_escalates_explicit_deep_request_to_reasoning_profile():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Deep think about this",
            user_requested_deep_thinking=True,
        )
    )

    route = RexModelRouter(
        Settings(
            grok_api_key="key",
            grok_model="grok-default",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="deep_think_ui",
        )
    ).route_for_decision(decision)

    assert route.effective_profile == RexModelProfile.REASONING
    assert route.selected_model == "grok-reasoning"
    assert route.cost_tier == RexCostTier.HIGH


def test_model_router_metadata_is_safe_and_contains_cost_limits():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="Analyze this", has_financial_context=True)
    )

    route = RexModelRouter(
        Settings(
            grok_api_key="key",
            grok_model="grok-default",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="deep_think_ui",
        )
    ).route_for_decision(decision)

    metadata = route.metadata()

    assert metadata == {
        "routing_enabled": True,
        "rollout_stage": "deep_think_ui",
        "requested_profile": "reasoning",
        "effective_profile": "reasoning",
        "selected_model": "grok-reasoning",
        "fallback_model": "grok-default",
        "max_prompt_characters": PROFILE_LIMITS[
            RexModelProfile.REASONING
        ].max_prompt_characters,
        "max_output_tokens": PROFILE_LIMITS[
            RexModelProfile.REASONING
        ].max_output_tokens,
        "cost_tier": "high",
        "reasons": ["requested_profile:reasoning"],
    }
    assert "message" not in metadata
    assert "financial" not in metadata


def test_profile_limits_keep_reasoning_under_ai_service_prompt_ceiling():
    assert (
        PROFILE_LIMITS[RexModelProfile.FAST].max_prompt_characters
        < PROFILE_LIMITS[RexModelProfile.STANDARD].max_prompt_characters
    )
    assert (
        PROFILE_LIMITS[RexModelProfile.STANDARD].max_prompt_characters
        < PROFILE_LIMITS[RexModelProfile.REASONING].max_prompt_characters
    )
    assert PROFILE_LIMITS[RexModelProfile.REASONING].max_prompt_characters <= 30000
    assert (
        PROFILE_LIMITS[RexModelProfile.FAST].max_output_tokens
        < PROFILE_LIMITS[RexModelProfile.STANDARD].max_output_tokens
    )
    assert (
        PROFILE_LIMITS[RexModelProfile.STANDARD].max_output_tokens
        < PROFILE_LIMITS[RexModelProfile.REASONING].max_output_tokens
    )


def test_model_router_logging_only_stage_does_not_change_live_model_call():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="Analyze my spending", has_financial_context=True)
    )

    route = RexModelRouter(
        Settings(
            grok_model="grok-default",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="logging_only",
        )
    ).route_for_decision(decision)

    assert route.routing_enabled is False
    assert route.selected_model == "grok-default"
    assert route.reasons == ("rex_brain_rollout_logging_only",)


def test_model_router_fast_contextual_stage_blocks_analytical_routing():
    decision = RexThinkingRouter().route(
        RexBrainInput(message="Analyze my spending", has_financial_context=True)
    )

    route = RexModelRouter(
        Settings(
            grok_model="grok-default",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="fast_contextual",
        )
    ).route_for_decision(decision)

    assert route.routing_enabled is False
    assert route.selected_model == "grok-default"
    assert route.reasons == (
        "rex_brain_rollout_fast_contextual_blocked_layer_2_analytical",
    )


def test_model_router_analytical_stage_allows_analytical_but_blocks_advanced_layers():
    router = RexModelRouter(
        Settings(
            grok_model="grok-default",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="analytical",
        )
    )
    analytical = RexThinkingRouter().route(
        RexBrainInput(message="Analyze my spending", has_financial_context=True)
    )
    strategic = RexThinkingRouter().route(
        RexBrainInput(
            message="Make a plan for my savings goal next month",
            has_financial_context=True,
            has_goals=True,
        )
    )
    coaching = RexThinkingRouter().route(
        RexBrainInput(message="Coach me through this habit change")
    )

    assert router.route_for_decision(analytical).routing_enabled is True
    strategic_route = router.route_for_decision(strategic)
    assert strategic_route.routing_enabled is False
    assert strategic_route.reasons == (
        "rex_brain_rollout_analytical_blocked_layer_3_strategic",
    )
    coaching_route = router.route_for_decision(coaching)
    assert coaching_route.routing_enabled is False
    assert coaching_route.reasons == (
        "rex_brain_rollout_analytical_blocked_layer_5_coaching",
    )


def test_model_router_launch_safe_stage_allows_only_mvp_layers():
    router = RexModelRouter(
        Settings(
            grok_model="grok-default",
            grok_fast_model="grok-fast",
            grok_standard_model="grok-standard",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="launch_safe",
        )
    )
    thinking_router = RexThinkingRouter()

    fast = thinking_router.route(RexBrainInput(message="hey"))
    contextual = thinking_router.route(
        RexBrainInput(
            message="Do you remember what I told you?",
            has_structured_memory=True,
        )
    )
    analytical = thinking_router.route(
        RexBrainInput(message="Analyze my spending", has_financial_context=True)
    )
    strategic = thinking_router.route(
        RexBrainInput(
            message="Make a plan for my savings goal next month",
            has_financial_context=True,
            has_goals=True,
        )
    )
    reflective = thinking_router.route(
        RexBrainInput(
            message="Double check this plan and tell me what I am missing",
            has_structured_memory=True,
        )
    )
    coaching = thinking_router.route(
        RexBrainInput(message="Coach me through this habit change")
    )

    assert router.route_for_decision(fast).selected_model == "grok-fast"
    assert router.route_for_decision(contextual).selected_model == "grok-standard"
    assert router.route_for_decision(analytical).selected_model == "grok-reasoning"
    for decision in (strategic, reflective, coaching):
        route = router.route_for_decision(decision)
        assert route.routing_enabled is False
        assert route.selected_model == "grok-default"
        assert route.rollout_stage == "launch_safe"
        assert route.reasons == (
            f"rex_brain_rollout_launch_safe_blocked_{decision.layer.value}",
        )


def test_model_router_production_alias_uses_launch_safe_profile():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Make a strategy for my budget and goals",
            has_financial_context=True,
            has_goals=True,
        )
    )

    route = RexModelRouter(
        Settings(
            grok_model="grok-default",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="production",
        )
    ).route_for_decision(decision)

    assert route.routing_enabled is False
    assert route.rollout_stage == "launch_safe"


def test_model_router_launch_safe_blocks_deep_voice_routing_by_default():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Make a strategic plan for my financial goals",
            channel=RexBrainChannel.VOICE,
            has_financial_context=True,
            has_goals=True,
        )
    )

    route = RexModelRouter(
        Settings(
            grok_model="grok-default",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="mvp",
        )
    ).route_for_decision(decision)

    assert route.routing_enabled is False
    assert route.rollout_stage == "launch_safe"


def test_model_router_deep_think_ui_stage_allows_full_routing():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Deep think about my savings goal next month",
            has_financial_context=True,
            has_goals=True,
            user_requested_deep_thinking=True,
        )
    )

    route = RexModelRouter(
        Settings(
            grok_model="grok-default",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="deep_think_ui",
        )
    ).route_for_decision(decision)

    assert route.routing_enabled is True
    assert route.selected_model == "grok-reasoning"
    assert route.effective_profile == RexModelProfile.REASONING
