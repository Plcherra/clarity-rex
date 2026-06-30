"""Client-facing memory_changes payloads for durable write proposals."""

from __future__ import annotations

from typing import Any, Optional

from app.services.durable_write_proposal import DurableWriteProposal


def pending_memory_changes(*, proposal: DurableWriteProposal) -> dict[str, Any]:
    card = proposal.to_client_dict(status="pending")
    return _envelope(
        confirmation_required=1,
        proposals=[card],
    )


def applied_memory_changes(
    *,
    proposal: DurableWriteProposal,
    record: dict[str, Any],
    merged: bool = False,
) -> dict[str, Any]:
    is_update = proposal.write_kind.startswith("update_") or str(
        proposal.apply_snapshot.get("type") or ""
    ) in {"memory_update", "update_plan", "update_milestone", "update_commitment"}
    created = 0 if is_update or merged else 1
    updated = 1 if is_update else 0
    card = proposal.to_client_dict(status="applied")
    card["result"] = [_applied_record_result(proposal, record=record, merged=merged)]
    return _envelope(
        created=created,
        updated=updated,
        merged=1 if merged else 0,
        confirmation_required=0,
        proposals=[card],
        record=record,
    )


def rejected_memory_changes(*, proposal: DurableWriteProposal) -> dict[str, Any]:
    card = proposal.to_client_dict(status="dismissed")
    return _envelope(
        skipped=1,
        confirmation_required=0,
        proposals=[card],
    )


def failed_memory_changes(*, proposal: DurableWriteProposal) -> dict[str, Any]:
    card = proposal.to_client_dict(status="failed")
    return _envelope(
        confirmation_required=0,
        proposals=[card],
    )


def _envelope(
    *,
    created: int = 0,
    updated: int = 0,
    archived: int = 0,
    merged: int = 0,
    skipped: int = 0,
    confirmation_required: int = 0,
    proposals: list[dict[str, Any]],
    record: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "created": created,
        "updated": updated,
        "archived": archived,
        "merged": merged,
        "skipped": skipped,
        "confirmation_required": confirmation_required,
        "write_proposals": proposals,
        "plan_save_proposals": proposals,
    }
    if record is not None:
        payload["applied_record"] = {
            "id": record.get("id"),
            "title": record.get("title") or record.get("content"),
            "write_kind": proposals[0].get("write_kind") if proposals else None,
        }
    return payload


def _applied_record_result(
    proposal: DurableWriteProposal,
    *,
    record: dict[str, Any],
    merged: bool,
) -> dict[str, Any]:
    action = "direct_updated" if proposal.write_kind.startswith("update_") else "direct_saved"
    if merged:
        action = "merged"
    return {
        "id": record.get("id"),
        "title": record.get("title") or record.get("content") or proposal.title,
        "action": action,
        "write_kind": proposal.write_kind,
    }
