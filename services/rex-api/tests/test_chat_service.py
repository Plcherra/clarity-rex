import asyncio

import pytest
from fastapi import HTTPException

from chat_service_fakes import (
    BlockingMemoryExtractionService,
    FailingAIService,
    FakeAIService,
    FakeMemoryCandidateService,
    FakeMemoryCorrectionService,
    FakeMemoryDisciplineService,
    FakeMemoryExtractionService,
    FakeMemoryService,
    FakeUpload,
)
from app.config import Settings
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.memory_service import SupabaseMemoryService, MemoryServiceError


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
async def test_chat_service_applies_memory_correction_and_prompts_summary():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    correction_service = FakeMemoryCorrectionService(
        {
            "applied": True,
            "requires_confirmation": False,
            "affected_records": [
                {"table": "plans", "id": "plan-1", "action": "updated"}
            ],
        }
    )
    candidate_service = FakeMemoryCandidateService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        memory_correction_service=correction_service,
        memory_candidate_service=candidate_service,
    )

    result = await chat_service.send_message("not Flowfirst, it is FlowForce")

    assert result["memory_correction"]["applied"] is False
    assert result["memory_correction"]["requires_confirmation"] is True
    assert result["memory_correction"]["old_value"] == "Flowfirst"
    assert result["memory_correction"]["new_value"] == "FlowForce"
    assert candidate_service.created[0]["candidate_type"] == "correction"
    assert candidate_service.created[0]["payload"]["text"] == (
        "not Flowfirst, it is FlowForce"
    )
    assert candidate_service.created[0]["payload"]["intent"]["old_value"] == "Flowfirst"
    assert candidate_service.created[0]["payload"]["intent"]["new_value"] == "FlowForce"
    rex_brain_metadata = candidate_service.created[0]["payload"]["metadata"][
        "rex_brain"
    ]
    assert rex_brain_metadata["decision"]["layer"] == "layer_0_fast"
    assert rex_brain_metadata["decision"]["model_profile"] == "fast"
    assert "not Flowfirst" not in str(rex_brain_metadata)
    assert correction_service.calls == [("detect", "not Flowfirst, it is FlowForce")]
    assert "Memory correction status" in ai_service.messages[-1]["content"]
    assert any(
        message["content"] == "not Flowfirst, it is FlowForce"
        for message in ai_service.messages
    )
    assert result["memory_changes"]["confirmation_required"] == 1
    assert result["memory_changes"]["records"][-1]["reason"] == (
        "correction_already_handled"
    )


@pytest.mark.asyncio
async def test_chat_service_skips_extraction_after_applied_correction():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    extraction_service = FakeMemoryExtractionService(
        result=[
            {
                "id": "plan-duplicate",
                "extraction_kind": "structured_memory",
                "structured_type": "plan",
                "extraction_action": "create_plan",
            }
        ]
    )
    correction_service = FakeMemoryCorrectionService(
        {
            "applied": True,
            "requires_confirmation": False,
            "updated": [{"table": "entities", "id": "entity-1"}],
        }
    )
    candidate_service = FakeMemoryCandidateService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        extraction_service,
        memory_correction_service=correction_service,
        memory_candidate_service=candidate_service,
    )

    result = await chat_service.send_message("wrong name, fix it")

    assert extraction_service.calls == []
    assert result["memory_changes"]["updated"] == 0
    assert result["memory_changes"]["confirmation_required"] == 1
    assert result["memory_changes"]["skipped"] == 1


@pytest.mark.asyncio
async def test_chat_service_returns_memory_change_summary_for_extraction():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    extraction_service = FakeMemoryExtractionService(
        result=[
            {
                "id": "milestone-1",
                "title": "$5k monthly revenue target",
                "extraction_kind": "structured_memory",
                "structured_type": "plan_milestone",
                "extraction_action": "create_milestone",
            },
            {
                "id": "plan-1",
                "title": "Relocate to Europe next year",
                "extraction_kind": "structured_memory",
                "structured_type": "plan",
                "extraction_action": "update_plan",
            },
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        extraction_service,
    )

    result = await chat_service.send_message("Add $5k income under Europe plan")

    assert result["memory_changes"]["created"] == 1
    assert result["memory_changes"]["updated"] == 1
    assert result["memory_changes"]["records"][0]["type"] == "plan_milestone"


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
async def test_chat_service_stream_done_does_not_wait_for_memory_extraction():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    extraction_service = BlockingMemoryExtractionService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        extraction_service,
    )

    events = [
        event async for event in chat_service.stream_message("Hello Rex", file=None)
    ]

    assert events[-1]["event"] == "done"
    assert events[-1]["response"] == "Rex stream"

    await asyncio.wait_for(extraction_service.started.wait(), timeout=1)
    assert len(extraction_service.calls) == 1
    assert extraction_service.calls[0]["conversation_id"] == "conversation-1"

    extraction_service.release.set()
    await asyncio.sleep(0)


@pytest.mark.asyncio
async def test_chat_service_runs_memory_extraction_after_successful_response():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    extraction_service = FakeMemoryExtractionService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        extraction_service,
    )

    await chat_service.send_message("I work best in the morning")

    assert len(extraction_service.calls) == 1
    assert extraction_service.calls[0]["conversation_id"] == "conversation-1"
    assert extraction_service.calls[0]["user_message"]["content"] == (
        "I work best in the morning"
    )
    assert extraction_service.calls[0]["assistant_message"]["content"] == (
        "Rex response"
    )
    assert extraction_service.calls[0]["brain_metadata"]["source"] == "rex_brain"
    assert "morning" not in str(extraction_service.calls[0]["brain_metadata"])


@pytest.mark.asyncio
async def test_chat_service_ignores_memory_extraction_failures():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    extraction_service = FakeMemoryExtractionService(should_fail=True)
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        extraction_service,
    )

    result = await chat_service.send_message("I work best in the morning")

    assert result["response"] == "Rex response"
    assert len(extraction_service.calls) == 1


@pytest.mark.asyncio
async def test_chat_service_does_not_extract_memory_when_ai_fails():
    memory_service = FakeMemoryService()
    extraction_service = FakeMemoryExtractionService()
    chat_service = ChatService(
        FailingAIService(),
        FileService(),
        memory_service,
        extraction_service,
    )

    with pytest.raises(RuntimeError):
        await chat_service.send_message("Hello Rex")

    assert memory_service.conversations == {"conversation-1"}
    assert [message["role"] for message in memory_service.messages] == ["user"]
    assert memory_service.long_term_memory == []
    assert extraction_service.calls == []


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
