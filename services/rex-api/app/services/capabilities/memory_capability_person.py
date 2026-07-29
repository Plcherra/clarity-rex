"""Person state and note update handlers."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.body_display_text import clarification_turn_result
from app.services.capabilities.memory_action_payload import (
    person_note_text,
    person_state_text,
)
from app.services.capabilities.memory_capability_support import (
    BAD_NOTE_REPLY,
    BAD_STATE_REPLY,
    PERSON_NOT_FOUND_REPLY,
    apply_memory_proposal,
    entity_notes,
    resolve_person_target,
    with_assistant_reply,
)
from app.services.durable_write_builders import (
    proposal_from_person_note,
    proposal_from_person_state,
)
from app.services.grok_continuing_reply import continuing_reply_for_propose


async def handle_person_state(
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
    state = person_state_text(payload)
    target = await resolve_person_target(
        durable_write_service.memory_service,
        payload,
    )
    if target is None or not state:
        reply = PERSON_NOT_FOUND_REPLY if state else BAD_STATE_REPLY
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, reply),
        )

    if mode_plan.apply_immediately:
        proposal = proposal_from_person_state(
            entity_id=target.entity_id,
            display_name=target.display_name,
            state=state,
        )
        return await apply_memory_proposal(
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
    return await durable_write_service.propose_person_state(
        entity_id=target.entity_id,
        display_name=target.display_name,
        state=state,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )


async def handle_person_note(
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
    note = person_note_text(payload)
    target = await resolve_person_target(
        durable_write_service.memory_service,
        payload,
    )
    if target is None or not note:
        reply = PERSON_NOT_FOUND_REPLY if note else BAD_NOTE_REPLY
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, reply),
        )

    existing_notes = entity_notes(target.entity)
    replace = bool(payload.get("replace") is True)
    if mode_plan.apply_immediately:
        proposal = proposal_from_person_note(
            entity_id=target.entity_id,
            display_name=target.display_name,
            note=note,
            existing_notes=existing_notes,
            replace=replace,
        )
        return await apply_memory_proposal(
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
    return await durable_write_service.propose_person_note(
        entity_id=target.entity_id,
        display_name=target.display_name,
        note=note,
        existing_notes=existing_notes,
        replace=replace,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )
