"""Thin turn orchestrator: settings + recent chat + thread titles → Grok → Truth."""

from __future__ import annotations

from collections.abc import AsyncIterator
import time
from typing import Optional

from fastapi import UploadFile

from app.services.action_fence_stream import ActionFenceStreamFilter
from app.services.chat_financial_guard import ChatFinancialGuard
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_context import ChatTurnContextService, MemoryService
from app.services.chat_turn_observability import ChatTurnObserver
from app.services.chat_turn_orchestrator_support import (
    annotate_pending_action,
    annotate_proposal_settings,
    brain_messages,
    finish_short_circuit,
    load_pending_action,
)
from app.services.chat_turn_reply import (
    build_truthful_turn_reply,
    memory_changes_for_phase_b,
)
from app.services.chat_usage_recorder import ChatUsageRecorder
from app.services.clarity_action_parser import ClarityActionParser
from app.services.durable_write_service import DurableWriteService
from app.services.grok_prompt_logging import log_grok_prompt_messages
from app.services.grok_turn_brain import GrokTurnBrain
from app.services.grok_usage import GrokUsageHolder
from app.services.open_thread_context_loader import load_open_threads_context
from app.services.rex_channel import RexBrainChannel
from app.services.transcript_normalizer import (
    DEFAULT_TRANSCRIPT_NORMALIZER,
    TranscriptNormalizer,
)

# Soft cap for natural replies (not reply-length styles).
_DEFAULT_MAX_TOKENS = 1200


