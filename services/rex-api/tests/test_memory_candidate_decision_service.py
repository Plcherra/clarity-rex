import pytest

from app.services.memory_candidate_decision_service import (
    MemoryCandidateDecisionService,
)


class FakeMemoryCandidateService:
    def __init__(self, pending=None):
        self.pending = pending or []
        self.approved = []
        self.rejected = []
        self.updated = []
        self.list_calls = []

    async def list_candidates(
        self,
        *,
        status=None,
        source_conversation_id=None,
        limit=20,
        **kwargs,
    ):
        self.list_calls.append(
            {
                "status": status,
                "source_conversation_id": source_conversation_id,
                "limit": limit,
            }
        )
        pending = self.pending
        if status is not None:
            pending = [
                candidate for candidate in pending if candidate.get("status") == status
            ]
        if source_conversation_id is not None:
            pending = [
                candidate
                for candidate in pending
                if candidate.get("source_conversation_id") == source_conversation_id
            ]
        return pending[:limit]

    async def approve_candidate(self, candidate_id, request):
        candidate = self._candidate(candidate_id)
        approved = {
            **candidate,
            "status": "applied",
            "applied_record_table": "long_term_memory",
            "applied_record_id": "memory-1",
            "verification": {
                "passed": True,
                "message": "Candidate applied and verified.",
                "applied_record": {
                    "table": "long_term_memory",
                    "id": "memory-1",
                },
            },
        }
        self.approved.append(approved)
        return approved

    async def reject_candidate(self, candidate_id, request):
        candidate = self._candidate(candidate_id)
        rejected = {**candidate, "status": "rejected"}
        self.rejected.append(rejected)
        return rejected

    async def update_candidate(self, candidate_id, request):
        candidate = self._candidate(candidate_id)
        payload = request.payload or candidate.get("payload") or {}
        updated = {
            **candidate,
            "payload": payload,
            "reason": request.reason,
            "preview": (
                f"{candidate['candidate_type']}: "
                f"{payload.get('content') or payload.get('title') or payload.get('text')}"
            ),
        }
        self.updated.append(updated)
        return updated

    async def bulk_approve_candidates(self, request):
        approved = []
        skipped = []
        for candidate in self.pending:
            if request.candidate_ids and candidate["id"] not in request.candidate_ids:
                continue
            if candidate.get("risk_level") == "high" and not request.include_high_risk:
                skipped.append(candidate)
            else:
                approved.append(await self.approve_candidate(candidate["id"], request))
        return {"approved": approved, "rejected": [], "skipped": skipped}

    async def bulk_reject_candidates(self, request):
        rejected = [
            await self.reject_candidate(candidate["id"], request)
            for candidate in self.pending
            if not request.candidate_ids or candidate["id"] in request.candidate_ids
        ]
        return {"approved": [], "rejected": rejected, "skipped": []}

    def _candidate(self, candidate_id):
        for candidate in self.pending:
            if candidate["id"] == candidate_id:
                return candidate
        raise AssertionError(f"unknown candidate {candidate_id}")


def candidate(
    candidate_id,
    *,
    candidate_type="long_term_memory",
    risk_level="medium",
    source_conversation_id="conversation-1",
    payload=None,
):
    payload = payload or {
        "memory_type": "preference",
        "content": "Pedro prefers weekly launch plans.",
        "importance": 5,
        "metadata": {
            "memory_path": "pending_review",
            "review_reason": "Extracted memory was not explicitly confirmed in chat, so it needs review.",
        },
    }


    return {
        "id": candidate_id,
        "candidate_type": candidate_type,
        "payload": payload,
        "risk_level": risk_level,
        "status": "pending",
        "preview": f"{candidate_type}: pending memory change",
        "source_conversation_id": source_conversation_id,
        "source_message_id": "message-1",
        "reason": "Memory-worthy user preference.",
    }


class FakeReviewSessionService:
    def __init__(self, latest=None):
        self.latest = latest
        self.created = []
        self.completed = []

    async def create_session(self, *, conversation_id, candidates):
        session = {
            "id": f"session-{len(self.created) + 1}",
            "conversation_id": conversation_id,
            "candidate_ids": [item["id"] for item in candidates],
            "status": "active",
            "expires_at": "2026-06-02T12:30:00Z",
            "metadata": {},
        }
        self.created.append(session)
        self.latest = session
        return session

    async def latest_active_session(self, *, conversation_id):
        return self.latest

    async def complete_session(self, session):
        self.completed.append(session)

    def session_candidate_ids(self, session):
        return list((session or {}).get("candidate_ids") or [])

    def with_session_payload(self, response, session):
        memory_changes = response["memory_changes"]
        memory_changes["review_session"] = {
            **(memory_changes.get("review_session") or {}),
            "id": session["id"],
            "status": session["status"],
            "expires_at": session["expires_at"],
            "candidate_ids": list(session["candidate_ids"]),
        }
        return response


