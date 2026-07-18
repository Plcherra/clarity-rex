"""Open-thread create/update body handler (durable write propose)."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.brain_action_schema import BrainAction
from app.services.open_thread_service import OpenThreadService

_OPEN_THREAD_ACTIONS = frozenset({"create_open_thread", "update_open_thread"})


def is_open_thread_action(action: BrainAction) -> bool:
    return action.name in _OPEN_THREAD_ACTIONS


async def handle_open_thread_action(
    action: BrainAction,
    *,
    durable_write_service,
    settings: AssistantProposalSettings,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]] = None,
) -> Optional[dict]:
    """Propose create/update via DurableWriteService. None = skip (no propose)."""
    if not is_open_thread_action(action):
        return None

    payload = action.payload if isinstance(action.payload, dict) else {}
    # Confirm cards remain the truth path for durable writes (Text + Card + Off explicit).
    surface_client_cards = True

    if action.name == "create_open_thread":
        title = _title_from_payload(payload)
        if not title:
            return None
        summary = _optional_str(payload.get("summary"))
        return await durable_write_service.propose_open_thread(
            title=title,
            summary=summary,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            proposal_settings=settings,
            surface_client_cards=surface_client_cards,
        )

    thread_id = _optional_str(payload.get("thread_id"))
    if not thread_id:
        return None
    title = _title_from_payload(payload)
    if not title:
        return None
    summary = _optional_str(payload.get("summary"))
    existing_title = await _resolve_existing_title(
        durable_write_service.memory_service,
        thread_id=thread_id,
        payload=payload,
    )
    return await durable_write_service.propose_open_thread_update(
        thread_id=thread_id,
        title=title,
        summary=summary,
        existing_title=existing_title,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=surface_client_cards,
    )


async def _resolve_existing_title(
    memory_service: Any,
    *,
    thread_id: str,
    payload: dict,
) -> Optional[str]:
    from_payload = _optional_str(payload.get("existing_title"))
    if from_payload:
        return from_payload
    try:
        threads = await OpenThreadService(memory_service).list_active_threads()
    except Exception:
        return None
    for thread in threads:
        if str(thread.get("id") or "") == thread_id:
            return _optional_str(thread.get("title"))
    return None


def _title_from_payload(payload: dict) -> str:
    return (
        _optional_str(payload.get("title"))
        or _optional_str(payload.get("name"))
        or ""
    )


def _optional_str(value: Any) -> Optional[str]:
    text = str(value or "").strip()
    return text or None
