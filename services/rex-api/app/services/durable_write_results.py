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
    records: list[dict[str, Any]] | None = None,
    updated_count: int | None = None,
) -> dict[str, Any]:
    snapshot_type = str(proposal.apply_snapshot.get("type") or "")
    is_bulk = snapshot_type == "bulk_plan_target_date"
    is_delete = proposal.write_kind == "delete" or snapshot_type == "record_delete"
    bulk_records = records or ([record] if record else [])
    is_update = (
        not is_delete
        and (
            proposal.write_kind.startswith("update_")
            or snapshot_type
            in {
                "memory_update",
                "update_plan",
                "update_milestone",
                "bulk_plan_target_date",
            }
        )
    )
    created = 0 if is_update or merged or is_delete else 1
    updated = updated_count if updated_count is not None else (1 if is_update else 0)
    card = proposal.to_client_dict(status="applied")
    if is_bulk and bulk_records:
        card["result"] = [
            _applied_record_result(proposal, record=item, merged=False)
            for item in bulk_records
        ]
    else:
        card["result"] = [_applied_record_result(proposal, record=record, merged=merged)]
    return _envelope(
        created=created,
        updated=updated,
        archived=1 if is_delete else 0,
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
    if proposal.write_kind == "delete":
        action = "deleted"
    if merged:
        action = "merged"
    return {
        "id": record.get("id"),
        "title": record.get("title") or record.get("content") or proposal.title,
        "action": action,
        "write_kind": proposal.write_kind,
    }
