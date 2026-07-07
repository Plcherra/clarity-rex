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
from app.services.durable_write_pending import proposal_from_pending_action
from app.services.durable_write_results import pending_memory_changes
from app.services.goal_command_results import clarification_turn_result
from app.services.rex_channel import RexBrainChannel
from app.services.write_resolution_continuation import (
    append_companion_continuation,
    is_write_resolution_ack_turn,
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


async def _finish_resolution_short_circuit(
    orchestrator,
    *,
    turn_result: dict,
    turn_context,
    intent_decision,
    financial_context,
    channel: RexBrainChannel,
    brain_message: str,
    turn_trace: ChatTurnTrace,
    turn_started_at: float,
    route: str,
    locale: Optional[str] = None,
) -> dict:
    turn_result = await append_companion_continuation(
        orchestrator,
        turn_context=turn_context,
        intent_decision=intent_decision,
        financial_context=financial_context,
        channel=channel,
        turn_result=turn_result,
        brain_message=brain_message,
        locale=locale,
    )
    finish_short_circuit(
        orchestrator.turn_observer,
        orchestrator.usage_recorder,
        turn_trace,
        turn_started_at,
        route,
    )
    return turn_result


async def _finish_short_circuit_turn(
    orchestrator,
    *,
    turn_result: dict,
    turn_context,
    intent_decision,
    financial_context,
    channel: RexBrainChannel,
    brain_message: str,
    turn_trace: ChatTurnTrace,
    turn_started_at: float,
    route: str,
    locale: Optional[str] = None,
) -> dict:
    if is_write_resolution_ack_turn(turn_result):
        return await _finish_resolution_short_circuit(
            orchestrator,
            turn_result=turn_result,
            turn_context=turn_context,
            intent_decision=intent_decision,
            financial_context=financial_context,
            channel=channel,
            brain_message=brain_message,
            turn_trace=turn_trace,
            turn_started_at=turn_started_at,
            route=route,
            locale=locale,
        )
    finish_short_circuit(
        orchestrator.turn_observer,
        orchestrator.usage_recorder,
        turn_trace,
        turn_started_at,
        route,
    )
    return turn_result


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
    channel: RexBrainChannel = RexBrainChannel.CHAT,
    locale: Optional[str] = None,
) -> Optional[dict]:
    conversation_id = turn_context.conversation_id
    proposal_settings = turn_context.proposal_settings
    if should_apply_write_confirmation(write_confirmation):
        durable_turn = await orchestrator.durable_write_service.try_handle_pending(
            brain_message,
            pending_action=pending_action,
            conversation_id=conversation_id,
            user_message=turn_context.user_message,
            write_confirmation=write_confirmation,
        )
        if durable_turn is not None:
            return await _finish_resolution_short_circuit(
                orchestrator,
                turn_result=durable_turn,
                turn_context=turn_context,
                intent_decision=intent_decision,
                financial_context=financial_context,
                channel=channel,
                brain_message=brain_message,
                turn_trace=turn_trace,
                turn_started_at=turn_started_at,
                route="durable_write",
                locale=locale,
            )

    open_thread_turn = await orchestrator.open_thread_turn_service.handle_turn(
        brain_message,
        conversation_id=conversation_id,
        user_message=turn_context.user_message,
        conversation_history=turn_context.conversation_history,
        pending_action=pending_action,
        proposal_settings=proposal_settings,
    )
    if open_thread_turn:
        return await _finish_short_circuit_turn(
            orchestrator,
            turn_result=open_thread_turn,
            turn_context=turn_context,
            intent_decision=intent_decision,
            financial_context=financial_context,
            channel=channel,
            brain_message=brain_message,
            turn_trace=turn_trace,
            turn_started_at=turn_started_at,
            route="open_thread",
            locale=locale,
        )

    conversational_plan_turn = await orchestrator.conversational_plan_service.handle_turn(
        brain_message,
        conversation_id=conversation_id,
        user_message=turn_context.user_message,
        conversation_history=turn_context.conversation_history,
        time_context=turn_context.time_context,
        pending_action=pending_action,
        proposal_settings=proposal_settings,
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

    plan_date_turn = await orchestrator.plan_target_date_update_service.handle_turn(
        brain_message,
        conversation_id=conversation_id,
        user_message=turn_context.user_message,
        time_context=turn_context.time_context,
        pending_action=pending_action,
    )
    if plan_date_turn:
        finish_short_circuit(
            orchestrator.turn_observer,
            orchestrator.usage_recorder,
            turn_trace,
            turn_started_at,
            "plan_target_date",
        )
        return plan_date_turn

    delete_turn = await orchestrator.memory_delete_turn_service.handle_turn(
        brain_message,
        conversation_id=conversation_id,
        user_message=turn_context.user_message,
        conversation_history=turn_context.conversation_history,
        pending_action=pending_action,
    )
    if delete_turn:
        return await _finish_short_circuit_turn(
            orchestrator,
            turn_result=delete_turn,
            turn_context=turn_context,
            intent_decision=intent_decision,
            financial_context=financial_context,
            channel=channel,
            brain_message=brain_message,
            turn_trace=turn_trace,
            turn_started_at=turn_started_at,
            route="memory_delete",
            locale=locale,
        )

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
        proposal_settings=proposal_settings,
    )
    if simple_memory_turn:
        return await _finish_short_circuit_turn(
            orchestrator,
            turn_result=simple_memory_turn,
            turn_context=turn_context,
            intent_decision=intent_decision,
            financial_context=financial_context,
            channel=channel,
            brain_message=brain_message,
            turn_trace=turn_trace,
            turn_started_at=turn_started_at,
            route="memory_turn",
            locale=locale,
        )

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
            return await _finish_resolution_short_circuit(
                orchestrator,
                turn_result=durable_turn,
                turn_context=turn_context,
                intent_decision=intent_decision,
                financial_context=financial_context,
                channel=channel,
                brain_message=brain_message,
                turn_trace=turn_trace,
                turn_started_at=turn_started_at,
                route="durable_write",
                locale=locale,
            )

    pending_write_reminder = await _try_remind_pending_durable_write(
        orchestrator,
        brain_message,
        pending_action=pending_action,
        conversation_id=conversation_id,
        user_message=turn_context.user_message,
    )
    if pending_write_reminder is not None:
        finish_short_circuit(
            orchestrator.turn_observer,
            orchestrator.usage_recorder,
            turn_trace,
            turn_started_at,
            "durable_write_pending",
        )
        return pending_write_reminder

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


async def _try_remind_pending_durable_write(
    orchestrator,
    message: str,
    *,
    pending_action,
    conversation_id: str,
    user_message: dict,
) -> Optional[dict]:
    pending = (
        pending_action
        if isinstance(pending_action, PendingAction)
        else PendingAction.from_dict(pending_action)
    )
    if pending is None or pending.action_type != "durable_write":
        return None
    if is_delete_confirmation_message(message) or is_delete_rejection_message(message):
        return None

    proposal = proposal_from_pending_action(pending)
    if proposal is None:
        return None
    if proposal.write_kind == "delete":
        return None

    return await clarification_turn_result(
        orchestrator.memory_service,
        conversation_id=conversation_id,
        user_message=user_message,
        response=(
            "I still have a pending save waiting for your confirmation. "
            "Use the save card to confirm or dismiss it."
        ),
        memory_changes=pending_memory_changes(proposal=proposal),
    )
