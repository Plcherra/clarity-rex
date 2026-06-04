import pytest

from chat_service_fakes import (
    FailingRexBrain,
    FakeAIService,
    FakeMemoryService,
    FakeRexBrainObserver,
)
from app.config import Settings
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_model_router import RexModelRouter


def _routed_chat_service(
    ai_service,
    memory_service,
    *,
    rex_brain=None,
    **settings_overrides,
):
    settings = Settings(
        grok_api_key="key",
        grok_model="grok-default",
        rex_brain_routing_enabled=True,
        rex_brain_rollout_stage="deep_think_ui",
        **settings_overrides,
    )
    return ChatService(
        ai_service,
        FileService(),
        memory_service,
        rex_brain=rex_brain,
        rex_model_router=RexModelRouter(settings),
    )


@pytest.mark.asyncio
async def test_rex_brain_routing_disabled_keeps_chat_ai_call_unchanged():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    await chat_service.send_message("hey Rex")

    assert ai_service.kwargs == {}
    assert "Rex Brain routing contract" not in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_rex_brain_planning_failure_falls_back_to_base_chat_path():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        rex_brain=FailingRexBrain(),
    )

    result = await chat_service.send_message("hey Rex")

    assert result["response"] == "Rex response"
    assert ai_service.kwargs == {}
    assert "Rex Brain routing contract" not in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_rex_brain_chat_routing_adds_layer_prompt_and_model_limits_when_enabled():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
    )

    await chat_service.send_message(
        "Analyze my spending and compare it to my budget",
        financial_context={
            "cash_flow": {"income": 4000, "spending": 3100},
            "transactions": [
                {"merchant": "Private merchant", "amount": 42, "secret": "remove"}
            ],
        },
    )

    assert ai_service.kwargs["model_override"] == "grok-reasoning"
    assert ai_service.kwargs["max_tokens"] == 3000
    assert ai_service.kwargs["max_prompt_characters"] == 28000
    system_prompt = ai_service.messages[0]["content"]
    assert "Rex Brain routing contract" in system_prompt
    assert "Layer 2 Analytical" in system_prompt
    assert "Self-check internally" in system_prompt
    assert "Keep it hidden unless debug exposure is enabled" in system_prompt
    assert "Private merchant" not in system_prompt
    assert "remove" not in system_prompt
    rex_brain_section = system_prompt.split("Rex Brain routing contract", 1)[1]
    assert "Private merchant" not in rex_brain_section
    assert "secret" not in rex_brain_section


@pytest.mark.asyncio
async def test_rex_brain_streaming_chat_uses_same_route_for_model_limits():
    ai_service = FakeAIService(stream_tokens=["A", "B"])
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_fast_model="grok-fast",
    )

    events = [event async for event in chat_service.stream_message("hey")]

    assert ai_service.kwargs["model_override"] == "grok-fast"
    assert ai_service.kwargs["max_tokens"] == 700
    assert ai_service.kwargs["max_prompt_characters"] == 6000
    assert any(
        event.get("event") == "done" and event.get("response") == "AB"
        for event in events
    )


@pytest.mark.asyncio
async def test_rex_brain_chat_deep_think_flag_escalates_casual_message_when_enabled():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
    )

    await chat_service.send_message(
        "hey Rex",
        user_requested_deep_thinking=True,
    )

    assert ai_service.kwargs["model_override"] == "grok-reasoning"
    system_prompt = ai_service.messages[0]["content"]
    assert "Rex Brain routing contract" in system_prompt
    assert "Layer 1 Contextual Recall" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_chat_requires_opt_in_for_current_external_research():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
    )

    await chat_service.send_message("What is the latest mortgage rate today?")

    system_prompt = ai_service.messages[0]["content"]
    assert "Research guard" in system_prompt
    assert (
        "ask before claiming live/current external facts"
        in system_prompt
    )


