import pytest

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from chat_service_fakes import (
    FakeAIService,
    FakeMemoryCandidateService,
    FakeMemoryCorrectionService,
    FakeMemoryExtractionService,
    FakeMemoryService,
)


@pytest.mark.asyncio
async def test_phone_phrase_finishes_all_pending_memory_without_extraction():
    ai_service = FakeAIService(response="AI should not answer")
    extraction_service = FakeMemoryExtractionService(
        result=[{"extraction_action": "candidate_created"}]
    )
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
                "payload": {"text": "Fix Summerville location."},
                "risk_level": "high",
                "status": "pending",
                "preview": "correction: Fix Summerville location.",
            },
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        extraction_service,
        memory_candidate_service=candidate_service,
    )

    result = await chat_service.send_message(
        "Yes, we should review and finish all the pending memory.",
        "conversation-existing",
    )

    assert [candidate["id"] for candidate in candidate_service.approved] == [
        "candidate-low"
    ]
    assert result["memory_changes"]["applied_candidates"][0]["id"] == "candidate-low"
    assert result["memory_changes"]["skipped_candidates"][0]["id"] == "candidate-high"
    assert extraction_service.calls == []
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_confirm_those_as_saved_applies_multiple_eligible_pending():
    ai_service = FakeAIService(response="AI should not answer")
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
                "candidate_type": "long_term_memory",
                "payload": {
                    "memory_type": "preference",
                    "content": "Pedro prefers concise updates.",
                },
                "risk_level": "medium",
                "status": "pending",
                "preview": "long_term_memory: Pedro prefers concise updates.",
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
        "Confirm those as saved.",
        "conversation-existing",
    )

    assert [candidate["id"] for candidate in candidate_service.approved] == [
        "candidate-1",
        "candidate-2",
    ]
    assert result["memory_changes"]["created"] == 2
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_yes_but_updates_pending_correction_without_new_candidate():
    ai_service = FakeAIService(response="AI should not answer")
    extraction_service = FakeMemoryExtractionService(
        result=[{"extraction_action": "candidate_created"}]
    )
    memory_service = FakeMemoryService()
    memory_service.conversations.add("conversation-existing")
    candidate_service = FakeMemoryCandidateService(
        pending=[
            {
                "id": "candidate-correction",
                "candidate_type": "correction",
                "payload": {
                    "text": "Correction: replace like this with Summerville."
                },
                "risk_level": "high",
                "status": "pending",
                "preview": "correction: replace like this with Summerville.",
            },
        ]
    )
    correction_service = FakeMemoryCorrectionService(payload={"applied": False})
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        extraction_service,
        memory_candidate_service=candidate_service,
        memory_correction_service=correction_service,
    )

    result = await chat_service.send_message(
        "Yes. But Summerville is not like this. "
        "It's Summerville City in Massachusetts. It with o and one m.",
        "conversation-existing",
    )

    assert candidate_service.created == []
    assert len(candidate_service.updated) == 1
    assert candidate_service.updated[0]["id"] == "candidate-correction"
    assert candidate_service.updated[0]["payload"]["text"].startswith(
        "Summerville is not like this"
    )
    assert result["memory_changes"]["pending_candidates"][0]["id"] == (
        "candidate-correction"
    )
    assert extraction_service.calls == []
    assert correction_service.calls == []
    assert ai_service.messages == []
