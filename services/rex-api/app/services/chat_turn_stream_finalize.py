"""Buffered Grok stream + finalized token/done events (no mid-reply rewrite flash)."""

from __future__ import annotations

import time
from typing import Any, AsyncIterator

from app.services.action_fence_stream import ActionFenceStreamFilter
from app.services.chat_turn_finalize import finalize_grok_turn
from app.services.chat_turn_orchestrator_support import finish_short_circuit
from app.services.grok_usage import GrokUsageHolder


async def collect_buffered_grok_reply(
    grok_turn_brain,
    *,
    ai_messages: list[dict],
    max_tokens: int,
    usage_recorder,
    channel,
) -> str:
    """Drain Grok stream without yielding tokens; strip action fences."""
    response_parts: list[str] = []
    stream_filter = ActionFenceStreamFilter()
    llm_started_at = time.perf_counter()
    usage_holder = GrokUsageHolder()
    try:
        async for token in grok_turn_brain.stream(
            ai_messages,
            max_tokens=max_tokens,
            usage_holder=usage_holder,
        ):
            response_parts.append(token)
            stream_filter.feed(token)
    except Exception as error:
        await usage_recorder.record_llm_usage(
            channel=channel,
            ai_kwargs={"max_tokens": max_tokens},
            latency_ms=usage_recorder.elapsed_ms(llm_started_at),
            status="failure",
            error_class=error.__class__.__name__,
            usage=usage_holder.usage,
        )
        raise
    await usage_recorder.record_llm_usage(
        channel=channel,
        ai_kwargs={"max_tokens": max_tokens},
        latency_ms=usage_recorder.elapsed_ms(llm_started_at),
        usage=usage_holder.usage,
    )
    stream_filter.finish()
    return "".join(response_parts).strip()


async def iter_finalized_stream_events(
    rex_response: str,
    *,
    clarity_action_parser,
    truth_service,
    durable_write_service,
    memory_service,
    proposal_settings,
    brain_message: str,
    user_message: dict,
    conversation_id: str,
    conversation_history: list[dict],
    turn_trace,
    ai_messages: list[dict],
    turn_observer,
    usage_recorder,
    turn_started_at: float,
    recent_public_messages,
) -> AsyncIterator[dict[str, Any]]:
    """Finalize then emit a single token burst + done (stable reply)."""
    finalized = await finalize_grok_turn(
        rex_response,
        clarity_action_parser=clarity_action_parser,
        truth_service=truth_service,
        durable_write_service=durable_write_service,
        proposal_settings=proposal_settings,
        brain_message=brain_message,
        user_message=user_message,
        conversation_id=conversation_id,
        conversation_history=conversation_history,
        turn_trace=turn_trace,
        ai_messages=ai_messages,
    )
    if finalized.get("proposed_turn") is not None:
        proposed = finalized["proposed_turn"]
        finish_short_circuit(
            turn_observer,
            usage_recorder,
            turn_trace,
            turn_started_at,
            "llm",
            turn_result=proposed,
        )
        if proposed.get("response"):
            yield {"event": "token", "token": proposed["response"]}
        yield {
            "event": "done",
            "conversation_id": conversation_id,
            "response": proposed["response"],
            "messages": proposed.get("messages")
            or await recent_public_messages(conversation_id),
            "memory_changes": proposed.get("memory_changes"),
            "assistant_message": proposed.get("assistant_message"),
        }
        return

    assistant_response = finalized["response"]
    memory_changes = finalized.get("memory_changes")
    finish_short_circuit(
        turn_observer,
        usage_recorder,
        turn_trace,
        turn_started_at,
        "llm",
        turn_result={"memory_changes": memory_changes},
    )
    await memory_service.save_message(
        conversation_id,
        "assistant",
        assistant_response,
    )
    if assistant_response:
        yield {"event": "token", "token": assistant_response}
    yield {
        "event": "done",
        "conversation_id": conversation_id,
        "response": assistant_response,
        "messages": await recent_public_messages(conversation_id),
        "memory_changes": memory_changes,
    }
