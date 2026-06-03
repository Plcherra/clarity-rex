from app.services.memory_post_turn_service import MemoryPostTurnService


async def pending_correction_turn_response(
    *,
    memory_service,
    memory_turn_service,
    memory_post_turn_service: MemoryPostTurnService,
    conversation_id: str,
    user_message: dict,
    memory_correction: dict,
) -> dict:
    """Return a deterministic chat turn for corrections that need approval."""
    response = memory_post_turn_service.pending_correction_response(
        memory_correction
    )
    assistant_message = await memory_service.save_message(
        conversation_id,
        "assistant",
        response,
    )
    memory_changes = memory_post_turn_service.memory_change_summary(
        [],
        memory_correction=memory_correction,
        skipped_reason="correction_already_handled",
    )
    return {
        "conversation_id": conversation_id,
        "response": response,
        "user_message": user_message,
        "assistant_message": memory_turn_service.public_message(assistant_message),
        "memory_correction": memory_correction,
        "memory_changes": memory_changes,
        "messages": await memory_turn_service.recent_public_messages(conversation_id),
    }
