import pytest

from app.services.memory_correction_service import (
    CorrectionIntent,
    CorrectionIntentType,
)
from app.services.memory_post_turn_service import MemoryPostTurnService


class FakeMemoryCorrectionService:
    def __init__(self, intent):
        self.intent = intent

    def detect_correction_intent(self, message):
        return self.intent


class FakeMemoryCandidateService:
    def __init__(self):
        self.created = []

    async def create_candidate(self, request):
        self.created.append(request)
        return {
            "id": "candidate-1",
            "candidate_type": request.candidate_type,
            "risk_level": request.risk_level,
            "preview": "replace old value",
        }


class FailingMemoryCandidateService:
    async def create_candidate(self, request):
        raise RuntimeError("candidate failed")


class FailingMemoryExtractionService:
    async def extract_and_save(self, **kwargs):
        raise RuntimeError("extraction failed")


@pytest.mark.asyncio
async def test_memory_post_turn_service_creates_pending_correction_candidate():
    candidate_service = FakeMemoryCandidateService()
    service = MemoryPostTurnService(
        memory_correction_service=FakeMemoryCorrectionService(
            CorrectionIntent(
                CorrectionIntentType.REPLACE_VALUE,
                old_value="June 19",
                new_value="June 18",
                target_hint="mom birthday",
                confidence=0.9,
            )
        ),
        memory_candidate_service=candidate_service,
    )

    result = await service.apply_memory_correction(
        "Actually my mom's birthday is June 18",
        conversation_id="conversation-1",
        user_message_id="message-1",
        brain_metadata={"layer": "fast_contextual"},
    )

    assert result["requires_confirmation"] is True
    assert result["candidate_id"] == "candidate-1"
    assert result["memory_path"] == "pending_review"
    assert result["review_required"] is True
    assert result["review_reason"] == (
        "Correction could change saved memory, so it needs explicit review."
    )
    request = candidate_service.created[0]
    assert request.candidate_type == "correction"
    assert request.payload["metadata"]["rex_brain"] == {"layer": "fast_contextual"}
    assert request.payload["metadata"]["memory_path"] == "pending_review"


@pytest.mark.asyncio
async def test_memory_post_turn_service_reports_correction_candidate_failure():
    service = MemoryPostTurnService(
        memory_correction_service=FakeMemoryCorrectionService(
            CorrectionIntent(
                CorrectionIntentType.REPLACE_VALUE,
                old_value="June 19",
                new_value="June 18",
                target_hint="mom birthday",
                confidence=0.9,
            )
        ),
        memory_candidate_service=FailingMemoryCandidateService(),
    )

    result = await service.apply_memory_correction(
        "Actually my mom's birthday is June 18",
        conversation_id="conversation-1",
        user_message_id="message-1",
    )

    assert result["failed"] is True
    assert result["requires_confirmation"] is False
    assert result["memory_path"] == "degraded"
    assert result["metadata"]["degraded"] is True
    assert result["metadata"]["operation"] == "create_correction_candidate"
    assert result["metadata"]["failure_reason"] == (
        "correction_candidate_create_failed"
    )


def test_memory_post_turn_service_summarizes_extraction_and_correction_changes():
    service = MemoryPostTurnService()

    summary = service.memory_change_summary(
        [
            {
                "extraction_kind": "durable_memory",
                "memory_type": "personal_fact",
                "extraction_action": "create",
                "id": "memory-1",
                "content": "Mom's birthday is June 18",
            },
            {
                "extraction_kind": "structured_memory",
                "structured_type": "commitment",
                "extraction_action": "candidate_created",
                "id": "candidate-1",
                "title": "Send mom something",
            },
        ],
        memory_correction={"requires_confirmation": True},
    )

    assert summary["created"] == 1
    assert summary["confirmation_required"] == 2
    assert len(summary["records"]) == 3
    assert summary["records"][1]["memory_path"] is None
    assert summary["records"][2]["memory_path"] is None


def test_memory_post_turn_service_summarizes_failed_correction_as_skipped():
    service = MemoryPostTurnService()

    summary = service.memory_change_summary(
        [],
        memory_correction={
            "failed": True,
            "memory_path": "degraded",
            "review_required": False,
            "review_reason": "correction_candidate_create_failed",
            "metadata": {"degraded": True},
        },
    )

    assert summary["skipped"] == 1
    assert summary["confirmation_required"] == 0
    assert summary["records"][0]["action"] == "failed"
    assert summary["records"][0]["metadata"]["degraded"] is True


def test_memory_post_turn_service_counts_reused_candidate_as_review_required():
    service = MemoryPostTurnService()

    summary = service.memory_change_summary(
        [
            {
                "extraction_kind": "memory_candidate",
                "structured_type": "long_term_memory",
                "extraction_action": "candidate_reused",
                "id": "candidate-1",
                "content": "Mom's birthday is June 18",
                "memory_path": "pending_review",
                "review_required": True,
                "review_reason": "Extracted memory needs review before saving.",
            },
        ],
    )

    assert summary["created"] == 0
    assert summary["confirmation_required"] == 1
    assert summary["records"][0]["memory_path"] == "pending_review"


@pytest.mark.asyncio
async def test_memory_post_turn_service_extraction_failure_is_best_effort():
    service = MemoryPostTurnService(
        memory_extraction_service=FailingMemoryExtractionService()
    )

    result = await service.extract_memory_after_success(
        "conversation-1",
        {"id": "message-user"},
        {"id": "message-assistant"},
    )

    assert result[0]["extraction_kind"] == "memory_extraction"
    assert result[0]["extraction_action"] == "skip_failed"
    assert result[0]["metadata"]["degraded"] is True
    assert result[0]["metadata"]["operation"] == "extract_memory_after_success"
    assert result[0]["metadata"]["failure_reason"] == "memory_extraction_failed"
