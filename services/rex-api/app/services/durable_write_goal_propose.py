"""Goal propose helpers mixed into DurableWriteService."""

from __future__ import annotations

from typing import Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.body_display_text import GoalCommand
from app.services.durable_write_builders import (
    proposal_from_goal_command,
    proposal_from_goal_update,
)


class DurableWriteGoalProposeMixin:
    """Propose create/update goal via durable write."""

    async def propose_goal(
        self,
        command: GoalCommand,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
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
            conversation_messages=conversation_messages,
            response=response,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )

    async def propose_goal_update(
        self,
        *,
        plan_id: str,
        title: str,
        body: str | None,
        existing_title: str | None,
        target_date: str | None = None,
        target_amount: float | None = None,
        status: str | None = None,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        proposal = proposal_from_goal_update(
            plan_id=plan_id,
            title=title,
            body=body,
            existing_title=existing_title,
            target_date=target_date,
            target_amount=target_amount,
            status=status,
        )
        return await self._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            response=response,
            proposal_settings=proposal_settings,
            surface_client_cards=surface_client_cards,
        )
