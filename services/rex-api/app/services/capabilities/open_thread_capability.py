"""Open-thread create/update body handler (durable write propose)."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.body_display_text import clarification_turn_result
from app.services.brain_action_schema import BrainAction
from app.services.grok_continuing_reply import continuing_reply_for_propose
from app.services.open_thread_service import OpenThreadService

_OPEN_THREAD_ACTIONS = frozenset({"create_open_thread", "update_open_thread"})

_LIST_FAILED_REPLY = (
    "I couldn't load your open threads just now, so I won't create or change "
    "one until that works again. Please try once more in a moment."
)

_NO_UPDATE_TARGET_REPLY = (
    "I don't see an active open thread to update. Tell me which habit to track "
    "and I can create one after you confirm."
)

_DELETE_NOT_WIRED_REPLY = (
    "I can't delete an open thread from chat yet. Close it in Goals, or tell me "
    "which thread to update instead."
)

_BAD_PAYLOAD_REPLY = (
    "I couldn't tell which open-thread change to make. Give me a short title "
    "for the habit and I'll confirm before saving."
)


def is_open_thread_action(action: BrainAction) -> bool:
    return action.name in _OPEN_THREAD_ACTIONS


def is_delete_open_thread_action(action: BrainAction) -> bool:
    return action.name == "delete_open_thread"


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
    """Propose create/update while keeping Grok's conversational reply.

    Gate is authority: Text/Card auto offers, or Off + explicit commands.
    Card = confirm card; Text and Off+explicit = say-yes (no card).
    """
    if not is_open_thread_action(action):
        return None

    payload = dict(action.payload) if isinstance(action.payload, dict) else {}
    try:
        threads = await _list_active_threads(durable_write_service.memory_service)
    except Exception:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=_LIST_FAILED_REPLY,
        )

    resolved = _resolve_create_or_update(
        action_name=action.name,
        payload=payload,
        threads=threads,
    )
    if resolved is None:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=_BAD_PAYLOAD_REPLY,
        )
    mode, thread_id, title, summary, existing_title = resolved
    if mode == "ask_which":
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=_ask_which_thread_reply(assistant_reply, threads),
        )
    if mode == "no_target":
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=_NO_UPDATE_TARGET_REPLY,
        )

    # Off+explicit and Text: say-yes only. Card: client confirm cards.
    surface_client_cards = settings.uses_confirm_cards()
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


async def handle_delete_open_thread_action(
    *,
    durable_write_service,
    conversation_id: str,
    user_message: dict,
) -> dict:
    """Honest reply when Grok emits delete_open_thread (not body-wired yet)."""
    return await clarification_turn_result(
        durable_write_service.memory_service,
        conversation_id=conversation_id,
        user_message=user_message,
        response=_DELETE_NOT_WIRED_REPLY,
    )


def _resolve_create_or_update(
    *,
    action_name: str,
    payload: dict,
    threads: list[dict],
) -> Optional[tuple[str, Optional[str], str, Optional[str], Optional[str]]]:
    """Return (mode, thread_id, title, summary, existing_title).

    mode is create | update | ask_which | no_target.
    """
    title = _title_from_payload(payload)
    if not title:
        return None
    summary = _optional_str(payload.get("summary"))
    thread_id = _optional_str(payload.get("thread_id"))

    if action_name == "update_open_thread" or thread_id:
        if not thread_id and len(threads) == 1:
            thread_id = _optional_str(threads[0].get("id"))
        if not thread_id and len(threads) > 1:
            return ("ask_which", None, title, summary, None)
        if not thread_id:
            return ("no_target", None, title, summary, None)
        existing_title = _existing_title_for(
            threads,
            thread_id=thread_id,
            payload=payload,
        )
        return ("update", thread_id, title, summary, existing_title)

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
    """List active threads; let failures propagate (never pretend empty)."""
    return await OpenThreadService(memory_service).list_active_threads()


def _ask_which_thread_reply(assistant_reply: str, threads: list[dict]) -> str:
    titles = [
        str(thread.get("title") or "").strip()
        for thread in threads
        if str(thread.get("title") or "").strip()
    ]
    listed = "; ".join(titles[:5]) if titles else "your active threads"
    base = str(assistant_reply or "").strip()
    ask = (
        f"Which open thread should I update? You have: {listed}. "
        "Reply with the title (or id) and I'll confirm before changing it."
    )
    if base and "which" in base.lower() and "thread" in base.lower():
        return base
    if base:
        return f"{base}\n\n{ask}"
    return ask


def _existing_title_for(
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