class ChatTurnOrchestrator:
    def __init__(
        self,
        *,
        ai_service,
        memory_service: MemoryService,
        chat_turn_context_service: ChatTurnContextService,
        durable_write_service: DurableWriteService,
        clarity_action_parser: ClarityActionParser,
        financial_guard: ChatFinancialGuard,
        truth_service: ChatResponseTruthService,
        usage_recorder: ChatUsageRecorder,
        grok_turn_brain: Optional[GrokTurnBrain] = None,
        transcript_normalizer: Optional[TranscriptNormalizer] = None,
        turn_observer: Optional[ChatTurnObserver] = None,
    ) -> None:
        self.ai_service = ai_service
        self.memory_service = memory_service
        self.chat_turn_context_service = chat_turn_context_service
        self.durable_write_service = durable_write_service
        self.clarity_action_parser = clarity_action_parser
        self.financial_guard = financial_guard
        self.truth_service = truth_service
        self.usage_recorder = usage_recorder
        self.grok_turn_brain = grok_turn_brain or GrokTurnBrain(ai_service=ai_service)
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
            user_requested_deep_thinking,
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
            intent="just_chat",
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

        recent = await self._recent_public_messages(conversation_id)
        history = [item for item in recent[:-1]] if recent else []
        thread_block = await self._open_thread_titles_block()
        ai_messages = self.grok_turn_brain.build_messages(
            user_message=brain_message,
            recent_messages=history,
            proposal_settings=turn_context.proposal_settings,
            open_thread_titles_block=thread_block,
            locale=locale,
        )
        resolved_max = max_response_tokens or _DEFAULT_MAX_TOKENS
        log_grok_prompt_messages(
            ai_messages,
            channel=channel.value,
            conversation_id=conversation_id,
        )
        llm_started_at = time.perf_counter()
        try:
            grok_result = await self.grok_turn_brain.generate(
                ai_messages,
                max_tokens=resolved_max,
            )
        except Exception as error:
            await self.usage_recorder.record_llm_usage(
                channel=channel,
                ai_kwargs={"max_tokens": resolved_max},
                latency_ms=self.usage_recorder.elapsed_ms(llm_started_at),
                status="failure",
                error_class=error.__class__.__name__,
            )
            raise
        await self.usage_recorder.record_llm_usage(
            channel=channel,
            ai_kwargs={"max_tokens": resolved_max},
            latency_ms=self.usage_recorder.elapsed_ms(llm_started_at),
            usage=grok_result.usage,
        )
        assistant_response, proposals, gate = self._truthful_reply(
            grok_result.text,
            brain_message=brain_message,
            conversation_history=history,
            turn_trace=turn_trace,
            proposal_settings=turn_context.proposal_settings,
            ai_messages=ai_messages,
        )
        memory_changes = memory_changes_for_phase_b(
            self.clarity_action_parser,
            clarity_proposals=proposals,
            gate=gate,
        )
        finish_short_circuit(
            self.turn_observer,
            self.usage_recorder,
            turn_trace,
            turn_started_at,
            "llm",
            turn_result={"memory_changes": memory_changes},
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
            "memory_changes": memory_changes,
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
            user_requested_deep_thinking,
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
            intent="just_chat",
        )
        annotate_proposal_settings(turn_trace, turn_context)
        yield {"event": "conversation", "conversation_id": conversation_id}
        if include_turn_trace:
            yield {
                "event": "turn.trace",
                "intent": "just_chat",
                "intent_reasons": ["plan_05_phase_b"],
                "channel": channel.value,
                "loaded_context": {"thin_base": True},
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

        recent = await self._recent_public_messages(conversation_id)
        history = [item for item in recent[:-1]] if recent else []
        thread_block = await self._open_thread_titles_block()
        ai_messages = self.grok_turn_brain.build_messages(
            user_message=brain_message,
            recent_messages=history,
            proposal_settings=turn_context.proposal_settings,
            open_thread_titles_block=thread_block,
            locale=locale,
        )
        resolved_max = max_response_tokens or _DEFAULT_MAX_TOKENS
        log_grok_prompt_messages(
            ai_messages,
            channel=channel.value,
            conversation_id=conversation_id,
        )
        response_parts: list[str] = []
        stream_filter = ActionFenceStreamFilter()
        llm_started_at = time.perf_counter()
        usage_holder = GrokUsageHolder()
        try:
            async for token in self.grok_turn_brain.stream(
                ai_messages,
                max_tokens=resolved_max,
                usage_holder=usage_holder,
            ):
                response_parts.append(token)
                for visible in stream_filter.feed(token):
                    if visible:
                        yield {"event": "token", "token": visible}
        except Exception as error:
            await self.usage_recorder.record_llm_usage(
                channel=channel,
                ai_kwargs={"max_tokens": resolved_max},
                latency_ms=self.usage_recorder.elapsed_ms(llm_started_at),
                status="failure",
                error_class=error.__class__.__name__,
                usage=usage_holder.usage,
            )
            raise
        await self.usage_recorder.record_llm_usage(
            channel=channel,
            ai_kwargs={"max_tokens": resolved_max},
            latency_ms=self.usage_recorder.elapsed_ms(llm_started_at),
            usage=usage_holder.usage,
        )
        for visible in stream_filter.finish():
            if visible:
                yield {"event": "token", "token": visible}

        assistant_response, proposals, gate = self._truthful_reply(
            "".join(response_parts).strip(),
            brain_message=brain_message,
            conversation_history=history,
            turn_trace=turn_trace,
            proposal_settings=turn_context.proposal_settings,
            ai_messages=ai_messages,
        )
        memory_changes = memory_changes_for_phase_b(
            self.clarity_action_parser,
            clarity_proposals=proposals,
            gate=gate,
        )
        finish_short_circuit(
            self.turn_observer,
            self.usage_recorder,
            turn_trace,
            turn_started_at,
            "llm",
            turn_result={"memory_changes": memory_changes},
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
            "messages": await self._recent_public_messages(conversation_id),
            "memory_changes": memory_changes,
        }

    def _truthful_reply(
        self,
        rex_response: str,
        *,
        brain_message: str,
        conversation_history: list[dict],
        turn_trace,
        proposal_settings,
        ai_messages: list[dict],
    ):
        return build_truthful_turn_reply(
            rex_response,
            clarity_action_parser=self.clarity_action_parser,
            truth_service=self.truth_service,
            proposal_settings=proposal_settings,
            brain_message=brain_message,
            conversation_history=conversation_history,
            turn_trace=turn_trace,
            ai_messages=ai_messages,
        )

    async def _open_thread_titles_block(self) -> Optional[str]:
        packed = await load_open_threads_context(self.memory_service, "")
        block = packed.get("open_threads_context")
        if isinstance(block, str) and block.strip():
            return block.strip()
        return None

    async def _recent_public_messages(self, conversation_id: str) -> list[dict]:
        messages = await self.memory_service.get_recent_messages(
            conversation_id,
            limit=12,
        )
        return [
            message
            for message in messages
            if str(message.get("role") or "") in {"user", "assistant"}
        ]
