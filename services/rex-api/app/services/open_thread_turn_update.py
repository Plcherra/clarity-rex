"""Open-thread update offers (auto Text/Card) and explicit update commands."""

from __future__ import annotations

import re
from typing import Any, Optional

from app.services.assistant_proposal_settings import PROPOSAL_KIND_THREADS
from app.services.goal_command_results import clarification_turn_result
from app.services.open_thread_eligibility import (
    build_thread_description,
    has_specific_actionable_continuity,
    infer_thread_title,
    message_might_need_open_thread_offer,
)
from app.services.open_thread_overlap import (
    find_overlapping_active_thread,
    find_thread_for_explicit_update,
)


THREAD_UPDATE_ASK_MARKER = "Want me to change that open thread"
_EXPLICIT_THREAD_UPDATE_PATTERNS = (
    re.compile(
        r"\b(?:update|change|switch|edit)\b.{0,80}\b(?:open\s+)?thread\b",
        re.I,
    ),
    re.compile(
        r"\b(?:update|change|switch)\b.{0,40}\bmy\b.{0,40}\bthread\b.{0,40}\bto\b",
        re.I,
    ),
)


def is_explicit_thread_update_command(message: str) -> bool:
    cleaned = message.strip()
    if not cleaned:
        return False
    return any(pattern.search(cleaned) for pattern in _EXPLICIT_THREAD_UPDATE_PATTERNS)


def build_thread_update_ask(*, existing_title: str, new_title: str) -> str:
    old = existing_title.strip() or "that open thread"
    new = new_title.strip() or "the updated follow-up"
    return (
        f'You already have an open thread "{old}". '
        f'{THREAD_UPDATE_ASK_MARKER} to "{new}"?'
    )


def parse_update_offer_from_history(conversation_history: list[dict]) -> dict[str, Any]:
    for index, entry in enumerate(reversed(conversation_history)):
        if str(entry.get("role") or "") != "assistant":
            continue
        content = str(entry.get("content") or "")
        if THREAD_UPDATE_ASK_MARKER not in content:
            continue
        existing_title = ""
        new_title = ""
        match = re.search(
            r'open thread "([^"]+)".+to "([^"]+)"\?',
            content,
            flags=re.I | re.S,
        )
        if match:
            existing_title = match.group(1).strip()
            new_title = match.group(2).strip()
        abs_index = len(conversation_history) - 1 - index
        topic_message = ""
        for previous in reversed(conversation_history[:abs_index]):
            if str(previous.get("role") or "") != "user":
                continue
            candidate = str(previous.get("content") or "").strip()
            if candidate:
                topic_message = candidate
                break
        return {
            "offered": True,
            "existing_title": existing_title,
            "new_title": new_title,
            "topic_message": topic_message,
        }
    return {"offered": False}


async def try_handle_update_consent(
    *,
    message: str,
    conversation_id: str,
    user_message: dict,
    conversation_history: list[dict],
    settings: Any,
    open_thread_service: Any,
    durable_write_service: Any,
    memory_service: Any,
    is_consent: bool,
) -> Optional[dict]:
    offer = parse_update_offer_from_history(conversation_history)
    if not offer.get("offered") or not is_consent:
        return None

    active_threads = await open_thread_service.list_active_threads()
    existing = _resolve_existing_thread(
        active_threads,
        existing_title=str(offer.get("existing_title") or ""),
        topic_message=str(offer.get("topic_message") or message),
    )
    if existing is None:
        return await clarification_turn_result(
            memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=(
                "I couldn't find that open thread to update. "
                "Name it from Goals and ask me again."
            ),
        )

    topic = str(offer.get("topic_message") or message).strip() or message
    new_title = str(offer.get("new_title") or "").strip() or infer_thread_title(
        topic,
        conversation_history=conversation_history,
    )
    summary = build_thread_description(
        topic,
        conversation_history=conversation_history,
    )
    thread_id = str(existing.get("id") or "").strip()
    if settings.uses_text_offers():
        return await durable_write_service.apply_open_thread_update_consent(
            thread_id=thread_id,
            title=new_title,
            summary=summary,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_history,
        )
    return await durable_write_service.propose_open_thread_update(
        thread_id=thread_id,
        title=new_title,
        summary=summary,
        existing_title=str(existing.get("title") or ""),
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_history,
    )


async def try_handle_explicit_or_overlap_update(
    *,
    message: str,
    conversation_id: str,
    user_message: dict,
    conversation_history: list[dict],
    settings: Any,
    open_thread_service: Any,
    durable_write_service: Any,
    memory_service: Any,
    already_offered: bool,
    already_declined: bool,
) -> Optional[dict]:
    explicit = is_explicit_thread_update_command(message)
    if not explicit:
        if not settings.allows_kind(PROPOSAL_KIND_THREADS):
            return None
        if already_offered or already_declined:
            return None
        if not message_might_need_open_thread_offer(
            message,
            already_offered=already_offered,
            already_declined=already_declined,
            conversation_history=conversation_history,
        ):
            return None
        if not has_specific_actionable_continuity(
            message,
            conversation_history=conversation_history,
        ):
            return None

    active_threads = await open_thread_service.list_active_threads()
    if explicit:
        existing = find_thread_for_explicit_update(message, active_threads)
    else:
        existing = find_overlapping_active_thread(
            message,
            active_threads,
            threshold=0.45,
        )
    if existing is None:
        if explicit:
            return await clarification_turn_result(
                memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I couldn't match that to an open thread in Goals. "
                    "Name the thread and what to change."
                ),
            )
        return None

    new_title = infer_thread_title(
        message,
        conversation_history=conversation_history,
    )
    summary = build_thread_description(
        message,
        conversation_history=conversation_history,
    )
    existing_title = str(existing.get("title") or "").strip() or "that open thread"
    thread_id = str(existing.get("id") or "").strip()

    # Auto Text: chat ask only. Explicit Text: apply (user already ordered it).
    if settings.uses_text_offers() and not explicit:
        return await clarification_turn_result(
            memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=build_thread_update_ask(
                existing_title=existing_title,
                new_title=new_title,
            ),
        )
    if settings.uses_text_offers() and explicit:
        return await durable_write_service.apply_open_thread_update_consent(
            thread_id=thread_id,
            title=new_title,
            summary=summary,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_history,
        )

    # Card mode (auto or explicit) and Off explicit → confirm card.
    return await durable_write_service.propose_open_thread_update(
        thread_id=thread_id,
        title=new_title,
        summary=summary,
        existing_title=existing_title,
        conversation_id=conversation_id,
        user_message=user_message,
        conversation_messages=conversation_history,
    )


def _resolve_existing_thread(
    active_threads: list[dict],
    *,
    existing_title: str,
    topic_message: str,
) -> Optional[dict[str, Any]]:
    needle = existing_title.strip().casefold()
    if needle:
        for thread in active_threads:
            title = str(thread.get("title") or "").strip().casefold()
            if title == needle or needle in title or title in needle:
                return thread
    return find_overlapping_active_thread(topic_message, active_threads)
