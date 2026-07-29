"""Delete Knows item handler."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.body_display_text import clarification_turn_result
from app.services.capabilities.memory_action_payload import (
    DeleteKnowsPayload,
    delete_id_from_payload,
    delete_reference_from_payload,
)
from app.services.capabilities.memory_capability_support import (
    BAD_DELETE_REPLY,
    DELETE_AMBIGUOUS_REPLY,
    DELETE_NOT_FOUND_REPLY,
    apply_memory_proposal,
    with_assistant_reply,
)
from app.services.durable_write_builders import proposal_from_record_delete
from app.services.grok_continuing_reply import continuing_reply_for_propose
from app.services.memory_delete_resolver import MEMORY_DELETE_SCOPE
from app.services.memory_reference_models import KnowsReferenceMatch
from app.services.memory_reference_resolver import MemoryReferenceResolver
from app.services.memory_text_normalization import normalized_text


async def handle_delete_knows_item(
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
    resolved = await resolve_delete_target(
        durable_write_service.memory_service,
        payload,
    )
    if isinstance(resolved, str):
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=with_assistant_reply(assistant_reply, resolved),
        )

    if mode_plan.apply_immediately:
        proposal = proposal_from_record_delete(
            resolved.match,
            resolver_target=resolved.resolver_target,
            scope_tables=resolved.scope_tables,
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
        surface="knows",
    )
    return await durable_write_service.propose_delete(
        resolved.match,
        resolver_target=resolved.resolver_target,
        scope_tables=resolved.scope_tables,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
        response=reply,
    )


async def resolve_delete_target(
    memory_service: Any,
    payload: dict[str, Any],
) -> DeleteKnowsPayload | str:
    record_id, table = delete_id_from_payload(payload)
    if record_id and table:
        if table not in MEMORY_DELETE_SCOPE:
            return BAD_DELETE_REPLY
        return DeleteKnowsPayload(
            match=KnowsReferenceMatch(
                table=table,
                id=record_id,
                title=str(payload.get("title") or record_id),
                record={},
                action="would_delete",
            ),
            resolver_target=str(payload.get("title") or record_id),
        )

    reference = delete_reference_from_payload(payload)
    if not reference:
        return BAD_DELETE_REPLY

    resolver = MemoryReferenceResolver(memory_service)
    matches = await resolver.resolve_knows_delete_reference(reference)
    knows_matches = [
        match for match in matches if match.table in MEMORY_DELETE_SCOPE
    ]
    if not knows_matches:
        return DELETE_NOT_FOUND_REPLY
    if len(knows_matches) > 1:
        exact = [
            match
            for match in knows_matches
            if normalized_text(match.title) == normalized_text(reference)
        ]
        if len(exact) == 1:
            knows_matches = exact
        else:
            return DELETE_AMBIGUOUS_REPLY
    match = knows_matches[0]
    return DeleteKnowsPayload(
        match=match,
        resolver_target=match.title or reference,
    )