@pytest.mark.asyncio
async def test_candidate_decision_service_ignores_normal_chat():
    fake_service = FakeMemoryCandidateService(pending=[candidate("candidate-1")])
    service = MemoryCandidateDecisionService(fake_service)

    result = await service.handle_decision(
        "Can you help me today?",
        conversation_id="conversation-1",
    )

    assert result is None
    assert fake_service.approved == []
    assert fake_service.rejected == []


@pytest.mark.asyncio
async def test_candidate_decision_service_answers_memory_review_when_none_pending():
    fake_service = FakeMemoryCandidateService(pending=[])
    service = MemoryCandidateDecisionService(fake_service)

    result = await service.handle_decision(
        "Can we review pending memories?",
        conversation_id="conversation-1",
    )

    assert result["response"] == (
        "There are no memory review items waiting right now."
    )
    assert result["memory_changes"]["records"][0]["action"] == "none_pending"
    assert fake_service.approved == []
    assert fake_service.rejected == []


@pytest.mark.asyncio
async def test_candidate_decision_service_review_falls_back_to_global_pending():
    fake_service = FakeMemoryCandidateService(
        pending=[
            candidate(
                "candidate-other-chat",
                source_conversation_id="conversation-old",
            )
        ]
    )
    service = MemoryCandidateDecisionService(fake_service)

    result = await service.handle_decision(
        "Can we review pending memories?",
        conversation_id="conversation-new",
    )

    assert result["memory_changes"]["confirmation_required"] == 1
    assert result["memory_changes"]["pending_candidates"][0]["id"] == (
        "candidate-other-chat"
    )
    assert fake_service.list_calls == [
        {
            "status": "pending",
            "source_conversation_id": "conversation-new",
            "limit": 20,
        },
        {"status": "pending", "source_conversation_id": None, "limit": 20},
    ]


@pytest.mark.asyncio
async def test_candidate_decision_service_blocks_vague_high_risk_confirmation():
    fake_service = FakeMemoryCandidateService(
        pending=[
            candidate(
                "candidate-high",
                candidate_type="correction",
                risk_level="high",
                payload={
                    "text": "Stephanie was not fired.",
                    "intent": {
                        "intent_type": "replace_value",
                        "old_value": "Stephanie got fired",
                        "new_value": "Stephanie quit",
                    },
                },
            )
        ]
    )
    service = MemoryCandidateDecisionService(fake_service)

    result = await service.handle_decision("ok", conversation_id="conversation-1")

    assert fake_service.approved == []
    assert result["memory_changes"]["confirmation_required"] == 1
    card = result["memory_changes"]["pending_candidates"][0]
    assert card["id"] == "candidate-high"
    assert card["requires_explicit_confirmation"] is True
    assert card["payload_preview"]["intent"]["new_value"] == "Stephanie quit"


@pytest.mark.asyncio
async def test_candidate_decision_service_explicit_confirmation_applies_candidate():
    fake_service = FakeMemoryCandidateService(pending=[candidate("candidate-1")])
    service = MemoryCandidateDecisionService(fake_service)

    result = await service.handle_decision("confirm", conversation_id="conversation-1")

    assert fake_service.approved[0]["id"] == "candidate-1"
    assert result["memory_changes"]["created"] == 1
    assert result["memory_changes"]["applied_candidates"][0]["applied_record"] == {
        "table": "long_term_memory",
        "id": "memory-1",
    }


@pytest.mark.asyncio
async def test_candidate_decision_service_lists_multiple_pending_candidates():
    fake_service = FakeMemoryCandidateService(
        pending=[
            candidate("candidate-1", risk_level="medium"),
            candidate("candidate-2", candidate_type="plan", risk_level="high"),
        ]
    )
    service = MemoryCandidateDecisionService(fake_service)

    result = await service.handle_decision("confirm", conversation_id="conversation-1")

    assert fake_service.approved == []
    assert result["memory_changes"]["confirmation_required"] == 2
    assert "candidate card" not in result["response"]
    assert "before saving" in result["response"]
    assert [card["id"] for card in result["memory_changes"]["pending_candidates"]] == [
        "candidate-1",
        "candidate-2",
    ]
    assert result["memory_changes"]["pending_candidates"][0]["memory_path"] == (
        "pending_review"
    )
    assert result["memory_changes"]["pending_candidates"][0]["review_reason"] == (
        "Extracted memory was not explicitly confirmed in chat, so it needs review."
    )


@pytest.mark.asyncio
async def test_candidate_decision_service_creates_review_session_when_listing():
    fake_service = FakeMemoryCandidateService(
        pending=[candidate("candidate-1"), candidate("candidate-2")]
    )
    review_sessions = FakeReviewSessionService()
    service = MemoryCandidateDecisionService(
        fake_service,
        review_session_service=review_sessions,
    )

    result = await service.handle_decision("confirm", conversation_id="conversation-1")

    assert review_sessions.created[0]["candidate_ids"] == [
        "candidate-1",
        "candidate-2",
    ]
    assert result["memory_changes"]["review_session"]["id"] == "session-1"
    assert result["memory_changes"]["review_session"]["candidate_ids"] == [
        "candidate-1",
        "candidate-2",
    ]


