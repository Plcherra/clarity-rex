import pytest
from app.services.memory_candidate_decision_service import (
    MemoryCandidateDecisionService,
)
from app.services.memory_candidate_writer import MemoryCandidateWriter


class FakeCandidateDecisionStore:
    def __init__(self, pending):
        self.pending = pending
        self.approved = []
        self.updated = []
        self.list_calls = []

    async def list_candidates(self, *, status=None, source_conversation_id=None, limit=20):
        self.list_calls.append(
            {
                "status": status,
                "source_conversation_id": source_conversation_id,
                "limit": limit,
            }
        )
        rows = self.pending
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        if source_conversation_id is not None:
            rows = [
                row
                for row in rows
                if row.get("source_conversation_id") == source_conversation_id
            ]
        return rows[:limit]

    async def bulk_approve_candidates(self, request):
        approved = []
        skipped = []
        for row in self.pending:
            if request.candidate_ids and row["id"] not in request.candidate_ids:
                continue
            if row.get("risk_level") == "high" and not request.include_high_risk:
                skipped.append(row)
                continue
            applied = {
                **row,
                "status": "applied",
                "applied_record_table": "long_term_memory",
                "applied_record_id": f"memory-{row['id']}",
                "verification": {"passed": True},
            }
            self.approved.append(applied)
            approved.append(applied)
        return {"approved": approved, "rejected": [], "skipped": skipped}

    async def update_candidate(self, candidate_id, request):
        row = next(item for item in self.pending if item["id"] == candidate_id)
        updated = {
            **row,
            "payload": request.payload,
            "preview": f"{row['candidate_type']}: {request.payload.get('text')}",
        }
        self.updated.append(updated)
        return updated


class FakeReviewSessions:
    def __init__(self):
        self.latest = None
        self.completed = []

    async def create_session(self, *, conversation_id, candidates):
        self.latest = {
            "id": "session-1",
            "conversation_id": conversation_id,
            "candidate_ids": [row["id"] for row in candidates],
            "status": "active",
            "expires_at": "2026-06-02T12:30:00Z",
        }
        return self.latest

    async def latest_active_session(self, *, conversation_id):
        return self.latest

    async def complete_session(self, session):
        self.completed.append(session)

    def session_candidate_ids(self, session):
        return list((session or {}).get("candidate_ids") or [])

    def with_session_payload(self, response, session):
        response["memory_changes"]["review_session"] = {
            "id": session["id"],
            "candidate_ids": list(session["candidate_ids"]),
            "status": session["status"],
        }
        return response


class FakeCandidateWriterStore:
    def __init__(self):
        self.pending = []
        self.created = []

    async def list_memory_candidates(
        self,
        *,
        limit=20,
        candidate_type=None,
        status=None,
        source_conversation_id=None,
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

    async def create_memory_candidate(self, payload):
        self.created.append(payload)
        return {"id": "candidate-created", **payload}


class FakeDisciplineService:
    async def decide(self, candidate):
        return None


def _candidate(candidate_id, *, source_conversation_id="conversation-old"):
    return {
        "id": candidate_id,
        "candidate_type": "long_term_memory",
        "payload": {
            "memory_type": "fact",
            "content": "Mom's birthday is June 18.",
            "metadata": {
                "topic_fingerprint": "fact:birthday:mom",
                "memory_path": "pending_review",
            },
        },
        "status": "pending",
        "risk_level": "medium",
        "preview": "long_term_memory: Mom's birthday is June 18.",
        "source_conversation_id": source_conversation_id,
        "source_message_id": "message-1",
        "reason": "Recurring personal date.",
    }


@pytest.mark.asyncio
async def test_review_then_save_those_uses_global_pending_review_session():
    store = FakeCandidateDecisionStore([_candidate("candidate-old")])
    sessions = FakeReviewSessions()
    service = MemoryCandidateDecisionService(
        store,
        review_session_service=sessions,
    )

    review = await service.handle_decision(
        "Can we review pending memories?",
        conversation_id="conversation-new",
    )
    saved = await service.handle_decision(
        "Save those.",
        conversation_id="conversation-new",
    )

    assert review["memory_changes"]["pending_candidates"][0]["id"] == "candidate-old"
    assert [row["id"] for row in store.approved] == ["candidate-old"]
    assert saved["memory_changes"]["created"] == 1
    assert sessions.completed[0]["id"] == "session-1"


@pytest.mark.asyncio
async def test_approve_with_correction_can_update_global_pending_candidate():
    store = FakeCandidateDecisionStore(
        [
            {
                **_candidate("candidate-correction"),
                "candidate_type": "correction",
                "risk_level": "high",
                "payload": {
                    "text": "replace Somerville with Somerville",
                    "intent": {"old_value": "Summerville", "new_value": "Somerville"},
                },
            }
        ]
    )
    service = MemoryCandidateDecisionService(store)

    result = await service.handle_decision(
        "Yes, but it is Somerville with one m.",
        conversation_id="conversation-new",
    )

    assert store.updated[0]["id"] == "candidate-correction"
    assert store.updated[0]["payload"]["text"] == "it is Somerville with one m."
    assert result["memory_changes"]["pending_candidates"][0]["id"] == (
        "candidate-correction"
    )


@pytest.mark.asyncio
async def test_writer_reuses_duplicate_pending_candidate_across_conversations():
    store = FakeCandidateWriterStore()
    store.pending.append(_candidate("candidate-old"))
    writer = MemoryCandidateWriter(store, FakeDisciplineService())

    result = await writer.create_pending_memory_candidate(
        candidate_type="long_term_memory",
        payload={
            "memory_type": "fact",
            "content": "Mom's birthday is June 18.",
            "metadata": {"topic_fingerprint": "fact:birthday:mom"},
        },
        rationale="Recurring personal date.",
        conversation_id="conversation-new",
        user_message_id="message-new",
        risk_level="medium",
    )

    assert result["id"] == "candidate-old"
    assert result["extraction_action"] == "candidate_reused"
    assert store.created == []
