from __future__ import annotations

from collections.abc import AsyncIterator
import time
from typing import Optional

from fastapi import UploadFile

from app.services.chat_financial_guard import ChatFinancialGuard
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_context import ChatTurnContextService, MemoryService
from app.services.chat_turn_observability import ChatTurnObserver, ChatTurnTrace
from app.services.conversation_pending_action import (
    PendingAction,
    is_delete_confirmation_message,
    is_delete_rejection_message,
)
from app.services.chat_turn_orchestrator_support import (
    annotate_pending_action,
    brain_messages,
    finish_short_circuit,
    guarded_turn_response,
    load_pending_action,
    messages_with_attachment,
    turn_trace_event,
)
from app.services.chat_usage_recorder import ChatUsageRecorder
from app.services.grok_usage import GrokUsageHolder
from app.services.clarity_action_parser import (
    ClarityActionParser,
    ClarityActionStreamFilter,
)
from app.services.goal_command_service import GoalCommandService
from app.services.conversational_plan_service import ConversationalPlanService
from app.services.durable_write_service import DurableWriteService
from app.services.memory_turn_service import MemoryTurnService
from app.services.rex_channel import RexBrainChannel
from app.services.simple_rex_brain import SimpleRexBrain
from app.services.transcript_normalizer import (
    DEFAULT_TRANSCRIPT_NORMALIZER,
    TranscriptNormalizer,
)


