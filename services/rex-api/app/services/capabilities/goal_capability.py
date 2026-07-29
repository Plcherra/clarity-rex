"""Create / update / delete goal body handlers (durable write propose/apply)."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.body_display_text import clarification_turn_result, goal_title
from app.services.brain_action_schema import BrainAction
from app.services.capabilities.goal_action_payload import (
    delete_goal_fields_from_payload,
    goal_command_from_payload,
    update_goal_fields_from_payload,
)
from app.services.capabilities.goal_capability_support import (
    BAD_CREATE_REPLY,
    BAD_DELETE_REPLY,
    BAD_UPDATE_REPLY,
    apply_goal_proposal,
    resolve_plan_by_id_or_reference,
    with_assistant_reply,
)
from app.services.capabilities.suggestion_handling import suggestion_handling_plan
from app.services.durable_write_builders import (
    proposal_from_goal_command,
    proposal_from_goal_update,
    proposal_from_record_delete,
)
from app.services.grok_continuing_reply import continuing_reply_for_propose
from app.services.memory_delete_resolver import GOAL_DELETE_SCOPE
from app.services.memory_reference_models import KnowsReferenceMatch

_GOAL_ACTIONS = frozenset({"create_goal", "update_goal", "delete_goal"})


def is_goal_action(action: BrainAction) -> bool:
    return action.name in _GOAL_ACTIONS


async def handle_goal_action(
    action: BrainAction,
    *,
    durable_write_service,
    settings: AssistantProposalSettings,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]] = None,
    assistant_reply: str = "",
) -> Optional[dict]:
    if not is_goal_action(action):
        return None

    payload = dict(action.payload) if isinstance(action.payload, dict) else {}
    mode_plan = suggestion_handling_plan(settings)
    common = dict(
        payload=payload,
        durable_write_service=durable_write_service,
        settings=settings,
        mode_plan=mode_plan,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        assistant_reply=assistant_reply,
    )
    if action.name == "create_goal":
        return await _handle_create_goal(**common)
    if action.name == "update_goal":
        return await _handle_update_goal(**common)
    if action.name == "delete_goal":
        return await _handle_delete_goal(**common)
    return None


async def _handle_create_goal(
    *,
    payload: dict[str, Any],
    durable_write_service,
    settings: AssistantProposalSettings,
    mode_plan,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]],
    assistant_reply: str,
) -> dict:
    command = goal_command_from_payload(payload)
    if command is None:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, BAD_CREATE_REPLY),
        )

    if mode_plan.apply_immediately:
        proposal = await proposal_from_goal_command(
            command,
            plan_service=durable_write_service.plan_service,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        return await apply_goal_proposal(
            proposal,
            durable_write_service=durable_write_service,
            conversation_id=conversation_id,
            user_message=user_message,
            assistant_reply=assistant_reply,
        )

    reply = continuing_reply_for_propose(
        assistant_reply,
        surface_client_cards=mode_plan.surface_client_cards,
    )
    return await durable_write_service.propose_goal(
        command,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )


async def _handle_update_goal(
    *,
    payload: dict[str, Any],
    durable_write_service,
    settings: AssistantProposalSettings,
    mode_plan,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]],
    assistant_reply: str,
) -> dict:
    fields = update_goal_fields_from_payload(payload)
    if fields is None:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, BAD_UPDATE_REPLY),
        )

    resolved = await resolve_plan_by_id_or_reference(
        durable_write_service.memory_service,
        plan_id=fields.plan_id,
        reference=fields.reference,
    )
    if isinstance(resolved, str):
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, resolved),
        )

    existing = resolved.record if isinstance(resolved.record, dict) else {}
    existing_title = str(existing.get("title") or resolved.title).strip()
    new_title = goal_title(fields.title) if fields.title else existing_title
    new_body = fields.body
    if new_body is None:
        new_body = str(
            existing.get("description")
            or existing.get("desired_outcome")
            or ""
        ).strip() or None

    if mode_plan.apply_immediately:
        proposal = proposal_from_goal_update(
            plan_id=resolved.id,
            title=new_title,
            body=new_body,
            existing_title=existing_title,
            target_date=fields.target_date,
            status=fields.status,
        )
        return await apply_goal_proposal(
            proposal,
            durable_write_service=durable_write_service,
            conversation_id=conversation_id,
            user_message=user_message,
            assistant_reply=assistant_reply,
        )

    reply = continuing_reply_for_propose(
        assistant_reply,
        surface_client_cards=mode_plan.surface_client_cards,
    )
    return await durable_write_service.propose_goal_update(
        plan_id=resolved.id,
        title=new_title,
        body=new_body,
        existing_title=existing_title,
        target_date=fields.target_date,
        status=fields.status,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )


async def _handle_delete_goal(
    *,
    payload: dict[str, Any],
    durable_write_service,
    settings: AssistantProposalSettings,
    mode_plan,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]],
    assistant_reply: str,
) -> dict:
    fields = delete_goal_fields_from_payload(payload)
    if fields is None:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, BAD_DELETE_REPLY),
        )

    resolved = await resolve_plan_by_id_or_reference(
        durable_write_service.memory_service,
        plan_id=fields.plan_id,
        reference=fields.reference,
    )
    if isinstance(resolved, str):
        reply = BAD_DELETE_REPLY if resolved == BAD_UPDATE_REPLY else resolved
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, reply),
        )

    match = KnowsReferenceMatch(
        table=resolved.table,
        id=resolved.id,
        title=resolved.title,
        record=resolved.record,
        action="would_delete",
    )

    if mode_plan.apply_immediately:
        proposal = proposal_from_record_delete(
            match,
            resolver_target=match.title,
            scope_tables=GOAL_DELETE_SCOPE,
        )
        return await apply_goal_proposal(
            proposal,
            durable_write_service=durable_write_service,
            conversation_id=conversation_id,
            user_message=user_message,
            assistant_reply=assistant_reply,
        )

    reply = continuing_reply_for_propose(
        assistant_reply,
        surface_client_cards=mode_plan.surface_client_cards,
    )
    return await durable_write_service.propose_delete(
        match,
        resolver_target=match.title,
        scope_tables=GOAL_DELETE_SCOPE,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )
