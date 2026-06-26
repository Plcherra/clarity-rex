import pytest
from fastapi import HTTPException

from chat_service_fakes import (
    FailingAIService,
    FakeAIService,
    FakeMemoryService,
    FakeUpload,
)
from app.config import Settings
from app.services.action_truth_policy import (
    DEGRADED_RECALL_FALLBACK,
    FILTERED_RECALL_FALLBACK,
)
from app.services import file_service as file_service_module
from app.services.chat_service import (
    FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE,
    ChatService,
)
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
async def test_image_upload_rejects_images_over_5mb():
    file_service = FileService()
    upload = FakeUpload(
        "receipt.png",
        b"a" * (5 * 1024 * 1024 + 1),
        content_type="image/png",
    )

    with pytest.raises(HTTPException) as error:
        await file_service.read_attachment(upload)

    assert error.value.status_code == 413
    assert error.value.detail == "Uploaded image is too large. Maximum size is 5MB."


@pytest.mark.asyncio
async def test_image_upload_builds_data_url_context():
    file_service = FileService()
    upload = FakeUpload("receipt.png", b"image-bytes", content_type="image/png")

    attachment = await file_service.read_attachment(upload)

    assert attachment.kind == "image"
    assert attachment.filename == "receipt.png"
    assert attachment.content_type == "image/png"
    assert attachment.data_url == "data:image/png;base64,aW1hZ2UtYnl0ZXM="
    assert attachment.prompt_context == (
        "Image attachment: receipt.png (image/png). "
        "Use the attached image as visual context when answering."
    )


@pytest.mark.asyncio
async def test_pdf_upload_extracts_text_context(monkeypatch):
    monkeypatch.setattr(file_service_module, "PdfReader", _FakePdfReader)
    file_service = FileService()
    upload = FakeUpload(
        "statement.pdf",
        b"%PDF bytes",
        content_type="application/pdf",
    )

    attachment = await file_service.read_attachment(upload)

    assert attachment.kind == "pdf"
    assert attachment.filename == "statement.pdf"
    assert attachment.content_type == "application/pdf"
    assert attachment.prompt_context == (
        "PDF attachment: statement.pdf\n\nFirst page text\n\nSecond page text"
    )


@pytest.mark.asyncio
async def test_pdf_upload_rejects_oversized_files():
    file_service = FileService()
    upload = FakeUpload(
        "statement.pdf",
        b"a" * (10 * 1024 * 1024 + 1),
        content_type="application/pdf",
    )

    with pytest.raises(HTTPException) as error:
        await file_service.read_attachment(upload)

    assert error.value.status_code == 413
    assert error.value.detail == "Uploaded PDF is too large. Maximum size is 10MB."


@pytest.mark.asyncio
async def test_pdf_upload_rejects_unreadable_text(monkeypatch):
    monkeypatch.setattr(file_service_module, "PdfReader", _EmptyPdfReader)
    file_service = FileService()
    upload = FakeUpload(
        "scan.pdf",
        b"%PDF bytes",
        content_type="application/pdf",
    )

    with pytest.raises(HTTPException) as error:
        await file_service.read_attachment(upload)

    assert error.value.status_code == 400
    assert error.value.detail == "Uploaded PDF does not contain readable text."


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
async def test_chat_service_omits_attached_financial_context_for_normal_chat():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    await chat_service.send_message(
        "I worked with two new employees, Aaron and Jessica.",
        financial_context={
            "schema": "clarity_unified_financial_context_v1",
            "cash_flow": {"spent_this_month": 100},
        },
    )

    system_content = ai_service.messages[0]["content"]
    assert "Clarity financial summary:" not in system_content
    assert "spent_this_month" not in system_content


