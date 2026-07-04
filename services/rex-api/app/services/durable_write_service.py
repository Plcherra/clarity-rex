"""Confirm, reject, and apply durable write pending actions."""

from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import MemoryDisciplineDecision
from app.services.conversation_pending_action import (
    ConversationPendingActionService,
    PendingAction,
    is_delete_confirmation_message,
    is_delete_rejection_message,
)
from app.services.durable_write_applier import DurableWriteApplier
from app.services.durable_write_builders import (
    proposal_from_discipline_decision,
    proposal_from_goal_command,
    proposal_from_memory_update,
    proposal_from_open_thread,
    proposal_from_simple_memory,
)
from app.services.durable_write_pending import (
    pending_action_for_durable_write,
    proposal_from_pending_action,
    write_confirmation_edits,
)
from app.services.durable_write_proposal import DurableWriteProposal
from app.services.durable_write_results import (
    applied_memory_changes,
    failed_memory_changes,
    pending_memory_changes,
    rejected_memory_changes,
)
from app.services.goal_command_formatting import goal_title
from app.services.goal_command_results import clarification_turn_result
from app.services.goal_command_types import GoalCommand
from app.services.memory_intent_service import SimpleMemoryIntent
from app.services.plan_service import PlanService


class DurableWriteService:
    def __init__(
        self,
        memory_service: Any,
        *,
        plan_service: Optional[PlanService] = None,
        applier: Optional[DurableWriteApplier] = None,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)
        self.applier = applier or DurableWriteApplier(
            memory_service,
            plan_service=self.plan_service,
        )

    async def propose_simple_memory(
        self,
        intent: SimpleMemoryIntent,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        proposal = proposal_from_simple_memory(intent)
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
        )

    async def propose_memory_update(
        self,
        intent: SimpleMemoryIntent,
        *,
        record_id: str,
        previous_content: str | None,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        proposal = proposal_from_memory_update(
            intent,
            record_id=record_id,
            previous_content=previous_content,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
        )

    async def propose_goal(
        self,
        command: GoalCommand,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        proposal = await proposal_from_goal_command(
            command,
            plan_service=self.plan_service,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
        )

    async def propose_open_thread(
        self,
        *,
        title: str,
        summary: str | None,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        proposal = proposal_from_open_thread(
            title=title,
            summary=summary,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
        )

    async def propose_discipline_decision(
        self,
        decision: MemoryDisciplineDecision,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        title = goal_title(
            str(
                decision.payload.get("title")
                or decision.payload.get("description")
                or decision.payload.get("desired_outcome")
                or "this plan"
            )
        )
        proposal = proposal_from_discipline_decision(decision, title=title)
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
        )

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

        confirmed = write_confirmation is not None or is_delete_confirmation_message(
            message
        )
        rejected = is_delete_rejection_message(message)
        if not confirmed and not rejected:
            return None

        if confirmed:
            if write_confirmation is not None:
                confirmed_id = str(
                    (write_confirmation or {}).get("proposal_id") or ""
                ).strip()
                if confirmed_id and confirmed_id != proposal.proposal_id:
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

    async def _propose(
        self,
        proposal: DurableWriteProposal,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        supersede_note = await self._pending().set_superseding(
            conversation_id,
            pending_action_for_durable_write(proposal=proposal),
        )
        # The write_proposal card is the confirmation contract; avoid duplicating it in chat text.
        prompt = supersede_note or ""
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=prompt,
            memory_changes=pending_memory_changes(proposal=proposal),
        )

    async def _apply(
        self,
        proposal: DurableWriteProposal,
        *,
        pending: PendingAction,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        result = await self.applier.apply_proposal(
            proposal,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        if not result.get("applied"):
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    f"I understood what you wanted to save about {proposal.title}, "
                    "but I couldn't save it just now. Please try again in a moment."
                ),
                memory_changes=failed_memory_changes(proposal=proposal),
            )

        await self._pending().clear(conversation_id)
        record = result.get("record") or {}
        saved = _saved_response(proposal, record=record, merged=bool(result.get("merged")))
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=saved,
            memory_changes=applied_memory_changes(
                proposal=proposal,
                record=record,
                merged=bool(result.get("merged")),
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
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=f"Okay, I won't save {proposal.title}.",
            memory_changes=rejected_memory_changes(proposal=proposal),
        )

    def _pending(self) -> ConversationPendingActionService:
        return ConversationPendingActionService(self.memory_service)


def _saved_response(
    proposal: DurableWriteProposal,
    *,
    record: dict[str, Any],
    merged: bool,
) -> str:
    if proposal.write_kind == "memory":
        snapshot_type = str(proposal.apply_snapshot.get("type") or "")
        if snapshot_type == "memory_update":
            return f"Updated Clarity Knows: {proposal.title}"
        return f"Saved to Clarity Knows: {proposal.title}"
    if merged and proposal.merge_target_title:
        return f"Updated existing plan \"{proposal.merge_target_title}\" with that context."
    if proposal.write_kind == "plan":
        return f"Saved plan in Goals: {proposal.title}"
    if proposal.write_kind == "open_thread":
        return (
            f"Tracking as an open thread in Goals: {proposal.title}. "
            "This is companion follow-up — not saved memory."
        )
    if proposal.write_kind == "milestone":
        target = proposal.target_label or "your plan"
        return f"Saved milestone under {target}: {proposal.title}"
    return f"Saved {proposal.title}."
