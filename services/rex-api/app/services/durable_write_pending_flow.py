"""Confirm / reject / apply pending durable writes."""

from __future__ import annotations

from typing import Any, Optional

from app.services.body_display_text import (
    clarification_turn_result,
    format_plan_target_date_label,
)
from app.services.conversation_pending_action import (
    PendingAction,
    is_affirmative_confirmation,
    is_delete_rejection_message,
)
from app.services.durable_write_pending import (
    proposal_from_pending_action,
    write_confirmation_edits,
)
from app.services.durable_write_proposal import DurableWriteProposal
from app.services.durable_write_results import (
    applied_memory_changes,
    failed_memory_changes,
    rejected_memory_changes,
)


class DurableWritePendingFlowMixin:
    """Confirm-card / say-yes apply path for DurableWriteService."""

    async def try_handle_pending(
        self,
        message: str,
        *,
        pending_action,
        conversation_id: str,
        user_message: dict,
        write_confirmation: Any = None,
    ) -> Optional[dict]:
        pending = (
            pending_action
            if isinstance(pending_action, PendingAction)
            else PendingAction.from_dict(pending_action)
        )
        if pending is None:
            return None

        if pending.action_type != "durable_write":
            return None

        proposal = proposal_from_pending_action(pending)
        if proposal is None:
            await self._pending().clear(conversation_id)
            return None

        confirmation_id = write_confirmation_proposal_id(write_confirmation)
        # Empty {} / missing proposal_id must not confirm — only an id match or
        # a typed yes does.
        confirmed = (
            confirmation_id == proposal.proposal_id
            if confirmation_id is not None
            else is_affirmative_confirmation(message)
        )
        rejected = is_delete_rejection_message(message)
        if not confirmed and not rejected:
            if confirmation_id is not None:
                await self._pending().clear(conversation_id)
                return await clarification_turn_result(
                    self.memory_service,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    response=(
                        "That save confirmation is no longer current. "
                        "Please use the latest save card or ask me to save again."
                    ),
                    memory_changes=failed_memory_changes(proposal=proposal),
                )
            return None

        if confirmed:
            edits = write_confirmation_edits(write_confirmation)
            return await self._apply(
                proposal.with_edits(edits),
                pending=pending,
                conversation_id=conversation_id,
                user_message=user_message,
            )
        if rejected:
            return await self._reject(
                proposal,
                conversation_id=conversation_id,
                user_message=user_message,
            )
        return None

    async def _apply(
        self,
        proposal: DurableWriteProposal,
        *,
        pending: PendingAction,
        conversation_id: str,
        user_message: dict,
        response: str | None = None,
    ) -> dict:
        if proposal.person_card is not None:
            from app.services.person_confirm_proposal import (
                person_card_blocks_apply,
                person_card_insufficient_fields_message,
            )

            if person_card_blocks_apply(proposal.person_card):
                return await clarification_turn_result(
                    self.memory_service,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    response=person_card_insufficient_fields_message(),
                    memory_changes=failed_memory_changes(
                        proposal=proposal,
                        reason="person_card_insufficient_fields",
                    ),
                )
        result = await self.applier.apply_proposal(
            proposal,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        if not result.get("applied"):
            failure_reason = str(result.get("reason") or "").strip() or None
            if proposal.write_kind == "delete":
                failure = (
                    f"I understood you wanted to delete {proposal.title}, "
                    "but I couldn't delete it just now. Please try again in a moment."
                )
            else:
                failure = (
                    f"I understood what you wanted to save about {proposal.title}, "
                    "but I couldn't save it just now. Please try again in a moment."
                )
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=failure,
                memory_changes=failed_memory_changes(
                    proposal=proposal,
                    reason=failure_reason,
                ),
            )

        await self._pending().clear(conversation_id)
        record = result.get("record") or {}
        records = result.get("records") or ([record] if record else [])
        updated_count = result.get("updated_count")
        saved = response or saved_response(
            proposal,
            record=record,
            merged=bool(result.get("merged")),
            updated_count=updated_count,
        )
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=saved,
            memory_changes=applied_memory_changes(
                proposal=proposal,
                record=record,
                merged=bool(result.get("merged")),
                records=records,
                updated_count=updated_count,
            ),
        )

    async def _reject(
        self,
        proposal: DurableWriteProposal,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        await self._pending().clear(conversation_id)
        verb = "delete" if proposal.write_kind == "delete" else "save"
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=f"Okay, I won't {verb} {proposal.title}.",
            memory_changes=rejected_memory_changes(proposal=proposal),
        )


def write_confirmation_proposal_id(raw: Any) -> str | None:
    """Non-empty proposal_id from write_confirmation, else None.

    Empty {} must not count as a confirmation.
    """
    if not isinstance(raw, dict):
        return None
    confirmed_id = str(raw.get("proposal_id") or "").strip()
    return confirmed_id or None


def saved_response(
    proposal: DurableWriteProposal,
    *,
    record: dict[str, Any],
    merged: bool,
    updated_count: int | None = None,
) -> str:
    snapshot_type = str(proposal.apply_snapshot.get("type") or "")
    if proposal.write_kind == "memory":
        if snapshot_type in {
            "memory_update",
            "person_state_update",
            "person_note_update",
        }:
            return f"Updated Clarity Knows: {proposal.title}"
        return f"Saved to Clarity Knows: {proposal.title}"
    if merged and proposal.merge_target_title:
        return f"Updated existing plan \"{proposal.merge_target_title}\" with that context."
    if proposal.write_kind == "update_plan":
        if snapshot_type == "bulk_plan_target_date":
            payload = dict(proposal.apply_snapshot.get("payload") or {})
            target_date = str(payload.get("target_date") or "")
            count = updated_count or len(payload.get("plans") or [])
            date_label = format_plan_target_date_label(target_date)
            return f"Updated target dates for {count} goals to {date_label}."
        if snapshot_type == "plan_update":
            return f"Updated goal in Goals: {proposal.title}"
    if proposal.write_kind == "plan":
        return f"Saved plan in Goals: {proposal.title}"
    if proposal.write_kind == "open_thread":
        if snapshot_type == "open_thread_update":
            return (
                f"Updated open thread in Goals: {proposal.title}. "
                "This is companion follow-up — not saved memory."
            )
        return (
            f"Tracking as an open thread in Goals: {proposal.title}. "
            "This is companion follow-up — not saved memory."
        )
    if proposal.write_kind == "milestone":
        target = proposal.target_label or "your plan"
        return f"Saved milestone under {target}: {proposal.title}"
    if proposal.write_kind == "delete":
        return f"Permanently deleted: {proposal.title}."
    return f"Saved {proposal.title}."
