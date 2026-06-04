import pytest
from fastapi import HTTPException

from chat_service_fakes import (
    FailingAIService,
    FakeAIService,
    FakeMemoryDisciplineService,
    FakeMemoryService,
    FakeUpload,
)
from app.config import Settings
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.memory_service import SupabaseMemoryService, MemoryServiceError
from app.services.rex_brain_contracts import RexBrainChannel


@pytest.mark.asyncio
async def test_file_upload_rejects_files_over_2mb():
    file_service = FileService()
    upload = FakeUpload("notes.txt", b"a" * (2 * 1024 * 1024 + 1))

    with pytest.raises(HTTPException) as error:
        await file_service.read_text_file(upload)

    assert error.value.status_code == 413
    assert error.value.detail == "Uploaded file is too large. Maximum size is 2MB."


@pytest.mark.asyncio
async def test_chat_service_handles_normal_chat():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Hello Rex")

    assert result["conversation_id"] == "conversation-1"
    assert result["response"] == "Rex response"
    assert [message["role"] for message in result["messages"]] == [
        "user",
        "assistant",
    ]
    assert ai_service.messages[-1]["content"] == "Hello Rex"


@pytest.mark.asyncio
async def test_chat_service_extracts_clarity_action_proposal():
    ai_service = FakeAIService(
        response=(
            "I found the Starbucks transaction. Confirm moving it to Coffee?\n\n"
            "```clarity_action\n"
            '{"action":"update_transaction",'
            '"payload":{"id":"transaction-1","category_id":"category-coffee"},'
            '"confirmation_text":"Move Starbucks to Coffee?",'
            '"risk_level":"medium"}'
            "\n```"
        )
    )
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Move Starbucks to Coffee")

    assert result["response"] == (
        "I found the Starbucks transaction. Confirm moving it to Coffee?"
    )
    assert result["messages"][-1]["content"] == result["response"]
    assert result["memory_changes"]["clarity_action_proposals"] == [
        {
            "id": "clarity-action-1",
            "action": "update_transaction",
            "payload": {
                "id": "transaction-1",
                "category_id": "category-coffee",
            },
            "confirmation_text": "Move Starbucks to Coffee?",
            "risk_level": "medium",
            "status": "pending",
        }
    ]


@pytest.mark.asyncio
async def test_chat_service_accepts_memory_discipline_dependency_without_behavior_change():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    discipline_service = FakeMemoryDisciplineService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        memory_discipline_service=discipline_service,
    )

    result = await chat_service.send_message("Hello Rex")

    assert result["response"] == "Rex response"
    assert chat_service.memory_discipline_service is discipline_service


@pytest.mark.asyncio
async def test_chat_service_correction_uses_normal_single_llm_turn():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("not Flowfirst, it is FlowForce")

    assert result["memory_correction"] is None
    assert result["response"] == "Rex response"
    assert result["assistant_message"]["content"] == result["response"]
    assert result["memory_changes"] is None
    assert ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_chat_service_does_not_run_post_turn_extraction_on_normal_chat():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Add $5k income under Europe plan")

    assert result["response"] == "Rex response"
    assert result["memory_changes"] is None
    assert ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_chat_service_streams_tokens_and_persists_final_response():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    events = [
        event async for event in chat_service.stream_message("Hello Rex", file=None)
    ]

    assert events[:3] == [
        {"event": "conversation", "conversation_id": "conversation-1"},
        {"event": "token", "token": "Rex "},
        {"event": "token", "token": "stream"},
    ]
    assert events[-1]["event"] == "done"
    assert events[-1]["response"] == "Rex stream"
    assert [message["role"] for message in memory_service.messages] == [
        "user",
        "assistant",
    ]
    assert memory_service.messages[-1]["content"] == "Rex stream"


@pytest.mark.asyncio
async def test_chat_service_stream_hides_clarity_action_block():
    ai_service = FakeAIService(
        stream_tokens=[
            "I found it. ",
            "Confirm the change?\n\n```clar",
            "ity_action\n",
            '{"action":"update_transaction",',
            '"payload":{"id":"transaction-1"},',
            '"confirmation_text":"Update this transaction?",',
            '"risk_level":"medium"}',
            "\n```",
        ]
    )
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    events = [
        event async for event in chat_service.stream_message("Update it", file=None)
    ]
    visible_text = "".join(
        event["token"] for event in events if event["event"] == "token"
    )

    assert "clarity_action" not in visible_text
    assert "transaction-1" not in visible_text
    assert visible_text == "I found it. Confirm the change?\n\n"
    assert events[-1]["response"] == "I found it. Confirm the change?"
    assert events[-1]["memory_changes"]["clarity_action_proposals"][0] == {
        "id": "clarity-action-1",
        "action": "update_transaction",
        "payload": {"id": "transaction-1"},
        "confirmation_text": "Update this transaction?",
        "risk_level": "medium",
        "status": "pending",
    }


