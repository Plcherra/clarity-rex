"""Shared helpers for chat turn orchestration."""

from __future__ import annotations

from typing import Optional

from app.services.chat_turn_observability import ChatTurnObserver, ChatTurnTrace
from app.services.chat_usage_recorder import ChatUsageRecorder
from app.services.conversation_pending_action import ConversationPendingActionService
from app.services.file_service import AttachmentContext
from app.services.rex_channel import RexBrainChannel
from app.services.rex_intent_router import RexIntent
from app.services.transcript_normalizer import TranscriptNormalizer

_ACTION_TRUTH_STREAM_INTENTS = {
    RexIntent.MEMORY_SAVE,
    RexIntent.MEMORY_UPDATE,
    RexIntent.GOAL,
}


def stream_should_buffer_for_action_truth(
    intent_decision,
    *,
    channel: RexBrainChannel = RexBrainChannel.CHAT,
) -> bool:
    from app.services.voice_stream_orchestrator_support import (
        stream_should_buffer_for_action_truth as voice_aware_buffer,
    )

    return voice_aware_buffer(intent_decision, channel=channel)


def brain_messages(
    normalizer: TranscriptNormalizer,
    message: str,
) -> tuple[str, str]:
    stored_message = message.strip()
    brain_message = normalizer.normalize(stored_message)
    if not brain_message:
        brain_message = stored_message
    return stored_message, brain_message


def annotate_pending_action(turn_trace: ChatTurnTrace, pending_action) -> None:
    if pending_action is None:
        return
    turn_trace.record_pending_action(getattr(pending_action, "action_type", None))
    turn_trace.record_resolver_target(
        getattr(pending_action, "target_type", None),
        getattr(pending_action, "resolver_target", None),
    )


def annotate_proposal_settings(turn_trace: ChatTurnTrace, turn_context) -> None:
    resolution = getattr(turn_context, "proposal_settings_resolution", None)
    settings = getattr(turn_context, "proposal_settings", None)
    if resolution is None and settings is None:
        return
    if resolution is not None:
        turn_trace.record_proposal_settings(
            profile_mode=resolution.profile_mode,
            env_mode=resolution.env_mode,
            effective_mode=resolution.effective_mode,
            settings_load_status=resolution.settings_load_status,
            enabled_proposal_kinds=resolution.settings.enabled_kinds(),
        )
        return
    turn_trace.record_proposal_settings(
        profile_mode=None,
        env_mode=None,
        effective_mode=settings.mode,
        settings_load_status="unknown",
        enabled_proposal_kinds=settings.enabled_kinds(),
    )


def annotate_proposal_outcome(turn_trace: ChatTurnTrace, turn_result: Optional[dict]) -> None:
    from app.services.chat_turn_observability import (
        DURABLE_APPLY_APPLIED,
        DURABLE_APPLY_NONE,
        DURABLE_APPLY_PENDING,
        DURABLE_APPLY_REJECTED,
        DURABLE_APPLY_SKIPPED,
    )

    if not isinstance(turn_result, dict):
        return
    memory_changes = turn_result.get("memory_changes") or {}
    proposals = memory_changes.get("write_proposals") or []
    proposal_kind = None
    if proposals and isinstance(proposals[0], dict):
        proposal_kind = str(proposals[0].get("write_kind") or "").strip() or None

    applied = int(memory_changes.get("applied") or 0)
    skipped = int(memory_changes.get("skipped") or 0)
    confirmation_required = int(memory_changes.get("confirmation_required") or 0)
    if applied > 0:
        status = DURABLE_APPLY_APPLIED
    elif skipped > 0:
        status = DURABLE_APPLY_REJECTED
    elif confirmation_required > 0 or proposals:
        status = DURABLE_APPLY_PENDING
    elif memory_changes.get("skipped_reason"):
        status = DURABLE_APPLY_SKIPPED
    else:
        status = DURABLE_APPLY_NONE

    turn_trace.record_proposal_outcome(
        proposal_kind=proposal_kind,
        write_proposals_count=len(proposals),
        durable_apply_status=status,
    )


def finish_short_circuit(
    turn_observer: ChatTurnObserver,
    usage_recorder: ChatUsageRecorder,
    turn_trace: ChatTurnTrace,
    started_at: float,
    handler: str,
    turn_result: Optional[dict] = None,
) -> None:
    turn_trace.record_handler(handler)
    annotate_proposal_outcome(turn_trace, turn_result)
    log_turn_trace(turn_observer, usage_recorder, turn_trace, started_at)


async def guarded_turn_response(
    *,
    memory_service,
    memory_turn_service,
    conversation_id: str,
    response: str,
    user_message: dict,
) -> dict:
    assistant_message = await memory_service.save_message(
        conversation_id,
        "assistant",
        response,
    )
    return {
        "conversation_id": conversation_id,
        "response": response,
        "user_message": user_message,
        "assistant_message": assistant_message,
        "memory_correction": None,
        "memory_changes": None,
        "messages": await memory_turn_service.recent_public_messages(conversation_id),
    }


def turn_trace_event(intent_decision, channel: RexBrainChannel) -> dict:
    return {
        "event": "turn.trace",
        "intent": intent_decision.intent.value,
        "intent_reasons": list(intent_decision.reasons),
        "channel": channel.value,
        "loaded_context": {
            "long_term_memory": intent_decision.should_load_long_term_memory,
            "profile_memory": intent_decision.should_load_profile_memory,
            "structured_memory": intent_decision.should_load_structured_memory,
            "goal_context": intent_decision.should_load_goal_context,
            "accountability": intent_decision.should_load_accountability,
            "financial_context": intent_decision.should_use_financial_context,
        },
    }


def messages_with_attachment(
    messages: list[dict],
    attachment_context: Optional[AttachmentContext],
) -> list[dict]:
    if attachment_context is None or attachment_context.kind != "image":
        return messages
    if not attachment_context.data_url:
        return messages

    updated_messages = [dict(message) for message in messages]
    for index in range(len(updated_messages) - 1, -1, -1):
        if updated_messages[index].get("role") != "user":
            continue
        content = updated_messages[index].get("content", "")
        text = content if isinstance(content, str) else str(content)
        if not text.strip():
            text = "Please look at this image."
        updated_messages[index]["content"] = [
            {"type": "text", "text": text},
            {
                "type": "image_url",
                "image_url": {
                    "url": attachment_context.data_url,
                    "detail": "auto",
                },
            },
        ]
        return updated_messages
    return updated_messages


def financial_context_for_prompt(
    financial_context: Optional[dict],
    proposal_settings,
) -> Optional[dict]:
    if not financial_context:
        return None
    merged = dict(financial_context)
    merged["companion_settings"] = {
        "finance_edits_enabled": getattr(
            proposal_settings,
            "finance_edits_enabled",
            True,
        ),
    }
    return merged


async def load_pending_action(memory_service, conversation_id: str):
    if not conversation_id:
        return None
    return await ConversationPendingActionService(memory_service).get(conversation_id)


def log_turn_trace(
    turn_observer: ChatTurnObserver,
    usage_recorder: ChatUsageRecorder,
    turn_trace: ChatTurnTrace,
    started_at: float,
) -> None:
    turn_trace.duration_ms = usage_recorder.elapsed_ms(started_at)
    turn_observer.log_turn(turn_trace)