class ChatTurnOrchestrator:
    def __init__(
        self,
        *,
        ai_service,
        memory_service: MemoryService,
        simple_rex_brain: SimpleRexBrain,
        chat_turn_context_service: ChatTurnContextService,
        memory_turn_service: MemoryTurnService,
        goal_command_service: GoalCommandService,
        conversational_plan_service: ConversationalPlanService,
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
        self.memory_turn_service = memory_turn_service
        self.goal_command_service = goal_command_service
        self.conversational_plan_service = conversational_plan_service
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
    ) -> dict:
        stored_message, brain_message = brain_messages(
            self.transcript_normalizer,
            message,
        )
        turn_started_at = time.perf_counter()
        intent_decision = self.simple_rex_brain.classify(
            brain_message,
            has_file=file is not None,
            has_financial_context=financial_context is not None,
            user_requested_deep_thinking=user_requested_deep_thinking,
        )
        financial_context = self.financial_guard.financial_context_for_intent(
            intent_decision,
            financial_context,
        )
        turn_context = await self.chat_turn_context_service.prepare(
            message=brain_message,
            stored_message=stored_message,
            conversation_id=conversation_id,
            file=file,
            intent_decision=intent_decision,
        )
        conversation_id = turn_context.conversation_id
        turn_trace = self.turn_observer.new_trace(
            conversation_id=conversation_id,
            intent=intent_decision.intent.value,
        )
        pending_action = await load_pending_action(self.memory_service, conversation_id)
        annotate_pending_action(turn_trace, pending_action)
        short_circuit = await self._try_short_circuit_turn(
            brain_message=brain_message,
            turn_context=turn_context,
            pending_action=pending_action,
            intent_decision=intent_decision,
            financial_context=financial_context,
            turn_trace=turn_trace,
            turn_started_at=turn_started_at,
            write_confirmation=write_confirmation,
        )
        if short_circuit is not None:
            return short_circuit

        conversation_history = self.memory_turn_service.public_messages(
            turn_context.conversation_history
        )
        ai_messages = self._build_llm_messages(
            brain_message=brain_message,
            conversation_id=conversation_id,
            conversation_history=conversation_history,
            turn_context=turn_context,
            intent_decision=intent_decision,
            financial_context=financial_context,
            channel=channel,
            attachment_context=turn_context.attachment_context,
            response_instructions=response_instructions,
            locale=locale,
        )
        assistant_response, clarity_action_proposals = await self._generate_truthful_response(
            ai_messages=ai_messages,
            channel=channel,
            max_response_tokens=max_response_tokens,
            intent_decision=intent_decision,
            brain_message=brain_message,
            structured_context=turn_context.structured_context,
            conversation_history=conversation_history,
            turn_trace=turn_trace,
        )
        finish_short_circuit(
            self.turn_observer,
            self.usage_recorder,
            turn_trace,
            turn_started_at,
            "llm",
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
            "memory_changes": self.clarity_action_parser.with_memory_changes(
                None,
                clarity_action_proposals,
            ),
            "messages": await self.memory_turn_service.recent_public_messages(
                conversation_id
            ),
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
    ) -> AsyncIterator[dict]:
        stored_message, brain_message = brain_messages(
            self.transcript_normalizer,
            message,
        )
        turn_started_at = time.perf_counter()
        intent_decision = self.simple_rex_brain.classify(
            brain_message,
            has_file=file is not None,
            has_financial_context=financial_context is not None,
            user_requested_deep_thinking=user_requested_deep_thinking,
        )
        financial_context = self.financial_guard.financial_context_for_intent(
            intent_decision,
            financial_context,
        )
        turn_context = await self.chat_turn_context_service.prepare(
            message=brain_message,
            stored_message=stored_message,
            conversation_id=conversation_id,
            file=file,
            intent_decision=intent_decision,
        )
        conversation_id = turn_context.conversation_id
        turn_trace = self.turn_observer.new_trace(
            conversation_id=conversation_id,
            intent=intent_decision.intent.value,
        )
        yield {"event": "conversation", "conversation_id": conversation_id}
        if include_turn_trace:
            yield turn_trace_event(intent_decision, channel)
        pending_action = await load_pending_action(self.memory_service, conversation_id)
        annotate_pending_action(turn_trace, pending_action)
        short_circuit = await self._try_short_circuit_turn(
            brain_message=brain_message,
            turn_context=turn_context,
            pending_action=pending_action,
            intent_decision=intent_decision,
            financial_context=financial_context,
            turn_trace=turn_trace,
            turn_started_at=turn_started_at,
            write_confirmation=write_confirmation,
        )
        if short_circuit is not None:
            yield {"event": "token", "token": short_circuit["response"]}
            yield {
                "event": "done",
                "conversation_id": conversation_id,
                "response": short_circuit["response"],
                "messages": short_circuit["messages"],
                "memory_changes": short_circuit["memory_changes"],
                "assistant_message": short_circuit["assistant_message"],
            }
            return

        conversation_history = self.memory_turn_service.public_messages(
            turn_context.conversation_history
        )
        ai_messages = self._build_llm_messages(
            brain_message=brain_message,
            conversation_id=conversation_id,
            conversation_history=conversation_history,
            turn_context=turn_context,
            intent_decision=intent_decision,
            financial_context=financial_context,
            channel=channel,
            attachment_context=turn_context.attachment_context,
            response_instructions=response_instructions,
            locale=locale,
        )
        response_parts = []
        stream_filter = ClarityActionStreamFilter()
        ai_kwargs = {}
        if max_response_tokens is not None:
            ai_kwargs["max_tokens"] = max_response_tokens
        llm_started_at = time.perf_counter()
        usage_holder = GrokUsageHolder()
        try:
            async for token in self.ai_service.stream_response(
                ai_messages,
                usage_holder=usage_holder,
                **ai_kwargs,
            ):
                response_parts.append(token)
                for visible_token in stream_filter.feed(token):
                    if visible_token:
                        yield {"event": "token", "token": visible_token}
        except Exception as error:
            await self.usage_recorder.record_llm_usage(
                channel=channel,
                ai_kwargs=ai_kwargs,
                latency_ms=self.usage_recorder.elapsed_ms(llm_started_at),
                status="failure",
                error_class=error.__class__.__name__,
                usage=usage_holder.usage,
            )
            raise
        await self.usage_recorder.record_llm_usage(
            channel=channel,
            ai_kwargs=ai_kwargs,
            latency_ms=self.usage_recorder.elapsed_ms(llm_started_at),
            usage=usage_holder.usage,
        )
        for visible_token in stream_filter.finish():
            if visible_token:
                yield {"event": "token", "token": visible_token}

        rex_response = "".join(response_parts).strip()
        unsupported_actions = self.clarity_action_parser.unsupported_actions(
            rex_response,
        )
        assistant_response, clarity_action_proposals = (
            self.clarity_action_parser.extract_proposals(rex_response)
        )
        assistant_response = self.truth_service.truthful_generated_response(
            assistant_response,
            clarity_action_proposals,
            unsupported_actions=unsupported_actions,
            intent_decision=intent_decision,
            user_message=brain_message,
            memory_status=turn_context.structured_context.get("memory_status"),
            chat_search_results_loaded=self.truth_service.has_chat_search_results(
                ai_messages
            ),
            conversation_history=conversation_history,
            turn_trace=turn_trace,
        )
        finish_short_circuit(
            self.turn_observer,
            self.usage_recorder,
            turn_trace,
            turn_started_at,
            "llm",
        )
        await self.memory_service.save_message(
            conversation_id,
            "assistant",
            assistant_response,
        )
        yield {
            "event": "done",
            "conversation_id": conversation_id,
            "response": assistant_response,
            "messages": await self.memory_turn_service.recent_public_messages(
                conversation_id
            ),
            "memory_changes": self.clarity_action_parser.with_memory_changes(
                None,
                clarity_action_proposals,
            ),
        }

    async def _try_short_circuit_turn(
        self,
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
        if self._should_apply_write_confirmation(write_confirmation):
            durable_turn = await self.durable_write_service.try_handle_pending(
                brain_message,
                pending_action=pending_action,
                conversation_id=conversation_id,
                user_message=turn_context.user_message,
                write_confirmation=write_confirmation,
            )
            if durable_turn is not None:
                finish_short_circuit(
                    self.turn_observer,
                    self.usage_recorder,
                    turn_trace,
                    turn_started_at,
                    "durable_write",
                )
                return durable_turn

        conversational_plan_turn = await self.conversational_plan_service.handle_turn(
            brain_message,
            conversation_id=conversation_id,
            user_message=turn_context.user_message,
            conversation_history=turn_context.conversation_history,
            time_context=turn_context.time_context,
            pending_action=pending_action,
        )
        if conversational_plan_turn:
            finish_short_circuit(
                self.turn_observer,
                self.usage_recorder,
                turn_trace,
                turn_started_at,
                "conversational_plan",
            )
            return conversational_plan_turn
        goal_command_turn = await self.goal_command_service.handle_turn(
            brain_message,
            conversation_id=conversation_id,
            user_message=turn_context.user_message,
            conversation_history=turn_context.conversation_history,
            time_context=turn_context.time_context,
            pending_action=pending_action,
        )
        if goal_command_turn:
            finish_short_circuit(
                self.turn_observer,
                self.usage_recorder,
                turn_trace,
                turn_started_at,
                "goal_command",
            )
            return goal_command_turn
        simple_memory_turn = await self.memory_turn_service.handle_turn(
            brain_message,
            conversation_id=conversation_id,
            user_message=turn_context.user_message,
            conversation_history=turn_context.conversation_history,
            time_context=turn_context.time_context,
            pending_action=pending_action,
        )
        if simple_memory_turn:
            finish_short_circuit(
                self.turn_observer,
                self.usage_recorder,
                turn_trace,
                turn_started_at,
                "memory_turn",
            )
            return simple_memory_turn

        if self._should_apply_pending_affirmation(
            brain_message,
            pending_action=pending_action,
        ):
            durable_turn = await self.durable_write_service.try_handle_pending(
                brain_message,
                pending_action=pending_action,
                conversation_id=conversation_id,
                user_message=turn_context.user_message,
                write_confirmation=write_confirmation,
            )
            if durable_turn is not None:
                finish_short_circuit(
                    self.turn_observer,
                    self.usage_recorder,
                    turn_trace,
                    turn_started_at,
                    "durable_write",
                )
                return durable_turn
        finance_guard_response = self.financial_guard.guard_response(
            intent_decision,
            financial_context,
        )
        if finance_guard_response:
            finish_short_circuit(
                self.turn_observer,
                self.usage_recorder,
                turn_trace,
                turn_started_at,
                "finance_guard",
            )
            return await guarded_turn_response(
                memory_service=self.memory_service,
                memory_turn_service=self.memory_turn_service,
                conversation_id=conversation_id,
                response=finance_guard_response,
                user_message=turn_context.user_message,
            )
        return None

    def _should_apply_write_confirmation(
        self,
        write_confirmation: Optional[dict],
    ) -> bool:
        return write_confirmation is not None

    def _should_apply_pending_affirmation(
        self,
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

    def _build_llm_messages(
        self,
        *,
        brain_message: str,
        conversation_id: str,
        conversation_history: list[dict],
        turn_context,
        intent_decision,
        financial_context,
        channel: RexBrainChannel,
        attachment_context,
        response_instructions: Optional[str],
        locale: Optional[str] = None,
    ) -> list[dict]:
        ai_messages = self.simple_rex_brain.build_prompt_messages(
            message=brain_message,
            conversation_id=conversation_id,
            conversation_history=conversation_history,
            long_term_memory=turn_context.long_term_memory,
            structured_context=turn_context.structured_context,
            accountability_signals=turn_context.accountability_signals,
            file_text=turn_context.file_text,
            time_context=turn_context.time_context,
            financial_context=financial_context,
            channel=channel,
            locale=locale,
        )
        if response_instructions:
            ai_messages.append({"role": "system", "content": response_instructions})
        return messages_with_attachment(ai_messages, attachment_context)

    async def _generate_truthful_response(
        self,
        *,
        ai_messages: list[dict],
        channel: RexBrainChannel,
        max_response_tokens: Optional[int],
        intent_decision,
        brain_message: str,
        structured_context: dict,
        conversation_history: list[dict],
        turn_trace: ChatTurnTrace,
    ) -> tuple[str, list]:
        ai_kwargs = {}
        if max_response_tokens is not None:
            ai_kwargs["max_tokens"] = max_response_tokens
        llm_started_at = time.perf_counter()
        try:
            grok_result = await self.ai_service.generate_response(
                ai_messages,
                **ai_kwargs,
            )
        except Exception as error:
            await self.usage_recorder.record_llm_usage(
                channel=channel,
                ai_kwargs=ai_kwargs,
                latency_ms=self.usage_recorder.elapsed_ms(llm_started_at),
                status="failure",
                error_class=error.__class__.__name__,
            )
            raise
        await self.usage_recorder.record_llm_usage(
            channel=channel,
            ai_kwargs=ai_kwargs,
            latency_ms=self.usage_recorder.elapsed_ms(llm_started_at),
            usage=grok_result.usage,
        )
        rex_response = grok_result.text
        unsupported_actions = self.clarity_action_parser.unsupported_actions(
            rex_response,
        )
        assistant_response, clarity_action_proposals = (
            self.clarity_action_parser.extract_proposals(rex_response)
        )
        return (
            self.truth_service.truthful_generated_response(
                assistant_response,
                clarity_action_proposals,
                unsupported_actions=unsupported_actions,
                intent_decision=intent_decision,
                user_message=brain_message,
                memory_status=structured_context.get("memory_status"),
                chat_search_results_loaded=self.truth_service.has_chat_search_results(
                    ai_messages
                ),
                conversation_history=conversation_history,
                turn_trace=turn_trace,
            ),
            clarity_action_proposals,
        )