@pytest.mark.asyncio
async def test_chat_service_stream_uses_one_llm_call_without_post_turn_memory_work():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    events = [
        event async for event in chat_service.stream_message("Hello Rex", file=None)
    ]

    assert events[-1]["event"] == "done"
    assert events[-1]["response"] == "Rex stream"
    assert ai_service.stream_calls == 1


@pytest.mark.asyncio
async def test_chat_service_voice_stream_uses_one_llm_call():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    events = [
        event
        async for event in chat_service.stream_message(
            "Tell me about my day",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert events[-1]["event"] == "done"
    assert events[-1]["response"] == "Rex stream"
    assert ai_service.stream_calls == 1
    assert ai_service.generate_calls == 0


@pytest.mark.asyncio
async def test_chat_service_skips_memory_extraction_after_successful_response():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    await chat_service.send_message("I work best in the morning")

    assert ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_chat_service_ignores_memory_extraction_failures_when_extraction_is_disabled():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
    )

    result = await chat_service.send_message("I work best in the morning")

    assert result["response"] == "Rex response"
    assert result["memory_changes"] is None
    assert ai_service.generate_calls == 1


@pytest.mark.asyncio
async def test_chat_service_does_not_extract_memory_when_ai_fails():
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        FailingAIService(),
        FileService(),
        memory_service,
    )

    with pytest.raises(RuntimeError):
        await chat_service.send_message("Hello Rex")

    assert memory_service.conversations == {"conversation-1"}
    assert [message["role"] for message in memory_service.messages] == ["user"]
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_chat_service_saves_explicit_goal_without_llm_call():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Track save $5000 by August as a goal")

    assert result["response"] == "Got it, I added this as a goal: Save $5000 by August."
    assert ai_service.generate_calls == 0
    assert len(memory_service.created_plans) == 1
    assert memory_service.created_plans[0]["plan_type"] == "finance"
    assert memory_service.created_plans[0]["target_date"] == "August"
    assert result["memory_changes"]["records"][0]["kind"] == "plan"


@pytest.mark.asyncio
async def test_chat_service_reuses_duplicate_explicit_goal():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    await chat_service.send_message("Track save $5000 by August as a goal")
    await chat_service.send_message("Track save $5000 by August as a goal")

    assert ai_service.generate_calls == 0
    assert len(memory_service.created_plans) == 1
    assert len(memory_service.plans) == 1


@pytest.mark.asyncio
async def test_chat_service_saves_explicit_commitment_without_llm_call():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Remind me to send her $200 on the 10th")

    assert result["response"] == (
        "Got it, I saved that commitment: Send her $200 on the 10th."
    )
    assert ai_service.generate_calls == 0
    assert len(memory_service.created_commitments) == 1
    assert memory_service.created_commitments[0]["commitment_type"] == "money"
    assert memory_service.created_commitments[0]["due_at"] == "June 10"
    assert result["memory_changes"]["records"][0]["kind"] == "commitment"


@pytest.mark.asyncio
async def test_chat_service_voice_stream_saves_commitment_without_llm_call():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    events = [
        event
        async for event in chat_service.stream_message(
            "Remind me to send her $200 on the 10th",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert events[-1]["event"] == "done"
    assert events[-1]["response"] == (
        "Got it, I saved that commitment: Send her $200 on the 10th."
    )
    assert ai_service.stream_calls == 0
    assert ai_service.generate_calls == 0
    assert len(memory_service.created_commitments) == 1


@pytest.mark.asyncio
async def test_supabase_memory_requires_configuration():
    memory_service = SupabaseMemoryService(
        Settings(
            supabase_url=None,
            supabase_service_role_key=None,
        )
    )

    with pytest.raises(MemoryServiceError) as error:
        await memory_service.create_conversation()

    assert error.value.detail == "Supabase memory is not configured."
