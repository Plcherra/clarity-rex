"""Helpers for durable write proposal tests."""

from __future__ import annotations

from typing import Any, Optional


async def confirm_durable_write(
    chat_service,
    proposed_turn: dict[str, Any],
    *,
    message: str = "Yes",
    edits: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    memory_changes = proposed_turn.get("memory_changes") or {}
    proposals = (
        memory_changes.get("write_proposals")
        or memory_changes.get("plan_save_proposals")
        or []
    )
    if not proposals:
        raise AssertionError("Expected a pending write proposal to confirm.")
    proposal = proposals[0]
    payload: dict[str, Any] = {"proposal_id": proposal.get("id") or "write-1"}
    resolved_edits = edits
    if resolved_edits is None and (
        proposal.get("title") is not None or proposal.get("body") is not None
    ):
        resolved_edits = {
            key: proposal[key]
            for key in ("title", "body")
            if proposal.get(key) is not None
        }
    if resolved_edits:
        payload["edits"] = resolved_edits
    return await chat_service.send_message(
        message,
        conversation_id=proposed_turn["conversation_id"],
        write_confirmation=payload,
    )


async def save_message_with_confirmation(chat_service, message: str) -> dict[str, Any]:
    proposed = await chat_service.send_message(message)
    if (proposed.get("memory_changes") or {}).get("confirmation_required"):
        return await confirm_durable_write(chat_service, proposed)
    return proposed