@pytest.mark.asyncio
async def test_chat_service_refuses_finance_answer_without_financial_context():
    ai_service = FakeAIService(response="You spent $42 on groceries.")
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("How much did I spend on groceries?")

    assert result["response"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
    assert ai_service.generate_calls == 0
    assert result["messages"][-1]["content"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE


@pytest.mark.asyncio
async def test_chat_service_refuses_finance_answer_with_degraded_context():
    ai_service = FakeAIService(response="Your balance is $500.")
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message(
        "What is my checking account balance?",
        financial_context={
            "schema": "clarity_unified_financial_context_v1",
            "data_status": {
                "state": "degraded",
                "financial_context_complete": False,
                "load_errors": [
                    {
                        "source": "financial_read_model",
                        "message": "load failed",
                    }
                ],
            },
            "integration": {"full_financial_context_included": False},
        },
    )

    assert result["response"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
    assert ai_service.generate_calls == 0


@pytest.mark.asyncio
async def test_chat_service_refuses_finance_answer_with_unverified_context_shape():
    ai_service = FakeAIService(response="You spent $25.")
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message(
        "How much did I spend on groceries?",
        financial_context={"cash_flow": {"spent_this_month": 25}},
    )

    assert result["response"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
    assert ai_service.generate_calls == 0


@pytest.mark.asyncio
async def test_chat_service_allows_finance_answer_with_ready_context():
    ai_service = FakeAIService(response="You spent $25 on groceries.")
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message(
        "How much did I spend on groceries?",
        financial_context={
            "schema": "clarity_unified_financial_context_v1",
            "data_status": {
                "state": "ready",
                "financial_context_complete": True,
                "load_errors": [],
            },
            "integration": {"full_financial_context_included": True},
            "cash_flow": {"spent_this_month": 25},
        },
    )

    assert result["response"] == "You spent $25 on groceries."
    assert ai_service.generate_calls == 1
    system_content = ai_service.messages[0]["content"]
    assert "Clarity financial summary:" in system_content
    assert "spent_this_month=25" in system_content


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
async def test_chat_service_replaces_pending_action_success_claim_with_confirmation():
    ai_service = FakeAIService(
        response=(
            "Saved. I moved Starbucks to Coffee.\n\n"
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

    assert result["response"] == "Move Starbucks to Coffee?"
    assert result["messages"][-1]["content"] == result["response"]
    assert result["memory_changes"]["clarity_action_proposals"][0]["status"] == (
        "pending"
    )


@pytest.mark.asyncio
async def test_chat_service_explains_unsupported_clarity_action_proposal():
    ai_service = FakeAIService(
        response=(
            "I can draft that.\n\n"
            "```clarity_action\n"
            '{"action":"send_email",'
            '"payload":{"to":"mom@example.com"},'
            '"confirmation_text":"Send email?",'
            '"risk_level":"high"}'
            "\n```"
        )
    )
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Send my mom an email")

    assert result["response"] == (
        "I can't complete send email from Clarity yet. I can help you think it "
        "through or draft it, but I won't claim it was done."
    )
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_blocks_success_claim_for_unsupported_clarity_action():
    ai_service = FakeAIService(
        response=(
            "Sent. I emailed your mom.\n\n"
            "```clarity_action\n"
            '{"action":"send_email",'
            '"payload":{"to":"mom@example.com"},'
            '"confirmation_text":"Send email?",'
            '"risk_level":"high"}'
            "\n```"
        )
    )
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Send my mom an email")

    assert result["response"] == (
        "I can't complete send email from Clarity yet. I can help you think it "
        "through or draft it, but I won't claim it was done."
    )
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_blocks_memory_success_claim_without_backend_write():
    ai_service = FakeAIService(response="Saved. I updated your city.")
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Can you update that memory?")

    assert result["response"] == (
        "I can help with that, but I don't have a confirmed saved change from this "
        "turn. Tell me the exact fact to save or try again."
    )
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_allows_old_chat_no_result_claim_after_completed_search():
    ai_service = FakeAIService(
        response="I checked the old chats and found no mentions of your mom."
    )
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message(
        "Can you check the old chats for my mom?"
    )

    assert result["response"] == (
        "I searched my saved memory and old chats but couldn't find anything "
        "about that."
    )
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_standardizes_no_saved_memory_after_empty_chat_search():
    ai_service = FakeAIService(
        response="No, I don't have anything about your mom saved. Want to share?"
    )
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Do you know anything about my mom?")

    assert result["response"] == (
        "I searched my saved memory and old chats but couldn't find anything "
        "about that."
    )
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_downgrades_old_chat_no_result_claim_after_partial_search():
    ai_service = FakeAIService(
        response="I checked the old chats and found no mentions of your mom."
    )
    memory_service = FakeMemoryService()
    memory_service.structured_context = {
        "memory_status": {
            "state": "ready",
            "message": "Memory sources searched successfully.",
            "source_statuses": [
                {
                    "source": "chat_search",
                    "attempted": True,
                    "succeeded": True,
                    "result_count": 0,
                    "partial": True,
                }
            ],
        }
    }
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message(
        "Can you check the old chats for my mom?"
    )

    assert result["response"] == DEGRADED_RECALL_FALLBACK
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_downgrades_no_memory_claim_after_filtered_chat_search():
    ai_service = FakeAIService(
        response="No, I don't have anything about your mom saved."
    )
    memory_service = FakeMemoryService()
    memory_service.structured_context = {
        "memory_status": {
            "state": "ready",
            "message": "Memory sources searched successfully.",
            "source_statuses": [
                {
                    "source": "chat_search",
                    "attempted": True,
                    "succeeded": True,
                    "status": "filtered",
                    "filtered_all_matches": True,
                    "result_count": 0,
                    "raw_match_count": 2,
                    "partial": False,
                }
            ],
        }
    }
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Do you know anything about my mom?")

    assert result["response"] == FILTERED_RECALL_FALLBACK
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_downgrades_no_memory_claim_when_memory_is_degraded():
    ai_service = FakeAIService(response="I don't know anything about your mom.")
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
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Do you know anything about my mom?")

    assert result["response"] == DEGRADED_RECALL_FALLBACK
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_degraded_memory_status_overrides_old_chat_no_result_claim():
    ai_service = FakeAIService(
        response="I checked the old chats and found no mentions of your mom."
    )
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
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message(
        "Can you check the old chats for my mom?"
    )

    assert result["response"] == DEGRADED_RECALL_FALLBACK
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_stream_downgrades_no_memory_claim_when_memory_is_degraded():
    ai_service = FakeAIService(
        stream_tokens=["I don't know ", "anything about your mom."]
    )
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
    chat_service = ChatService(ai_service, FileService(), memory_service)

    events = [
        event
        async for event in chat_service.stream_message(
            "Do you know anything about my mom?"
        )
    ]

    done = next(event for event in events if event["event"] == "done")
    assert done["response"] == DEGRADED_RECALL_FALLBACK
    assert done["memory_changes"] is None


@pytest.mark.asyncio
async def test_chat_service_allows_old_chat_answer_when_chat_search_is_loaded():
    ai_service = FakeAIService(
        response="I found an old chat mention that your mom's birthday is June 18."
    )
    memory_service = FakeMemoryService()
    old_conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        old_conversation_id,
        "user",
        "It's not next week, but on the eighteenth, it's my mom's birthday.",
    )
    await memory_service.save_message(
        old_conversation_id,
        "assistant",
        "Got it, June 18th is your mom's birthday.",
    )
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message(
        "Can you check the old chats for my mom?"
    )

    assert result["response"] == (
        "I found an old chat mention that your mom's birthday is June 18."
    )
    assert "Chat history, not saved memory:" in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_chat_service_blocks_false_current_chat_only_search_claim():
    ai_service = FakeAIService(
        response=(
            "I only search the chat history available right here, so older "
            "messages might not show up."
        )
    )
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message(
        "Why can't you find all the history of our messages?"
    )

    assert result["response"] == (
        "I can search saved chat history when chat search is available. I won't "
        "treat this visible chat as the only source."
    )


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
async def test_chat_service_normal_chat_uses_one_llm_call():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    result = await chat_service.send_message("Add Europe plan note to the draft")

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
async def test_chat_service_stream_uses_one_llm_call():
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
async def test_chat_service_stream_refuses_finance_answer_without_context():
    ai_service = FakeAIService(stream_tokens=["You spent ", "$42."])
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    events = [
        event
        async for event in chat_service.stream_message(
            "How much did I spend on groceries?",
            channel=RexBrainChannel.VOICE,
            include_turn_trace=True,
        )
    ]

    assert events[0] == {"event": "conversation", "conversation_id": "conversation-1"}
    assert events[1]["event"] == "turn.trace"
    assert events[1]["loaded_context"]["financial_context"] is True
    assert events[2] == {
        "event": "token",
        "token": FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE,
    }
    assert events[-1]["event"] == "done"
    assert events[-1]["response"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE
    assert ai_service.stream_calls == 0
    assert memory_service.messages[-1]["content"] == FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE


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
async def test_chat_service_voice_stream_omits_attached_financial_context_for_normal_chat():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    events = [
        event
        async for event in chat_service.stream_message(
            "Tell me about my day",
            financial_context={
                "schema": "clarity_unified_financial_context_v1",
                "cash_flow": {"spent_this_month": 100},
            },
            channel=RexBrainChannel.VOICE,
            include_turn_trace=True,
        )
    ]

    turn_trace = next(event for event in events if event["event"] == "turn.trace")
    system_content = ai_service.messages[0]["content"]
    assert turn_trace["loaded_context"]["financial_context"] is False
    assert "Clarity financial summary:" not in system_content
    assert "spent_this_month" not in system_content


@pytest.mark.asyncio
async def test_chat_service_uses_direct_memory_path_after_successful_response():
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
async def test_chat_service_normal_memory_statement_uses_single_llm_path():
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
async def test_chat_service_does_not_save_memory_when_ai_fails():
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
async def test_chat_service_saves_pc_upgrade_checklist_as_goal_without_llm():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(ai_service, FileService(), memory_service)

    message = (
        "Nice, it would be my next checklist for the next month purchase. "
        "I have to upgrade my ram from 16 to at least 32 or 64 + "
        "1 or 2 more terabytes of space"
    )
    result = await chat_service.send_message(message)

    assert ai_service.generate_calls == 0
    assert "added this as a goal" in result["response"]
    assert len(memory_service.created_plans) == 1
    assert memory_service.created_plans[0]["target_date"] == "July 31"
    assert result["memory_changes"]["records"][0]["kind"] == "plan"
    assert memory_service.long_term_memory == []


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


class _FakePdfReader:
    def __init__(self, _stream):
        self.pages = [_FakePdfPage("First page text"), _FakePdfPage("Second page text")]


class _EmptyPdfReader:
    def __init__(self, _stream):
        self.pages = [_FakePdfPage("")]


class _FakePdfPage:
    def __init__(self, text):
        self._text = text

    def extract_text(self):
        return self._text
