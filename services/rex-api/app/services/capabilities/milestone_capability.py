"""Create / update / delete milestone body handlers (durable write propose/apply)."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.body_display_text import clarification_turn_result
from app.services.brain_action_schema import BrainAction
from app.services.capabilities.milestone_action_payload import (
    create_milestone_fields_from_payload,
    delete_milestone_fields_from_payload,
    update_milestone_fields_from_payload,
)
from app.services.capabilities.milestone_capability_support import (
    BAD_CREATE_REPLY,
    BAD_DELETE_REPLY,
    BAD_UPDATE_REPLY,
    MILESTONE_DELETE_SCOPE,
    apply_milestone_proposal,
    milestone_title,
    resolve_milestone_by_id_or_reference,
    resolve_parent_plan,
    with_assistant_reply,
)
from app.services.capabilities.suggestion_handling import suggestion_handling_plan
from app.services.durable_write_builders import proposal_from_record_delete
from app.services.durable_write_milestone_builders import (
    proposal_from_milestone,
    proposal_from_milestone_update,
)
from app.services.grok_continuing_reply import continuing_reply_for_propose
from app.services.memory_reference_models import KnowsReferenceMatch

_MILESTONE_ACTIONS = frozenset(
    {"create_milestone", "update_milestone", "delete_milestone"}
)


def is_milestone_action(action: BrainAction) -> bool:
    return action.name in _MILESTONE_ACTIONS


async def handle_milestone_action(
    action: BrainAction,
    *,
    durable_write_service,
    settings: AssistantProposalSettings,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]] = None,
    assistant_reply: str = "",
) -> Optional[dict]:
    if not is_milestone_action(action):
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
    if action.name == "create_milestone":
        return await _handle_create_milestone(**common)
    if action.name == "update_milestone":
        return await _handle_update_milestone(**common)
    if action.name == "delete_milestone":
        return await _handle_delete_milestone(**common)
    return None


async def _handle_create_milestone(
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
    fields = create_milestone_fields_from_payload(payload)
    if fields is None:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, BAD_CREATE_REPLY),
        )

    parent = await resolve_parent_plan(
        durable_write_service.memory_service,
        plan_id=fields.plan_id,
        parent_reference=fields.parent_reference,
        list_when_missing=True,
    )
    if isinstance(parent, str):
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, parent),
        )

    title = milestone_title(fields.title)
    if mode_plan.apply_immediately:
        proposal = proposal_from_milestone(
            plan_id=parent.id,
            title=title,
            description=fields.description,
            parent_title=parent.title,
            target_date=fields.target_date,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        return await apply_milestone_proposal(
            proposal,
            durable_write_service=durable_write_service,
            conversation_id=conversation_id,
            user_message=user_message,
            assistant_reply=assistant_reply,
        )

    reply = continuing_reply_for_propose(
        assistant_reply,
        surface_client_cards=mode_plan.surface_client_cards,
        surface="goals",
    )
    return await durable_write_service.propose_milestone(
        plan_id=parent.id,
        title=title,
        description=fields.description,
        parent_title=parent.title,
        target_date=fields.target_date,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )


async def _handle_update_milestone(
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
    fields = update_milestone_fields_from_payload(payload)
    if fields is None:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, BAD_UPDATE_REPLY),
        )

    resolved = await resolve_milestone_by_id_or_reference(
        durable_write_service.memory_service,
        milestone_id=fields.milestone_id,
        reference=fields.reference,
        plan_id=fields.plan_id,
        parent_reference=fields.parent_reference,
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
    new_title = milestone_title(fields.title) if fields.title else existing_title
    new_description = fields.description
    if new_description is None:
        new_description = str(existing.get("description") or "").strip() or None
    parent_title = await _parent_title_for_milestone(
        durable_write_service.memory_service,
        existing,
    )

    if mode_plan.apply_immediately:
        proposal = proposal_from_milestone_update(
            milestone_id=resolved.id,
            plan_id=str(existing.get("plan_id") or fields.plan_id or ""),
            title=new_title,
            description=new_description,
            existing_title=existing_title,
            parent_title=parent_title,
            target_date=fields.target_date,
            status=fields.status,
        )
        return await apply_milestone_proposal(
            proposal,
            durable_write_service=durable_write_service,
            conversation_id=conversation_id,
            user_message=user_message,
            assistant_reply=assistant_reply,
        )

    reply = continuing_reply_for_propose(
        assistant_reply,
        surface_client_cards=mode_plan.surface_client_cards,
        surface="goals",
    )
    return await durable_write_service.propose_milestone_update(
        milestone_id=resolved.id,
        plan_id=str(existing.get("plan_id") or fields.plan_id or ""),
        title=new_title,
        description=new_description,
        existing_title=existing_title,
        parent_title=parent_title,
        target_date=fields.target_date,
        status=fields.status,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )


async def _handle_delete_milestone(
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
    fields = delete_milestone_fields_from_payload(payload)
    if fields is None:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, BAD_DELETE_REPLY),
        )

    resolved = await resolve_milestone_by_id_or_reference(
        durable_write_service.memory_service,
        milestone_id=fields.milestone_id,
        reference=fields.reference,
        plan_id=fields.plan_id,
        parent_reference=fields.parent_reference,
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
            scope_tables=MILESTONE_DELETE_SCOPE,
        )
        return await apply_milestone_proposal(
            proposal,
            durable_write_service=durable_write_service,
            conversation_id=conversation_id,
            user_message=user_message,
            assistant_reply=assistant_reply,
        )

    reply = continuing_reply_for_propose(
        assistant_reply,
        surface_client_cards=mode_plan.surface_client_cards,
        surface="goals",
    )
    return await durable_write_service.propose_delete(
        match,
        resolver_target=match.title,
        scope_tables=MILESTONE_DELETE_SCOPE,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )


async def _parent_title_for_milestone(
    memory_service: Any, milestone: dict
) -> Optional[str]:
    plan_id = str(milestone.get("plan_id") or "").strip()
    if not plan_id:
        return None
    try:
        plans = await memory_service.list_plans(active=True, limit=100)
    except Exception:
        return None
    for plan in plans or []:
        if str(plan.get("id") or "") == plan_id:
            return str(plan.get("title") or "").strip() or None
    return None
