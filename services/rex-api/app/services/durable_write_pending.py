"""Pending action helpers for durable write proposals."""

from __future__ import annotations

from typing import Any, Optional

from app.services.conversation_pending_action import PendingAction
from app.services.durable_write_proposal import DurableWriteProposal


def pending_action_for_durable_write(*, proposal: DurableWriteProposal) -> PendingAction:
    return PendingAction(
        action_type="durable_write",
        target_type=proposal.write_kind,
        target_id="",
        target_label=proposal.title,
        resolver_target=proposal.proposal_id,
        context={"durable_write_proposal": proposal.to_dict()},
    )


def proposal_from_pending_action(
    pending_action: PendingAction | dict | None,
) -> Optional[DurableWriteProposal]:
    if pending_action is None:
        return None
    if isinstance(pending_action, PendingAction):
        context = pending_action.context
        action_type = pending_action.action_type
    elif isinstance(pending_action, dict):
        context = pending_action.get("context") or {}
        action_type = str(pending_action.get("action_type") or "")
    else:
        return None
    if action_type != "durable_write":
        return None
    raw = context.get("durable_write_proposal") if isinstance(context, dict) else None
    if not isinstance(raw, dict):
        return None
    return DurableWriteProposal.from_dict(raw)


def write_confirmation_edits(raw: Any) -> Optional[dict[str, Any]]:
    if not isinstance(raw, dict):
        return None
    edits = raw.get("edits")
    if isinstance(edits, dict):
        return dict(edits)
    cleaned = {key: raw[key] for key in ("title", "body") if key in raw}
    return cleaned or None
