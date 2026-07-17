from __future__ import annotations

from collections.abc import AsyncIterator
import time
from typing import Optional

from fastapi import UploadFile

from app.services.chat_financial_guard import ChatFinancialGuard
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_context import ChatTurnContextService, MemoryService
from app.services.chat_turn_observability import ChatTurnObserver, ChatTurnTrace
from app.services.chat_turn_orchestrator_support import (
    annotate_pending_action,
    annotate_proposal_settings,
    brain_messages,
    finish_short_circuit,
    load_pending_action,
    log_turn_trace,
)
from app.services.chat_usage_recorder import ChatUsageRecorder
from app.services.clarity_action_parser import ClarityActionParser
from app.services.durable_write_service import DurableWriteService
from app.services.rex_channel import RexBrainChannel
from app.services.simple_rex_brain import SimpleRexBrain
from app.services.transcript_normalizer import (
    DEFAULT_TRANSCRIPT_NORMALIZER,
    TranscriptNormalizer,
)

BRAIN_REDESIGN_RESPONSE = (
    "Brain redesign in progress. The assistant understanding layer was removed "
    "and will return in plan 05."
)


class ChatTurnOrchestrator:
    def __init__(
        self,
        *,
        ai_service,
        memory_service: MemoryService,
        simple_rex_brain: SimpleRexBrain,
        chat_turn_context_service: ChatTurnContextService,
        durable_write_service: DurableWriteService,
        clarity_action_parser: ClarityActionParser,
        financial_guard: ChatFinancialGuard,
        truth_service: ChatResponseTruthService,
        usage_recorder: ChatUsageRecorder,
        transcript_normalizer: Optional[TranscriptNormalizer] = None,
        turn_observer: Optional[ChatTurnObserver] = None,
    ) -> None:
        self.ai_service = ai_service
        self.memory_service = memory_service
        self.simple_rex_brain = simple_rex_brain
        self.chat_turn_context_service = chat_turn_context_service
        self.durable_write_service = durable_write_service
        self.clarity_action_parser = clarity_action_parser
        self.financial_guard = financial_guard
        self.truth_service = truth_service
        self.usage_recorder = usage_recorder
        self.transcript_normalizer = (
            transcript_normalizer or DEFAULT_TRANSCRIPT_NORMALIZER
        )
        self.turn_observer = turn_observer or ChatTurnObserver()

    async def send_message(
        self,
        message: str,
        conversation_id: Optional[str] = None,
        file: Optional[UploadFile] = None,
        financial_context: Optional[dict] = None,
        response_instructions: Optional[str] = None,
        max_response_tokens: Optional[int] = None,
        channel: RexBrainChannel = RexBrainChannel.CHAT,
        user_requested_deep_thinking: bool = False,
        locale: Optional[str] = None,
        write_confirmation: Optional[dict] = None,
        user_enabled_proactive_insights: bool = False,
    ) -> dict:
        _ = (
            financial_context,
            response_instructions,
            max_response_tokens,
            user_requested_deep_thinking,
            locale,
            user_enabled_proactive_insights,
        )
        stored_message, brain_message = brain_messages(
            self.transcript_normalizer,
            message,
        )
        turn_started_at = time.perf_counter()
        turn_context = await self.chat_turn_context_service.prepare(
            message=brain_message,
            stored_message=stored_message,
            conversation_id=conversation_id,
            file=file,
            channel=channel,
        )
        conversation_id = turn_context.conversation_id
        turn_trace = self.turn_observer.new_trace(
            conversation_id=conversation_id,
            intent="brain_redesign",
        )
        annotate_proposal_settings(turn_trace, turn_context)
        pending_action = await load_pending_action(self.memory_service, conversation_id)
        annotate_pending_action(turn_trace, pending_action)
        if pending_action is not None or write_confirmation is not None:
            pending_result = await self.durable_write_service.try_handle_pending(
                brain_message,
                pending_action=pending_action,
                conversation_id=conversation_id,
                user_message=turn_context.user_message,
                write_confirmation=write_confirmation,
            )
            if pending_result is not None:
                finish_short_circuit(
                    self.turn_observer,
                    self.usage_recorder,
                    turn_trace,
                    turn_started_at,
                    "durable_write",
                    turn_result=pending_result,
                )
                return pending_result

        assistant_response = BRAIN_REDESIGN_RESPONSE
        finish_short_circuit(
            self.turn_observer,
            self.usage_recorder,
            turn_trace,
            turn_started_at,
            "brain_redesign",
        )
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            assistant_response,
        )
        return {
            "conversation_id": conversation_id,
            "response": assistant_response,
            "user_message": turn_context.user_message,
            "assistant_message": assistant_message,
            "memory_correction": None,
            "memory_changes": None,
            "messages": await self._recent_public_messages(conversation_id),
        }

    async def stream_message(
        self,
        message: str,
        conversation_id: Optional[str] = None,
        file: Optional[UploadFile] = None,
        response_instructions: Optional[str] = None,
        max_response_tokens: Optional[int] = None,
        financial_context: Optional[dict] = None,
        channel: RexBrainChannel = RexBrainChannel.CHAT,
        user_requested_deep_thinking: bool = False,
        include_turn_trace: bool = False,
        locale: Optional[str] = None,
        write_confirmation: Optional[dict] = None,
        user_enabled_proactive_insights: bool = False,
    ) -> AsyncIterator[dict]:
        _ = (
            financial_context,
            response_instructions,
            max_response_tokens,
            user_requested_deep_thinking,
            locale,
            user_enabled_proactive_insights,
        )
        stored_message, brain_message = brain_messages(
            self.transcript_normalizer,
            message,
        )
        turn_started_at = time.perf_counter()
        turn_context = await self.chat_turn_context_service.prepare(
            message=brain_message,
            stored_message=stored_message,
            conversation_id=conversation_id,
            file=file,
            channel=channel,
        )
        conversation_id = turn_context.conversation_id
        turn_trace = self.turn_observer.new_trace(
            conversation_id=conversation_id,
            intent="brain_redesign",
        )
        annotate_proposal_settings(turn_trace, turn_context)
        yield {"event": "conversation", "conversation_id": conversation_id}
        if include_turn_trace:
            yield {
                "event": "turn.trace",
                "intent": "brain_redesign",
                "intent_reasons": ["plan_04_shell"],
                "channel": channel.value,
                "loaded_context": {},
            }
        pending_action = await load_pending_action(self.memory_service, conversation_id)
        annotate_pending_action(turn_trace, pending_action)
        if pending_action is not None or write_confirmation is not None:
            pending_result = await self.durable_write_service.try_handle_pending(
                brain_message,
                pending_action=pending_action,
                conversation_id=conversation_id,
                user_message=turn_context.user_message,
                write_confirmation=write_confirmation,
            )
            if pending_result is not None:
                finish_short_circuit(
                    self.turn_observer,
                    self.usage_recorder,
                    turn_trace,
                    turn_started_at,
                    "durable_write",
                    turn_result=pending_result,
                )
                yield {"event": "token", "token": pending_result["response"]}
                yield {
                    "event": "done",
                    "conversation_id": conversation_id,
                    "response": pending_result["response"],
                    "messages": pending_result["messages"],
                    "memory_changes": pending_result.get("memory_changes"),
                    "assistant_message": pending_result.get("assistant_message"),
                }
                return

        assistant_response = BRAIN_REDESIGN_RESPONSE
        finish_short_circuit(
            self.turn_observer,
            self.usage_recorder,
            turn_trace,
            turn_started_at,
            "brain_redesign",
        )
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            assistant_response,
        )
        yield {"event": "token", "token": assistant_response}
        yield {
            "event": "done",
            "conversation_id": conversation_id,
            "response": assistant_response,
            "messages": await self._recent_public_messages(conversation_id),
            "memory_changes": None,
            "assistant_message": assistant_message,
        }

    async def _recent_public_messages(self, conversation_id: str) -> list[dict]:
        messages = await self.memory_service.get_recent_messages(
            conversation_id,
            limit=20,
        )
        return [
            message
            for message in messages
            if str(message.get("role") or "") in {"user", "assistant"}
        ]
