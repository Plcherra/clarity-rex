"""Memory / person Knows body handler (durable write propose/apply)."""

from __future__ import annotations

from typing import Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.brain_action_schema import BrainAction
from app.services.capabilities.memory_capability_delete import handle_delete_knows_item
from app.services.capabilities.memory_capability_person import (
    handle_person_note,
    handle_person_state,
)
from app.services.capabilities.memory_capability_save import (
    handle_save_memory_or_person,
    handle_update_memory,
)
from app.services.capabilities.suggestion_handling import suggestion_handling_plan

_MEMORY_ACTIONS = frozenset(
    {
        "save_memory",
        "update_memory",
        "save_person",
        "update_person_state",
        "add_person_note",
        "delete_knows_item",
    }
)


def is_memory_action(action: BrainAction) -> bool:
    return action.name in _MEMORY_ACTIONS


async def handle_memory_action(
    action: BrainAction,
    *,
    durable_write_service,
    settings: AssistantProposalSettings,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]] = None,
    assistant_reply: str = "",
) -> Optional[dict]:
    if not is_memory_action(action):
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

    if action.name in {"save_memory", "save_person"}:
        return await handle_save_memory_or_person(
            action_name=action.name,
            **common,
        )
    if action.name == "update_memory":
        return await handle_update_memory(**common)
    if action.name == "update_person_state":
        return await handle_person_state(**common)
    if action.name == "add_person_note":
        return await handle_person_note(**common)
    if action.name == "delete_knows_item":
        return await handle_delete_knows_item(**common)
    return None
