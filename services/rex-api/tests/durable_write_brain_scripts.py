"""Scripted-brain chat services for the durable write end-to-end tests.

Grok is the only understanding layer, so these tests script the action the
brain emits for a message instead of relying on the backend to read intent
out of the user's wording.
"""

from __future__ import annotations

from typing import Any, Optional

from app.services.chat_service import ChatService
from chat_service_fakes import FakeMemoryService
from durable_write_test_helpers import confirm_durable_write
from scripted_brain_fakes import fixed_time_context_service, scripted_chat_service

__all__ = [
    "confirm_proposal",
    "fixed_time_context_service",
    "only_proposal",
    "pending_apply_snapshot",
    "scripted_chat_service",
]


def pending_apply_snapshot(
    memory_service: FakeMemoryService,
    conversation_id: str,
) -> dict[str, Any]:
    """The frozen snapshot stored with the pending proposal."""
    pending = memory_service.pending_actions.get(conversation_id)
    assert pending is not None, "expected a pending durable write"
    raw = (pending.get("context") or {}).get("durable_write_proposal") or {}
    return dict(raw.get("apply_snapshot") or {})


def only_proposal(turn: dict[str, Any]) -> dict[str, Any]:
    proposals = (turn.get("memory_changes") or {}).get("write_proposals") or []
    assert len(proposals) == 1, turn.get("response")
    return proposals[0]


async def confirm_proposal(
    chat_service: ChatService,
    turn: dict[str, Any],
    *,
    message: str = "Yes",
    edits: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    """Confirm the turn's single proposal — one is all these flows should offer."""
    only_proposal(turn)
    return await confirm_durable_write(
        chat_service,
        turn,
        message=message,
        edits=edits,
    )
