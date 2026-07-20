"""Pending action helpers for durable write proposals."""

from __future__ import annotations

from typing import Any, Optional

from app.services.conversation_pending_action import PendingAction
from app.services.durable_write_proposal import DurableWriteProposal


def pending_action_for_durable_write(
    *,
    proposal: DurableWriteProposal,
    surface_client_cards: bool | None = None,
) -> PendingAction:
    context: dict[str, Any] = {"durable_write_proposal": proposal.to_dict()}
    if surface_client_cards is not None:
        # Freeze propose-time UI surface so hydrate does not follow later settings.
        context["surface_client_cards"] = bool(surface_client_cards)
    return PendingAction(
        action_type="durable_write",
        target_type=proposal.write_kind,
        target_id="",
        target_label=proposal.title,
        resolver_target=proposal.proposal_id,
        context=context,
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


def surface_client_cards_from_pending(
    pending_action: PendingAction | dict | None,
) -> bool | None:
    """Propose-time card surface, or None when older pendings omit the flag."""
    if pending_action is None:
        return None
    if isinstance(pending_action, PendingAction):
        context = pending_action.context
    elif isinstance(pending_action, dict):
        context = pending_action.get("context") or {}
    else:
        return None
    if not isinstance(context, dict) or "surface_client_cards" not in context:
        return None
    return bool(context.get("surface_client_cards"))


def write_confirmation_edits(raw: Any) -> Optional[dict[str, Any]]:
    if not isinstance(raw, dict):
        return None
    edits = raw.get("edits")
    if isinstance(edits, dict):
        return dict(edits)
    person_keys = ("display_name", "relationship", "birthday", "notes")
    cleaned = {
        key: raw[key]
        for key in ("title", "body", *person_keys)
        if key in raw
    }
    return cleaned or None
