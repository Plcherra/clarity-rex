"""Save / update flat memory and save person card handlers."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.body_display_text import clarification_turn_result
from app.services.capabilities.memory_action_payload import (
    memory_update_record_id,
    simple_memory_intent_from_payload,
)
from app.services.capabilities.memory_capability_support import (
    BAD_MEMORY_REPLY,
    BAD_PERSON_REPLY,
    apply_memory_proposal,
    with_assistant_reply,
)
from app.services.durable_write_builders import (
    proposal_from_memory_update,
    proposal_from_simple_memory,
)
from app.services.grok_continuing_reply import continuing_reply_for_propose


async def handle_save_memory_or_person(
    *,
    action_name: str,
    payload: dict[str, Any],
    durable_write_service,
    settings: AssistantProposalSettings,
    mode_plan,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]],
    assistant_reply: str,
) -> dict:
    for_person = action_name == "save_person"
    intent = simple_memory_intent_from_payload(payload, for_person=for_person)
    if intent is None:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(
                assistant_reply,
                BAD_PERSON_REPLY if for_person else BAD_MEMORY_REPLY,
            ),
        )

    if mode_plan.apply_immediately:
        related = {}
        if for_person:
            related = await durable_write_service._related_person_context(intent)
        proposal = proposal_from_simple_memory(
            intent,
            related=related,
            use_person_card=for_person,
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
    return await durable_write_service.propose_simple_memory(
        intent,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        use_person_card=for_person,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )


async def handle_update_memory(
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
    intent = simple_memory_intent_from_payload(payload, for_person=False)
    record_id = memory_update_record_id(payload)
    if intent is None or not record_id:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, BAD_MEMORY_REPLY),
        )

    previous = str(payload.get("previous_content") or "").strip() or None
    if mode_plan.apply_immediately:
        proposal = proposal_from_memory_update(
            intent,
            record_id=record_id,
            previous_content=previous,
            use_person_card=False,
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
    return await durable_write_service.propose_memory_update(
        intent,
        record_id=record_id,
        previous_content=previous,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        use_person_card=False,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )
