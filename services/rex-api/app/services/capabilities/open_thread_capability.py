"""Open-thread create/update body handler (durable write propose)."""

from __future__ import annotations

from typing import Any, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.body_display_text import clarification_turn_result
from app.services.brain_action_schema import BrainAction
from app.services.capabilities.open_thread_matching import (
    ResolvedOpenThreadSuggestion,
    resolve_open_thread_suggestion,
)
from app.services.capabilities.suggestion_handling import suggestion_handling_plan
from app.services.durable_write_builders import (
    proposal_from_open_thread,
    proposal_from_open_thread_update,
)
from app.services.durable_write_results import (
    applied_memory_changes,
    failed_memory_changes,
)
from app.services.grok_continuing_reply import (
    continuing_reply_for_apply,
    continuing_reply_for_propose,
)
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
    "I need a short title for that open thread before I can save it. "
    "For example: \"Wake at 5:30am\"."
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

    Gate is authority: Text/Card auto offers, or Off + explicit:true only.
    Card = confirm card; Text = say-yes; Off = apply immediately (no confirm).
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
            response=_with_assistant_reply(assistant_reply, _LIST_FAILED_REPLY),
        )

    resolved = resolve_open_thread_suggestion(
        action_name=action.name,
        payload=payload,
        threads=threads,
        user_text=str(user_message.get("content") or ""),
    )
    if resolved is None:
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=_with_assistant_reply(assistant_reply, _BAD_PAYLOAD_REPLY),
        )
    mode_plan = suggestion_handling_plan(settings)
    mode = resolved.mode
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
            response=_with_assistant_reply(assistant_reply, _NO_UPDATE_TARGET_REPLY),
        )

    if mode_plan.apply_immediately:
        return await _apply_resolved_open_thread(
            resolved,
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
    if mode == "update":
        return await durable_write_service.propose_open_thread_update(
            thread_id=resolved.thread_id or "",
            title=resolved.title,
            summary=resolved.summary or resolved.existing_summary,
            existing_title=resolved.existing_title,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
            proposal_settings=settings,
            surface_client_cards=mode_plan.surface_client_cards,
            response=reply,
        )
    return await durable_write_service.propose_open_thread(
        title=resolved.title,
        summary=resolved.summary,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_messages,
        proposal_settings=settings,
        surface_client_cards=mode_plan.surface_client_cards,
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
    ask = (
        f"Which open thread should I update? You have: {listed}. "
        "Reply with the title (or id) and I'll confirm before changing it."
    )
    return _with_assistant_reply(assistant_reply, ask)


def _with_assistant_reply(assistant_reply: str, fallback: str) -> str:
    base = str(assistant_reply or "").strip()
    # Avoid stacking the same clarification twice.
    if base and fallback.lower() in base.lower():
        return base
    if base:
        return f"{base}\n\n{fallback}"
    return fallback


async def _apply_resolved_open_thread(
    resolved: ResolvedOpenThreadSuggestion,
    *,
    durable_write_service,
    conversation_id: str,
    user_message: dict,
    assistant_reply: str,
) -> dict:
    if resolved.mode == "update":
        proposal = proposal_from_open_thread_update(
            thread_id=resolved.thread_id or "",
            title=resolved.title,
            summary=resolved.summary or resolved.existing_summary,
            existing_title=resolved.existing_title,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
    else:
        proposal = proposal_from_open_thread(
            title=resolved.title,
            summary=resolved.summary,
            conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )

    result = await durable_write_service.applier.apply_proposal(
        proposal,
        conversation_id=conversation_id,
        source_message_id=str(user_message.get("id") or "") or None,
    )
    if not result.get("applied"):
        reason = str(result.get("reason") or "").strip() or None
        return await clarification_turn_result(
            durable_write_service.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=(
                f"I understood what you wanted to change about {proposal.title}, "
                "but I couldn't update it just now. Please try again in a moment."
            ),
            memory_changes=failed_memory_changes(
                proposal=proposal,
                reason=reason,
            ),
        )

    record = result.get("record") or {}
    records = result.get("records") or ([record] if record else [])
    updated_count = result.get("updated_count")
    return await clarification_turn_result(
        durable_write_service.memory_service,
        conversation_id=conversation_id,
        user_message=user_message,
        response=continuing_reply_for_apply(assistant_reply, title=proposal.title),
        memory_changes=applied_memory_changes(
            proposal=proposal,
            record=record,
            merged=bool(result.get("merged")),
            records=records,
            updated_count=updated_count,
        ),
    )


def _optional_str(value: Any) -> Optional[str]:
    text = str(value or "").strip()
    return text or None
