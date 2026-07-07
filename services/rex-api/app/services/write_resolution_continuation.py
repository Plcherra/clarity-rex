"""Continue companion chat after a save/tracking decision."""

from __future__ import annotations

from typing import Any, Optional

from app.services.rex_channel import RexBrainChannel

_COMPANION_CONTINUATION_INSTRUCTIONS = (
    "The user just confirmed or declined a save/tracking prompt. "
    "Continue the conversation naturally on their real topic. "
    "Do not propose saving, tracking, or creating goals, open threads, or memory "
    "unless they explicitly ask."
)

_AFFIRMATION_REPLIES = {
    "yes",
    "no",
    "nope",
    "yeah",
    "yep",
    "sure",
    "ok",
    "okay",
    "please",
}

_WRITE_RESOLUTION_ACK_PHRASES = (
    "okay, i won't",
    "no problem. i won't",
)


def _pending_write_proposals(memory_changes: dict) -> list[dict]:
    proposals = memory_changes.get("write_proposals") or []
    pending: list[dict] = []
    for proposal in proposals:
        if not isinstance(proposal, dict):
            continue
        status = str(proposal.get("status") or "pending").strip().lower()
        if status == "pending":
            pending.append(proposal)
    return pending


def should_continue_companion_chat(turn_result: dict) -> bool:
    memory_changes = turn_result.get("memory_changes") or {}
    if memory_changes.get("confirmation_required"):
        return False
    if _pending_write_proposals(memory_changes):
        return False
    response = str(turn_result.get("response") or "").strip()
    return bool(response)


def is_write_resolution_ack_response(response: str) -> bool:
    normalized = str(response or "").strip().casefold()
    if not normalized:
        return False
    return any(phrase in normalized for phrase in _WRITE_RESOLUTION_ACK_PHRASES)


def is_write_resolution_ack_turn(turn_result: dict) -> bool:
    if not should_continue_companion_chat(turn_result):
        return False
    return is_write_resolution_ack_response(str(turn_result.get("response") or ""))


def should_append_companion_continuation(turn_result: dict) -> bool:
    if not should_continue_companion_chat(turn_result):
        return False
    memory_changes = turn_result.get("memory_changes") or {}
    response = str(turn_result.get("response") or "").strip()
    if is_write_resolution_ack_response(response):
        return True
    proposals = memory_changes.get("write_proposals") or []
    if any(
        str(proposal.get("status") or "").strip().lower() == "failed"
        for proposal in proposals
        if isinstance(proposal, dict)
    ):
        return False
    if memory_changes.get("created") or memory_changes.get("updated"):
        return True
    if memory_changes.get("skipped"):
        return True
    return False


def topic_message_for_continuation(
    conversation_history: list[dict],
    *,
    current_message: str,
) -> str:
    normalized = current_message.strip().casefold()
    if normalized not in _AFFIRMATION_REPLIES:
        return current_message
    for message in reversed(conversation_history):
        if message.get("role") != "user":
            continue
        content = str(message.get("content") or "").strip()
        if not content:
            continue
        if content.casefold() in _AFFIRMATION_REPLIES:
            continue
        return content
    return current_message


async def append_companion_continuation(
    orchestrator: Any,
    *,
    turn_context: Any,
    intent_decision: Any,
    financial_context: Optional[dict],
    channel: RexBrainChannel,
    turn_result: dict,
    brain_message: str,
    locale: Optional[str] = None,
) -> dict:
    if not should_append_companion_continuation(turn_result):
        return turn_result

    conversation_id = turn_context.conversation_id
    conversation_history = orchestrator.memory_turn_service.public_messages(
        turn_context.conversation_history
    )
    topic_message = topic_message_for_continuation(
        conversation_history,
        current_message=brain_message,
    )
    ai_messages = orchestrator._build_llm_messages(
        brain_message=topic_message,
        conversation_id=conversation_id,
        conversation_history=conversation_history,
        turn_context=turn_context,
        intent_decision=intent_decision,
        financial_context=financial_context,
        channel=channel,
        attachment_context=turn_context.attachment_context,
        response_instructions=_COMPANION_CONTINUATION_INSTRUCTIONS,
        locale=locale,
    )
    continuation, _ = await orchestrator._generate_truthful_response(
        ai_messages=ai_messages,
        channel=channel,
        max_response_tokens=None,
        intent_decision=intent_decision,
        brain_message=topic_message,
        structured_context=turn_context.structured_context,
        conversation_history=conversation_history,
        turn_trace=orchestrator.turn_observer.new_trace(
            conversation_id=conversation_id,
            intent=intent_decision.intent.value,
        ),
        conversation_id=conversation_id,
    )
    continuation = str(continuation or "").strip()
    if not continuation:
        return turn_result

    await orchestrator.memory_service.save_message(
        conversation_id,
        "assistant",
        continuation,
    )
    turn_result = dict(turn_result)
    turn_result["response"] = continuation
    turn_result["messages"] = await orchestrator.memory_turn_service.recent_public_messages(
        conversation_id
    )
    return turn_result
