"""Deterministic short-circuit handlers for chat turns."""

from __future__ import annotations

from typing import Optional

from app.services.chat_turn_observability import ChatTurnTrace
from app.services.chat_turn_orchestrator_support import (
    finish_short_circuit,
    guarded_turn_response,
)
from app.services.conversation_pending_action import (
    PendingAction,
    is_delete_confirmation_message,
    is_delete_rejection_message,
)


def should_apply_write_confirmation(write_confirmation: Optional[dict]) -> bool:
    return write_confirmation is not None


def should_apply_pending_affirmation(
    message: str,
    *,
    pending_action,
) -> bool:
    pending = (
        pending_action
        if isinstance(pending_action, PendingAction)
        else PendingAction.from_dict(pending_action)
    )
    if pending is None or pending.action_type != "durable_write":
        return False
    return is_delete_confirmation_message(message) or is_delete_rejection_message(
        message
    )


async def try_short_circuit_turn(
    orchestrator,
    *,
    brain_message: str,
    turn_context,
    pending_action,
    intent_decision,
    financial_context,
    turn_trace: ChatTurnTrace,
    turn_started_at: float,
    write_confirmation: Optional[dict] = None,
) -> Optional[dict]:
    conversation_id = turn_context.conversation_id
    if should_apply_write_confirmation(write_confirmation):
        durable_turn = await orchestrator.durable_write_service.try_handle_pending(
            brain_message,
            pending_action=pending_action,
            conversation_id=conversation_id,
            user_message=turn_context.user_message,
            write_confirmation=write_confirmation,
        )
        if durable_turn is not None:
            finish_short_circuit(
                orchestrator.turn_observer,
                orchestrator.usage_recorder,
                turn_trace,
                turn_started_at,
                "durable_write",
            )
            return durable_turn

    conversational_plan_turn = await orchestrator.conversational_plan_service.handle_turn(
        brain_message,
        conversation_id=conversation_id,
        user_message=turn_context.user_message,
        conversation_history=turn_context.conversation_history,
        time_context=turn_context.time_context,
        pending_action=pending_action,
    )
    if conversational_plan_turn:
        finish_short_circuit(
            orchestrator.turn_observer,
            orchestrator.usage_recorder,
            turn_trace,
            turn_started_at,
            "conversational_plan",
        )
        return conversational_plan_turn

    goal_command_turn = await orchestrator.goal_command_service.handle_turn(
        brain_message,
        conversation_id=conversation_id,
        user_message=turn_context.user_message,
        conversation_history=turn_context.conversation_history,
        time_context=turn_context.time_context,
        pending_action=pending_action,
    )
    if goal_command_turn:
        finish_short_circuit(
            orchestrator.turn_observer,
            orchestrator.usage_recorder,
            turn_trace,
            turn_started_at,
            "goal_command",
        )
        return goal_command_turn

    simple_memory_turn = await orchestrator.memory_turn_service.handle_turn(
        brain_message,
        conversation_id=conversation_id,
        user_message=turn_context.user_message,
        conversation_history=turn_context.conversation_history,
        time_context=turn_context.time_context,
        pending_action=pending_action,
    )
    if simple_memory_turn:
        finish_short_circuit(
            orchestrator.turn_observer,
            orchestrator.usage_recorder,
            turn_trace,
            turn_started_at,
            "memory_turn",
        )
        return simple_memory_turn

    if should_apply_pending_affirmation(
        brain_message,
        pending_action=pending_action,
    ):
        durable_turn = await orchestrator.durable_write_service.try_handle_pending(
            brain_message,
            pending_action=pending_action,
            conversation_id=conversation_id,
            user_message=turn_context.user_message,
            write_confirmation=write_confirmation,
        )
        if durable_turn is not None:
            finish_short_circuit(
                orchestrator.turn_observer,
                orchestrator.usage_recorder,
                turn_trace,
                turn_started_at,
                "durable_write",
            )
            return durable_turn

    finance_guard_response = orchestrator.financial_guard.guard_response(
        intent_decision,
        financial_context,
    )
    if finance_guard_response:
        finish_short_circuit(
            orchestrator.turn_observer,
            orchestrator.usage_recorder,
            turn_trace,
            turn_started_at,
            "finance_guard",
        )
        return await guarded_turn_response(
            memory_service=orchestrator.memory_service,
            memory_turn_service=orchestrator.memory_turn_service,
            conversation_id=conversation_id,
            response=finance_guard_response,
            user_message=turn_context.user_message,
        )
    return None
