"""Durable write apply failure honesty — log + structured reason, never silent."""

from __future__ import annotations

import logging

import pytest

from app.services.durable_write_applier import DurableWriteApplier
from app.services.durable_write_proposal import DurableWriteProposal
from app.services.durable_write_results import failed_memory_changes
from app.services.plan_errors import PlanServiceError


class _FailingMemoryService:
    async def list_long_term_memory(self, **_kwargs):
        return []

    async def list_entities(self, **_kwargs):
        return []

    async def list_personal_rules(self, **_kwargs):
        return []

    async def list_plans(self, **_kwargs):
        return []

    async def list_plan_milestones(self, **_kwargs):
        return []

    async def save_long_term_memory(self, **_kwargs):
        raise RuntimeError("db unavailable")


class _EmptyMemoryService:
    async def list_long_term_memory(self, **_kwargs):
        return []

    async def list_entities(self, **_kwargs):
        return []

    async def list_personal_rules(self, **_kwargs):
        return []

    async def list_plans(self, **_kwargs):
        return []

    async def list_plan_milestones(self, **_kwargs):
        return []

    async def save_long_term_memory(self, **_kwargs):
        return {}


class _FailingPlanService:
    async def create_plan(self, _request):
        raise PlanServiceError("plan write failed")


def _memory_proposal() -> DurableWriteProposal:
    return DurableWriteProposal(
        write_kind="memory",
        title="Mom birthday",
        body="Mom's birthday is June 18",
        apply_snapshot={
            "type": "memory",
            "payload": {
                "memory_type": "fact",
                "content": "Mom's birthday is June 18",
                "importance": 3,
                "metadata": {},
            },
        },
    )


@pytest.mark.asyncio
async def test_apply_memory_exception_returns_structured_reason(caplog):
    applier = DurableWriteApplier(_FailingMemoryService())
    proposal = _memory_proposal()

    with caplog.at_level(logging.WARNING, logger="rex.durable_write"):
        result = await applier.apply_proposal(
            proposal,
            conversation_id="conversation-1",
        )

    assert result["applied"] is False
    assert result["reason"] == "memory_apply_failed:RuntimeError"
    assert "durable_write_apply_failed" in caplog.text
    assert "RuntimeError" in caplog.text


@pytest.mark.asyncio
async def test_apply_memory_missing_record_returns_structured_reason(caplog):
    applier = DurableWriteApplier(_EmptyMemoryService())
    proposal = _memory_proposal()

    with caplog.at_level(logging.WARNING, logger="rex.durable_write"):
        result = await applier.apply_proposal(
            proposal,
            conversation_id="conversation-1",
        )

    assert result["applied"] is False
    assert result["reason"] == "memory_apply_failed:memory_write_error"
    assert "missing_record" in caplog.text or "memory_write_error" in result["reason"]


@pytest.mark.asyncio
async def test_apply_plan_service_error_returns_structured_reason(caplog):
    applier = DurableWriteApplier(
        object(),
        plan_service=_FailingPlanService(),  # type: ignore[arg-type]
    )
    proposal = DurableWriteProposal(
        write_kind="plan",
        title="Save $5000",
        body="Save $5000 by August",
        apply_snapshot={
            "type": "plan",
            "payload": {
                "plan_type": "personal",
                "title": "Save $5000",
                "description": "Save $5000 by August",
                "metadata": {},
            },
        },
    )

    with caplog.at_level(logging.WARNING, logger="rex.durable_write"):
        result = await applier.apply_proposal(
            proposal,
            conversation_id="conversation-1",
        )

    assert result["applied"] is False
    assert result["reason"] == "plan_apply_failed:PlanServiceError"
    assert "PlanServiceError" in caplog.text


def test_failed_memory_changes_includes_failure_reason():
    proposal = _memory_proposal()
    changes = failed_memory_changes(
        proposal=proposal,
        reason="memory_apply_failed:RuntimeError",
    )

    card = changes["write_proposals"][0]
    assert card["status"] == "failed"
    assert card["failure_reason"] == "memory_apply_failed:RuntimeError"
    assert card["error_message"] == "memory_apply_failed:RuntimeError"


@pytest.mark.asyncio
async def test_apply_memory_merges_duplicate_at_confirm_time():
    class _Repo:
        def __init__(self):
            self.memories = [
                {
                    "id": "memory-existing",
                    "memory_type": "fact",
                    "content": "Mom's birthday is June 18",
                    "importance": 3,
                    "active": True,
                    "metadata": {},
                }
            ]

        async def list_long_term_memory(self, **_kwargs):
            return list(self.memories)

        async def list_entities(self, **_kwargs):
            return []

        async def list_personal_rules(self, **_kwargs):
            return []

        async def list_plans(self, **_kwargs):
            return []

        async def list_plan_milestones(self, **_kwargs):
            return []

        async def save_long_term_memory(self, **kwargs):
            raise AssertionError("create should not run when duplicate exists")

        async def update_long_term_memory(self, memory_id, **kwargs):
            for row in self.memories:
                if row["id"] == memory_id:
                    row.update(
                        {
                            "memory_type": kwargs.get("memory_type") or row["memory_type"],
                            "content": kwargs.get("content") or row["content"],
                            "importance": kwargs.get("importance") or row["importance"],
                            "metadata": kwargs.get("metadata") or row["metadata"],
                        }
                    )
                    return dict(row)
            raise KeyError(memory_id)

    repo = _Repo()
    applier = DurableWriteApplier(repo)
    proposal = DurableWriteProposal(
        write_kind="memory",
        title="Mom birthday",
        body="Mom's birthday is June 18",
        apply_snapshot={
            "type": "memory",
            "payload": {
                "memory_type": "fact",
                "content": "Mom's birthday is June 18",
                "importance": 3,
                "metadata": {},
            },
        },
    )

    result = await applier.apply_proposal(
        proposal,
        conversation_id="conversation-1",
    )

    assert result["applied"] is True
    assert result["merged"] is True
    assert result["record"]["id"] == "memory-existing"
    assert len(repo.memories) == 1


@pytest.mark.asyncio
async def test_apply_memory_fails_closed_when_duplicate_list_unavailable():
    class _Repo:
        async def list_long_term_memory(self, **_kwargs):
            raise RuntimeError("db down")

        async def list_entities(self, **_kwargs):
            return []

        async def list_personal_rules(self, **_kwargs):
            return []

        async def list_plans(self, **_kwargs):
            return []

        async def list_plan_milestones(self, **_kwargs):
            return []

        async def save_long_term_memory(self, **_kwargs):
            raise AssertionError("create must not run when list fails")

    applier = DurableWriteApplier(_Repo())
    proposal = DurableWriteProposal(
        write_kind="memory",
        title="Mom birthday",
        body="Mom's birthday is June 18",
        apply_snapshot={
            "type": "memory",
            "payload": {
                "memory_type": "fact",
                "content": "Mom's birthday is June 18",
                "importance": 3,
                "metadata": {},
            },
        },
    )

    result = await applier.apply_proposal(
        proposal,
        conversation_id="conversation-1",
    )

    assert result["applied"] is False
    assert "discipline_context_unavailable" in str(result.get("reason") or "")
