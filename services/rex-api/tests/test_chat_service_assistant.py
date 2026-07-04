import pytest

from chat_service_fakes import FakeAIService, FakeMemoryService
from app.services.chat_service import ChatService
from app.services.file_service import FileService


@pytest.mark.asyncio
async def test_simple_rex_brain_keeps_chat_ai_call_unchanged():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    await chat_service.send_message("hey Rex")

    assert ai_service.kwargs == {}
    assert "routing contract" not in ai_service.messages[0]["content"].lower()


@pytest.mark.asyncio
async def test_attached_financial_context_is_ignored_for_casual_chat():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    await chat_service.send_message(
        "Hey Rex",
        financial_context={
            "schema": "clarity_unified_financial_context_v1",
            "cash_flow": {"spent_this_month": 100},
        },
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "Clarity financial summary" not in system_prompt
    assert "spent_this_month" not in system_prompt


@pytest.mark.asyncio
async def test_attached_financial_context_is_ignored_for_streaming_recall():
    ai_service = FakeAIService(stream_tokens=["Rex response"])
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    events = [
        event
        async for event in chat_service.stream_message(
            "Search old chats about Legacy of Kain",
            financial_context={
                "schema": "clarity_unified_financial_context_v1",
                "cash_flow": {"spent_this_month": 100},
            },
        )
    ]

    system_prompt = ai_service.messages[0]["content"]
    assert "Clarity financial summary" not in system_prompt
    assert "spent_this_month" not in system_prompt
    assert any(event.get("event") == "done" for event in events)


@pytest.mark.asyncio
async def test_financial_context_included_for_spending_analysis():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    await chat_service.send_message(
        "Analyze my spending and compare it to my budget",
        financial_context={
            "data_status": {
                "state": "ready",
                "financial_context_complete": True,
                "load_errors": [],
            },
            "integration": {"full_financial_context_included": True},
            "cash_flow": {"income": 4000, "spending": 3100},
            "transactions": [{"merchant": "Coffee", "amount": 42}],
        },
    )

    assert ai_service.kwargs == {}
    system_prompt = ai_service.messages[0]["content"]
    assert "Clarity financial summary" in system_prompt
    assert "routing contract" not in system_prompt.lower()
    assert "Layer 2 Analytical" not in system_prompt
    assert "model_override" not in ai_service.kwargs


@pytest.mark.asyncio
async def test_streaming_chat_uses_mvp_kwargs_only():
    ai_service = FakeAIService(stream_tokens=["A", "B"])
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    events = [
        event
        async for event in chat_service.stream_message("hey", max_response_tokens=123)
    ]

    assert ai_service.kwargs.get("max_tokens") == 123
    assert "usage_holder" in ai_service.kwargs
    assert "routing contract" not in ai_service.messages[0]["content"].lower()
    assert any(
        event.get("event") == "done" and event.get("response") == "AB"
        for event in events
    )


@pytest.mark.asyncio
async def test_base_prompt_contains_launch_safety_guards():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    await chat_service.send_message(
        "Simulate my budget and alert me when anything changes",
        financial_context={
            "schema": "clarity_unified_financial_context_v1",
            "data_status": {
                "state": "ready",
                "financial_context_complete": True,
                "load_errors": [],
            },
            "integration": {"full_financial_context_included": True},
            "cash_flow": {"spent_this_month": 100},
        },
    )

    system_prompt = ai_service.messages[0]["content"]
    assert "verify with an available source" in system_prompt
    assert "state assumptions" in system_prompt
    assert "avoid guaranteed outcomes" in system_prompt
    assert "Do not imply background monitoring" in system_prompt
    assert "Ask for confirmation" in system_prompt


@pytest.mark.asyncio
async def test_mvp_flow_preserves_memory_status_in_prompt_context():
    ai_service = FakeAIService(response="Rex response")
    memory_service = FakeMemoryService()
    memory_service.structured_context = {
        "memory_status": {
            "state": "degraded",
            "message": "Some memory sources could not be searched.",
            "failures": [
                {
                    "source": "chat_search",
                    "message": "search failed",
                }
            ],
        }
    }
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    await chat_service.send_message("Do you know anything about my mom?")

    system_prompt = ai_service.messages[0]["content"]
    assert "recall_status" in system_prompt
    assert "chat_search=degraded" in system_prompt
    assert "Failed sources: chat_search" in system_prompt
    assert "search had trouble" in system_prompt
