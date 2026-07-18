"""Open-thread create/update body handler (durable write propose/apply)."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_OFF,
    AssistantProposalSettings,
)
from app.services.brain_action_schema import BrainAction
from app.services.grok_continuing_reply import (
    continuing_reply_for_apply,
    continuing_reply_for_propose,
)
from app.services.open_thread_service import OpenThreadService
from app.services.open_thread_user_intent import classify_open_thread_user_intent

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
    assistant_reply: str = "",
) -> Optional[dict]:
    """Propose or apply create/update while keeping Grok's conversational reply."""
    if not is_open_thread_action(action):
        return None

    payload = dict(action.payload) if isinstance(action.payload, dict) else {}
    user_text = str(user_message.get("content") or "")
    user_intent = classify_open_thread_user_intent(user_text)
    resolved = await _resolve_create_or_update(
        durable_write_service.memory_service,
        action_name=action.name,
        payload=payload,
    )
    if resolved is None:
        return None
    mode, thread_id, title, summary, existing_title = resolved

    # Off + imperative command → apply immediately (user already commanded).
    if settings.mode == AUTO_PROPOSALS_OFF and user_intent == "command":
        applied_reply = continuing_reply_for_apply(assistant_reply, title=title)
        if mode == "update":
            return await durable_write_service.apply_open_thread_update_consent(
                thread_id=thread_id or "",
                title=title,
                summary=summary,
                conversation_id=conversation_id,
                user_message=user_message,
                conversation_messages=conversation_messages,
                existing_title=existing_title,
                response=applied_reply,
            )
        return await durable_write_service.apply_open_thread_consent(
            title=title,
            summary=summary,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            response=applied_reply,
        )

    surface_client_cards = _surface_cards(settings, user_intent=user_intent)
    reply = continuing_reply_for_propose(
        assistant_reply,
        surface_client_cards=surface_client_cards,
    )
    if mode == "update":
        return await durable_write_service.propose_open_thread_update(
            thread_id=thread_id or "",
            title=title,
            summary=summary,
            existing_title=existing_title,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            proposal_settings=settings,
            surface_client_cards=surface_client_cards,
            response=reply,
        )
    return await durable_write_service.propose_open_thread(
        title=title,
        summary=summary,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=surface_client_cards,
        response=reply,
    )


def _surface_cards(
    settings: AssistantProposalSettings,
    *,
    user_intent: str,
) -> bool:
    if settings.uses_confirm_cards():
        return True
    if settings.uses_text_offers():
        return False
    if settings.mode == AUTO_PROPOSALS_OFF and user_intent == "ask":
        return False
    return False


async def _resolve_create_or_update(
    memory_service: Any,
    *,
    action_name: str,
    payload: dict,
) -> Optional[tuple[str, Optional[str], str, Optional[str], Optional[str]]]:
    """Return (mode, thread_id, title, summary, existing_title)."""
    title = _title_from_payload(payload)
    if not title:
        return None
    summary = _optional_str(payload.get("summary"))
    threads = await _list_active_threads(memory_service)
    thread_id = _optional_str(payload.get("thread_id"))

    if action_name == "update_open_thread" or thread_id:
        if not thread_id and len(threads) == 1:
            thread_id = _optional_str(threads[0].get("id"))
        if not thread_id:
            return None
        existing_title = await _existing_title_for(
            threads,
            thread_id=thread_id,
            payload=payload,
        )
        return ("update", thread_id, title, summary, existing_title)

    # create_open_thread: if only one active thread, update it instead of duplicating.
    if len(threads) == 1:
        sole = threads[0]
        sole_id = _optional_str(sole.get("id"))
        if sole_id:
            return (
                "update",
                sole_id,
                title,
                summary,
                _optional_str(sole.get("title")),
            )
    return ("create", None, title, summary, None)


async def _list_active_threads(memory_service: Any) -> list[dict]:
    try:
        return await OpenThreadService(memory_service).list_active_threads()
    except Exception:
        return []


async def _existing_title_for(
    threads: list[dict],
    *,
    thread_id: str,
    payload: dict,
) -> Optional[str]:
    from_payload = _optional_str(payload.get("existing_title"))
    if from_payload:
        return from_payload
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