@pytest.mark.asyncio
async def test_rex_brain_chat_marks_scenario_simulations_with_assumption_contract():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
    )

    await chat_service.send_message(
        "Simulate what happens if I cut spending by $200 next month",
        financial_context={"cash_flow": {"income": 3000, "spending": 2200}},
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "Simulation guard" in system_prompt
    assert "state assumptions" in system_prompt
    assert "avoid guaranteed outcomes" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_chat_marks_proactive_insights_as_user_controlled():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
    )

    await chat_service.send_message(
        "What should I watch this month for unusual spending and goal risks?",
        financial_context={"cash_flow": {"income": 3000, "spending": 2200}},
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "Proactive guard" in system_prompt
    assert "do not imply monitoring" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_chat_requires_opt_in_for_background_proactive_monitoring():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
    )

    await chat_service.send_message(
        "Alert me when budget drift gets risky",
        financial_context={"cash_flow": {"income": 3000, "spending": 2200}},
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "Proactive guard" in system_prompt
    assert "Ask opt-in before promising alerts" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_chat_marks_daily_focus_personal_operating_system_turns():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    memory_service.structured_context = {
        "plans": [{"title": "Stabilize cash flow"}],
        "commitments": [{"title": "Review budget"}],
    }
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
    )

    await chat_service.send_message(
        "What should I focus on today?",
        financial_context={"cash_flow": {"income": 3000, "spending": 2200}},
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "Daily focus" in system_prompt
    assert "give 1-3 priorities" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_chat_marks_planning_workspace_turns_as_resumable():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    memory_service.structured_context = {
        "plans": [{"title": "Save emergency fund"}],
        "commitments": [{"title": "Review budget weekly"}],
    }
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
    )

    await chat_service.send_message(
        "Start a planning session and build a plan for my savings goal",
        financial_context={"cash_flow": {"income": 3000, "spending": 2200}},
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "Planning: intent=create" in system_prompt
    assert "objective, constraints, milestones" in system_prompt
    assert "Do not claim saved without execution metadata" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_chat_can_expose_self_evaluation_when_debug_enabled():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
        rex_brain_debug_enabled=True,
    )

    await chat_service.send_message(
        "Analyze my spending and compare it to income",
        financial_context={"cash_flow": {"income": 3000, "spending": 2200}},
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "Self-check internally" in system_prompt
    assert "Debug exposure enabled" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_chat_adds_response_style_contract_for_explicit_profile():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
    )

    await chat_service.send_message(
        "Be direct and analyze my spending trend",
        financial_context={"cash_flow": {"income": 3000, "spending": 2200}},
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "Style: direct from explicit_message" in system_prompt
    assert "Honor it for this turn only" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_chat_adds_long_term_review_contract():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
    )

    await chat_service.send_message(
        "Review outdated memories and duplicate commitments",
        financial_context={"cash_flow": {"income": 3000, "spending": 2200}},
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "Long-term review: targets=memories, commitments" in system_prompt
    assert "Review only provided context" in system_prompt
    assert "ask before destructive edits" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_chat_adds_confirmed_action_preview_contract():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = _routed_chat_service(
        ai_service,
        memory_service,
        grok_reasoning_model="grok-reasoning",
    )

    await chat_service.send_message("Go ahead and delete those memories")

    system_prompt = ai_service.messages[0]["content"]
    assert "Action preview: intent=delete; targets=memories" in system_prompt
    assert "Summarize exact changes" in system_prompt
    assert "never claim a mutation without execution metadata" in system_prompt


@pytest.mark.asyncio
async def test_rex_brain_observer_receives_planned_and_completed_events():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    observer = FakeRexBrainObserver()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        rex_brain_observer=observer,
    )

    await chat_service.send_message("Analyze my spending")

    assert [call["status"] for call in observer.calls] == ["planned", "completed"]
    assert all(call["channel"].value == "chat" for call in observer.calls)
    assert all("Analyze my spending" not in str(call) for call in observer.calls)
    assert observer.calls[0]["request_id"].startswith("rexbrain-conversation-1-")
