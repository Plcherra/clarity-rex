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

    async def list_candidates(
        self,
        *,
        status=None,
        source_conversation_id=None,
        limit=20,
        **kwargs,
    ):
        return self.pending[:limit]

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
            if candidate.get("risk_level") == "high" and not request.include_high_risk:
                skipped.append(candidate)
            else:
                approved.append(await self.approve_candidate(candidate["id"], request))
        return {"approved": approved, "rejected": [], "skipped": skipped}

    async def bulk_reject_candidates(self, request):
        rejected = [
            await self.reject_candidate(candidate["id"], request)
            for candidate in self.pending
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
    payload=None,
):
    payload = payload or {
        "memory_type": "preference",
        "content": "Pedro prefers weekly launch plans.",
        "importance": 5,
    }
    return {
        "id": candidate_id,
        "candidate_type": candidate_type,
        "payload": payload,
        "risk_level": risk_level,
        "status": "pending",
        "preview": f"{candidate_type}: pending memory change",
        "source_conversation_id": "conversation-1",
        "source_message_id": "message-1",
        "reason": "Memory-worthy user preference.",
    }


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
    assert [card["id"] for card in result["memory_changes"]["pending_candidates"]] == [
        "candidate-1",
        "candidate-2",
    ]


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
        "Updated 1 pending memory request. Review it before saving."
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