@pytest.mark.asyncio
async def test_candidate_decision_service_confirms_them_from_review_session_only():
    fake_service = FakeMemoryCandidateService(
        pending=[
            candidate("candidate-reviewed"),
            candidate("candidate-unreviewed"),
        ]
    )
    review_sessions = FakeReviewSessionService(
        latest={
            "id": "session-existing",
            "candidate_ids": ["candidate-reviewed"],
            "status": "active",
        }
    )
    service = MemoryCandidateDecisionService(
        fake_service,
        review_session_service=review_sessions,
    )

    result = await service.handle_decision(
        "Confirm them as saved.",
        conversation_id="conversation-1",
    )

    assert [item["id"] for item in fake_service.approved] == ["candidate-reviewed"]
    assert result["memory_changes"]["applied_candidates"][0]["id"] == (
        "candidate-reviewed"
    )
    assert review_sessions.completed[0]["id"] == "session-existing"


@pytest.mark.asyncio
async def test_candidate_decision_service_approve_all_ignores_review_session_scope():
    fake_service = FakeMemoryCandidateService(
        pending=[
            candidate("candidate-reviewed"),
            candidate("candidate-unreviewed"),
        ]
    )
    review_sessions = FakeReviewSessionService(
        latest={
            "id": "session-existing",
            "candidate_ids": ["candidate-reviewed"],
            "status": "active",
        }
    )
    service = MemoryCandidateDecisionService(
        fake_service,
        review_session_service=review_sessions,
    )

    await service.handle_decision(
        "Approve all pending.",
        conversation_id="conversation-1",
    )

    assert [item["id"] for item in fake_service.approved] == [
        "candidate-reviewed",
        "candidate-unreviewed",
    ]
    assert review_sessions.completed == []


@pytest.mark.asyncio
async def test_candidate_decision_service_keeps_high_risk_session_item_pending():
    fake_service = FakeMemoryCandidateService(
        pending=[
            candidate("candidate-low", risk_level="medium"),
            candidate("candidate-high", candidate_type="correction", risk_level="high"),
        ]
    )
    review_sessions = FakeReviewSessionService(
        latest={
            "id": "session-existing",
            "candidate_ids": ["candidate-low", "candidate-high"],
            "status": "active",
        }
    )
    service = MemoryCandidateDecisionService(
        fake_service,
        review_session_service=review_sessions,
    )

    result = await service.handle_decision(
        "Save those.",
        conversation_id="conversation-1",
    )

    assert [item["id"] for item in fake_service.approved] == ["candidate-low"]
    assert result["memory_changes"]["skipped_candidates"][0]["id"] == (
        "candidate-high"
    )
    assert review_sessions.completed[0]["id"] == "session-existing"


@pytest.mark.asyncio
async def test_candidate_decision_service_can_confirm_specific_candidate_by_id():
    fake_service = FakeMemoryCandidateService(
        pending=[
            candidate("candidate-low", risk_level="medium"),
            candidate("candidate-high", candidate_type="correction", risk_level="high"),
        ]
    )
    service = MemoryCandidateDecisionService(fake_service)

    result = await service.handle_decision(
        "confirm memory candidate candidate-high",
        conversation_id="conversation-1",
    )

    assert fake_service.approved[0]["id"] == "candidate-high"
    assert result["memory_changes"]["applied_candidates"][0]["id"] == "candidate-high"


@pytest.mark.asyncio
async def test_candidate_decision_service_can_edit_pending_candidate():
    fake_service = FakeMemoryCandidateService(
        pending=[candidate("candidate-1", payload={"content": "Old text"})]
    )
    service = MemoryCandidateDecisionService(fake_service)

    result = await service.handle_decision(
        "Edit pending memory candidate-1: Pedro prefers concise updates",
        conversation_id="conversation-1",
    )

    assert fake_service.updated[0]["payload"]["content"] == (
        "Pedro prefers concise updates"
    )
    assert result["response"] == (
        "Updated 1 memory review item. Review it before saving."
    )
    assert result["memory_changes"]["pending_candidates"][0]["payload_preview"][
        "content"
    ] == "Pedro prefers concise updates"


@pytest.mark.asyncio
async def test_candidate_decision_service_can_reject_all_pending_candidates():
    fake_service = FakeMemoryCandidateService(
        pending=[candidate("candidate-1"), candidate("candidate-2")]
    )
    service = MemoryCandidateDecisionService(fake_service)

    result = await service.handle_decision(
        "reject all pending",
        conversation_id="conversation-1",
    )

    assert [item["id"] for item in fake_service.rejected] == [
        "candidate-1",
        "candidate-2",
    ]
    assert result["memory_changes"]["rejected_candidates"][0]["id"] == "candidate-1"
    assert result["memory_changes"]["rejected_candidates"][1]["id"] == "candidate-2"
