import pytest

from app.models.memory_discipline import (
    MemoryCandidateKind,
    MemoryDisciplineAction,
    MemoryDisciplineDecision,
)
from app.services.memory_candidate_writer import MemoryCandidateWriter


class FakeCandidateStore:
    def __init__(self):
        self.created = []
        self.pending = []

    async def create_memory_candidate(self, payload):
        self.created.append(payload)
        return {"id": "candidate-1", **payload}

    async def list_memory_candidates(
        self,
        limit=20,
        candidate_type=None,
        status=None,
        source_conversation_id=None,
        **kwargs,
    ):
        rows = self.pending
        if candidate_type is not None:
            rows = [row for row in rows if row.get("candidate_type") == candidate_type]
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        if source_conversation_id is not None:
            rows = [
                row
                for row in rows
                if row.get("source_conversation_id") == source_conversation_id
            ]
        return rows[:limit]


class FailingCandidateStore(FakeCandidateStore):
    async def create_memory_candidate(self, payload):
        raise RuntimeError("candidate write failed")


class FakeDisciplineService:
    def __init__(self, decision=None, fail=False):
        self.decision = decision
        self.fail = fail
        self.seen = []

    async def decide(self, candidate):
        self.seen.append(candidate)
        if self.fail:
            raise RuntimeError("discipline failed")
        return self.decision


@pytest.mark.asyncio
async def test_memory_candidate_writer_creates_pending_candidate_with_brain_metadata():
    store = FakeCandidateStore()
    writer = MemoryCandidateWriter(store, FakeDisciplineService())

    result = await writer.create_pending_memory_candidate(
        candidate_type="long_term_memory",
        payload={
            "memory_type": "fact",
            "content": "Mom's birthday is June 18",
            "importance": 5,
            "metadata": {"source": "test"},
        },
        rationale="Important family context",
        conversation_id="conversation-1",
        user_message_id="message-1",
        risk_level="high",
        brain_metadata={"layer": "fast_contextual"},
    )

    assert result["id"] == "candidate-1"
    assert result["pending"] is True
    assert result["memory_type"] == "fact"
    assert result["metadata"]["rex_brain"] == {"layer": "fast_contextual"}
    assert result["metadata"]["memory_path"] == "pending_review"
    assert result["metadata"]["review_required"] is True
    assert result["metadata"]["review_reason"] == (
        "High-importance extracted memory needs review before saving."
    )
    assert result["memory_path"] == "pending_review"
    assert result["review_required"] is True
    assert store.created[0]["risk_level"] == "high"


@pytest.mark.asyncio
async def test_memory_candidate_writer_reuses_pending_candidate_by_fingerprint():
    store = FakeCandidateStore()
    store.pending.append(
        {
            "id": "candidate-existing",
            "candidate_type": "long_term_memory",
            "payload": {
                "memory_type": "fact",
                "content": "Mom's birthday is June 18",
                "metadata": {"topic_fingerprint": "fact:birthday:mom"},
            },
            "status": "pending",
            "source_conversation_id": "conversation-1",
        }
    )
    writer = MemoryCandidateWriter(store, FakeDisciplineService())

    result = await writer.create_pending_memory_candidate(
        candidate_type="long_term_memory",
        payload={
            "memory_type": "fact",
            "content": "Mom's birthday is June 18",
            "metadata": {"topic_fingerprint": "fact:birthday:mom"},
        },
        rationale="Important family context",
        conversation_id="conversation-1",
        user_message_id="message-1",
        risk_level="high",
    )

    assert result["id"] == "candidate-existing"
    assert result["extraction_action"] == "candidate_reused"
    assert result["memory_path"] == "pending_review"
    assert store.created == []


@pytest.mark.asyncio
async def test_memory_candidate_writer_reports_candidate_create_failure():
    writer = MemoryCandidateWriter(FailingCandidateStore(), FakeDisciplineService())

    result = await writer.create_pending_memory_candidate(
        candidate_type="long_term_memory",
        payload={
            "memory_type": "fact",
            "content": "Mom's birthday is June 18",
            "metadata": {"topic_fingerprint": "fact:birthday:mom"},
        },
        rationale="Important family context",
        conversation_id="conversation-1",
        user_message_id="message-1",
        risk_level="high",
    )

    assert result["extraction_action"] == "skip_candidate_create_failed"
    assert result["pending"] is False
    assert result["memory_path"] == "degraded"
    assert result["review_required"] is False
    assert result["metadata"]["degraded"] is True
    assert result["metadata"]["operation"] == "create_memory_candidate"
    assert result["metadata"]["failure_reason"] == "memory_candidate_create_failed"


@pytest.mark.asyncio
async def test_memory_candidate_writer_reuses_pending_candidate_by_text():
    store = FakeCandidateStore()
    store.pending.append(
        {
            "id": "candidate-existing",
            "candidate_type": "long_term_memory",
            "payload": {
                "memory_type": "fact",
                "content": "Mom's birthday is June 18.",
            },
            "status": "pending",
            "source_conversation_id": "conversation-1",
        }
    )
    writer = MemoryCandidateWriter(store, FakeDisciplineService())

    result = await writer.create_pending_memory_candidate(
        candidate_type="long_term_memory",
        payload={
            "memory_type": "fact",
            "content": "Mom's birthday is June 18",
        },
        rationale="Important family context",
        conversation_id="conversation-1",
        user_message_id="message-1",
        risk_level="high",
    )

    assert result["id"] == "candidate-existing"
    assert result["extraction_action"] == "candidate_reused"
    assert store.created == []


@pytest.mark.asyncio
async def test_memory_candidate_writer_applies_discipline_decision():
    decision = MemoryDisciplineDecision(
        action=MemoryDisciplineAction.UPDATE_PLAN,
        candidate_kind=MemoryCandidateKind.PLAN,
        payload={"title": "Updated plan", "source_conversation_id": "conversation-1"},
        reason="Existing plan should be updated",
        confidence=0.9,
        target_table="plans",
        target_id="plan-1",
        requires_confirmation=True,
    )
    store = FakeCandidateStore()
    writer = MemoryCandidateWriter(store, FakeDisciplineService(decision))

    result = await writer.save_structured_candidate(
        kind=MemoryCandidateKind.PLAN,
        payload={"title": "Plan", "source_conversation_id": "conversation-1"},
        rationale="Useful plan context",
        fallback=lambda: None,
    )

    assert result["structured_type"] == "plan"
    assert result["memory_discipline"]["action"] == "update_plan"
    assert result["memory_discipline"]["target_id"] == "plan-1"
    assert store.created[0]["risk_level"] == "high"


def test_memory_candidate_writer_risk_levels_are_stable():
    writer = MemoryCandidateWriter(FakeCandidateStore(), FakeDisciplineService())

    assert writer.candidate_risk_level(
        candidate_type="long_term_memory",
        payload={"importance": 5},
    ) == "high"
    assert writer.candidate_risk_level(
        candidate_type="entity_event",
        payload={},
    ) == "low"
    assert writer.candidate_risk_level(
        candidate_type="personal_rule",
        payload={},
    ) == "medium"
