"""Milestone propose helpers mixed into DurableWriteService."""

from __future__ import annotations

from typing import Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.durable_write_milestone_builders import (
    proposal_from_milestone,
    proposal_from_milestone_update,
)


class DurableWriteMilestoneProposeMixin:
    """Propose create/update milestone via durable write."""

    async def propose_milestone(
        self,
        *,
        plan_id: str,
        title: str,
        description: str | None,
        parent_title: str | None,
        target_date: str | None = None,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        proposal = proposal_from_milestone(
            plan_id=plan_id,
            title=title,
            description=description,
            parent_title=parent_title,
            target_date=target_date,
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

    async def propose_milestone_update(
        self,
        *,
        milestone_id: str,
        plan_id: str,
        title: str,
        description: str | None,
        existing_title: str | None,
        parent_title: str | None = None,
        target_date: str | None = None,
        status: str | None = None,
        conversation_id: str,
        user_message: dict,
        conversation_messages: Optional[list[dict]] = None,
        response: str | None = None,
        proposal_settings: Optional[AssistantProposalSettings] = None,
        surface_client_cards: Optional[bool] = None,
    ) -> dict:
        proposal = proposal_from_milestone_update(
            milestone_id=milestone_id,
            plan_id=plan_id,
            title=title,
            description=description,
            existing_title=existing_title,
            parent_title=parent_title,
            target_date=target_date,
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
