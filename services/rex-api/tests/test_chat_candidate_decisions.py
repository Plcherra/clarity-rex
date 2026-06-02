import pytest

from chat_service_fakes import (
    DurableFakeMemoryCandidateService,
    FakeAIService,
    FakeMemoryCandidateService,
    FakeMemoryService,
)
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_brain_contracts import RexBrainChannel


@pytest.mark.asyncio
async def test_chat_service_blocks_vague_confirmation_for_high_risk_candidate():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.conversations.add("conversation-existing")
    candidate_service = FakeMemoryCandidateService(
        pending=[
            {
                "id": "candidate-high",
                "candidate_type": "correction",
                "payload": {
                    "text": "Stephanie was not fired.",
                    "intent": {
                        "intent_type": "replace_value",
                        "old_value": "Stephanie got fired",
                        "new_value": "Stephanie quit",
                    },
                },
                "risk_level": "high",
                "status": "pending",
                "preview": "correction: Stephanie was not fired.",
                "source_conversation_id": "conversation-existing",
                "source_message_id": "message-1",
            }
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        memory_candidate_service=candidate_service,
    )

    result = await chat_service.send_message("ok", "conversation-existing")

    assert candidate_service.approved == []
    assert "high-risk memory change" in result["response"]
    assert result["memory_changes"]["confirmation_required"] == 1
    card = result["memory_changes"]["pending_candidates"][0]
    assert card["id"] == "candidate-high"
    assert card["risk_level"] == "high"
    assert card["requires_explicit_confirmation"] is True
    assert card["expected_action"] == "Review correction before changing saved memory"


@pytest.mark.asyncio
async def test_chat_service_explicit_confirmation_applies_and_reports_candidate_card():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.conversations.add("conversation-existing")
    candidate_service = FakeMemoryCandidateService(
        pending=[
            {
                "id": "candidate-high",
                "candidate_type": "correction",
                "payload": {"text": "Fix Stephanie fact."},
                "risk_level": "high",
                "status": "pending",
                "preview": "correction: Fix Stephanie fact.",
                "source_conversation_id": "conversation-existing",
                "source_message_id": "message-1",
            }
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        memory_candidate_service=candidate_service,
    )

    result = await chat_service.send_message("confirm", "conversation-existing")

    assert candidate_service.approved[0]["id"] == "candidate-high"
    assert result["memory_changes"]["created"] == 1
    assert result["memory_changes"]["applied_candidates"][0]["applied_record"] == {
        "table": "entities",
        "id": "entity-1",
    }
    assert (
        result["memory_changes"]["applied_candidates"][0]["verification"]["passed"]
        is True
    )
    assert result["memory_changes"]["records"][0]["candidate"]["id"] == (
        "candidate-high"
    )


@pytest.mark.asyncio
async def test_approved_memory_is_recalled_in_later_text_and_voice_turns():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.conversations.add("conversation-existing")
    candidate_service = DurableFakeMemoryCandidateService(
        memory_service,
        pending=[
            {
                "id": "candidate-memory",
                "candidate_type": "long_term_memory",
                "payload": {
                    "memory_type": "preference",
                    "content": "Pedro prefers weekly launch plans.",
                    "importance": 5,
                },
                "risk_level": "medium",
                "status": "pending",
                "preview": "long_term_memory: Pedro prefers weekly launch plans.",
                "source_conversation_id": "conversation-existing",
                "source_message_id": "message-source",
            }
        ],
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        memory_candidate_service=candidate_service,
    )

    approval = await chat_service.send_message("confirm", "conversation-existing")

    assert approval["memory_changes"]["applied_candidates"][0]["applied_record"] == {
        "table": "long_term_memory",
        "id": "memory-1",
    }
    assert memory_service.long_term_memory[0]["content"] == (
        "Pedro prefers weekly launch plans."
    )

    await chat_service.send_message("What should I do next?", "conversation-existing")

    assert (
        "- preference: Pedro prefers weekly launch plans."
        in ai_service.messages[0]["content"]
    )

    events = [
        event
        async for event in chat_service.stream_message(
            "Can you help me plan this week?",
            conversation_id="conversation-existing",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert any(event.get("event") == "done" for event in events)
    assert (
        "- preference: Pedro prefers weekly launch plans."
        in ai_service.messages[0]["content"]
    )


@pytest.mark.asyncio
async def test_chat_service_lists_multiple_pending_candidates_as_cards():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.conversations.add("conversation-existing")
    candidate_service = FakeMemoryCandidateService(
        pending=[
            {
                "id": "candidate-1",
                "candidate_type": "commitment",
                "payload": {"title": "Prepare Clarity release build"},
                "risk_level": "low",
                "status": "pending",
                "preview": "commitment: Prepare Clarity release build",
            },
            {
                "id": "candidate-2",
                "candidate_type": "plan",
                "payload": {"title": "Move out of the country"},
                "risk_level": "high",
                "status": "pending",
                "preview": "plan: Move out of the country",
            },
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        memory_candidate_service=candidate_service,
    )

    result = await chat_service.send_message("yes", "conversation-existing")

    assert candidate_service.approved == []
    assert result["memory_changes"]["confirmation_required"] == 2
    assert [card["id"] for card in result["memory_changes"]["pending_candidates"]] == [
        "candidate-1",
        "candidate-2",
    ]
    assert result["memory_changes"]["review_session"]["candidate_ids"] == [
        "candidate-1",
        "candidate-2",
    ]
    assert (
        result["memory_changes"]["pending_candidates"][1][
            "requires_explicit_confirmation"
        ]
        is True
    )


@pytest.mark.asyncio
async def test_chat_service_can_confirm_specific_candidate_by_id():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.conversations.add("conversation-existing")
    candidate_service = FakeMemoryCandidateService(
        pending=[
            {
                "id": "candidate-low",
                "candidate_type": "commitment",
                "payload": {"title": "Prepare Clarity release build"},
                "risk_level": "low",
                "status": "pending",
                "preview": "commitment: Prepare Clarity release build",
            },
            {
                "id": "candidate-high",
                "candidate_type": "correction",
                "payload": {"text": "Fix Stephanie fact."},
                "risk_level": "high",
                "status": "pending",
                "preview": "correction: Fix Stephanie fact.",
            },
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        memory_candidate_service=candidate_service,
    )

    result = await chat_service.send_message(
        "confirm memory candidate candidate-high",
        "conversation-existing",
    )

    assert candidate_service.approved[0]["id"] == "candidate-high"
    assert result["memory_changes"]["applied_candidates"][0]["id"] == (
        "candidate-high"
    )


@pytest.mark.asyncio
async def test_chat_service_can_edit_specific_pending_candidate_by_id():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.conversations.add("conversation-existing")
    candidate_service = FakeMemoryCandidateService(
        pending=[
            {
                "id": "candidate-low",
                "candidate_type": "long_term_memory",
                "payload": {
                    "memory_type": "preference",
                    "content": "Pedro prefers email",
                },
                "risk_level": "medium",
                "status": "pending",
                "preview": "long_term_memory: Pedro prefers email",
            },
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        memory_candidate_service=candidate_service,
    )

    result = await chat_service.send_message(
        "Edit pending memory candidate-low: Pedro prefers concise email updates",
        "conversation-existing",
    )

    assert candidate_service.updated[0]["id"] == "candidate-low"
    assert candidate_service.updated[0]["payload"]["content"] == (
        "Pedro prefers concise email updates"
    )
    assert result["response"] == (
        "Updated 1 memory review item. Review it before saving."
    )
    assert result["memory_changes"]["pending_candidates"][0]["id"] == "candidate-low"
    assert result["memory_changes"]["pending_candidates"][0]["reason"] == (
        "Edited by the user before approval."
    )


@pytest.mark.asyncio
async def test_chat_service_can_reject_all_pending_candidates():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.conversations.add("conversation-existing")
    candidate_service = FakeMemoryCandidateService(
        pending=[
            {
                "id": "candidate-1",
                "candidate_type": "commitment",
                "payload": {"title": "Prepare Clarity release build"},
                "risk_level": "low",
                "status": "pending",
                "preview": "commitment: Prepare Clarity release build",
            },
            {
                "id": "candidate-2",
                "candidate_type": "plan",
                "payload": {"title": "Move out of the country"},
                "risk_level": "high",
                "status": "pending",
                "preview": "plan: Move out of the country",
            },
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        memory_candidate_service=candidate_service,
    )

    result = await chat_service.send_message(
        "reject all pending", "conversation-existing"
    )

    assert [candidate["id"] for candidate in candidate_service.rejected] == [
        "candidate-1",
        "candidate-2",
    ]
    assert result["memory_changes"]["rejected_candidates"][0]["id"] == "candidate-1"
    assert result["memory_changes"]["rejected_candidates"][1]["id"] == "candidate-2"
