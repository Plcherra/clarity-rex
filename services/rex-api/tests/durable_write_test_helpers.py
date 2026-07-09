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
    proposal_id = None
    proposal: dict[str, Any] = {}
    if proposals:
        proposal = proposals[0]
        proposal_id = proposal.get("id") or "write-1"
    else:
        proposal_id = memory_changes.get("pending_proposal_id")
    if not proposal_id:
        raise AssertionError("Expected a pending write proposal to confirm.")
    payload: dict[str, Any] = {"proposal_id": proposal_id}
    resolved_edits = edits
    if resolved_edits is None:
        person_card = proposal.get("person_card")
        if isinstance(person_card, dict):
            resolved_edits = {
                key: str(person_card.get(key) or "").strip()
                for key in ("display_name", "relationship", "birthday", "notes")
                if str(person_card.get(key) or "").strip()
            }
        elif proposal.get("title") is not None or proposal.get("body") is not None:
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


def assert_companion_continuation_response(
    result: dict[str, Any],
    *,
    expected_response: str = "Rex response",
) -> None:
    """Confirmed durable writes return Grok companion continuation, not save ack text."""
    assert result["response"] == expected_response
