from __future__ import annotations

from collections.abc import AsyncIterator
import time
from typing import Optional

from fastapi import UploadFile

from app.services.chat_financial_guard import ChatFinancialGuard
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_context import ChatTurnContextService, MemoryService
from app.services.chat_usage_recorder import ChatUsageRecorder
from app.services.clarity_action_parser import (
    ClarityActionParser,
    ClarityActionStreamFilter,
)
from app.services.file_service import AttachmentContext
from app.services.goal_command_service import GoalCommandService
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
        clarity_action_parser: ClarityActionParser,
        financial_guard: ChatFinancialGuard,
        truth_service: ChatResponseTruthService,
        usage_recorder: ChatUsageRecorder,
        transcript_normalizer: Optional[TranscriptNormalizer] = None,
    ) -> None:
        self.ai_service = ai_service
        self.memory_service = memory_service
        self.simple_rex_brain = simple_rex_brain
        self.chat_turn_context_service = chat_turn_context_service
        self.memory_turn_service = memory_turn_service
        self.goal_command_service = goal_command_service
        self.clarity_action_parser = clarity_action_parser
        self.financial_guard = financial_guard
        self.truth_service = truth_service
        self.usage_recorder = usage_recorder
        self.transcript_normalizer = (
            transcript_normalizer or DEFAULT_TRANSCRIPT_NORMALIZER
        )

    def _brain_messages(self, message: str) -> tuple[str, str]:
        stored_message = message.strip()
        brain_message = self.transcript_normalizer.normalize(stored_message)
        if not brain_message:
            brain_message = stored_message
        return stored_message, brain_message

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
    ) -> dict:
        stored_message, brain_message = self._brain_messages(message)
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
        file_text = turn_context.file_text
        attachment_context = turn_context.attachment_context
        conversation_history = turn_context.conversation_history
        long_term_memory = turn_context.long_term_memory
        structured_context = turn_context.structured_context
        time_context = turn_context.time_context
        accountability_signals = turn_context.accountability_signals
        user_message = turn_context.user_message
        goal_command_turn = await self.goal_command_service.handle_turn(
            brain_message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if goal_command_turn:
            return goal_command_turn
        simple_memory_turn = await self.memory_turn_service.handle_turn(
            brain_message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if simple_memory_turn:
            return simple_memory_turn
        finance_guard_response = self.financial_guard.guard_response(
            intent_decision,
            financial_context,
        )
        if finance_guard_response:
            return await self._guarded_turn_response(
                conversation_id=conversation_id,
                response=finance_guard_response,
                user_message=user_message,
            )
        conversation_history = self.memory_turn_service.public_messages(
            conversation_history
        )
        ai_messages = self.simple_rex_brain.build_prompt_messages(
            message=brain_message,
            conversation_id=conversation_id,
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            file_text=file_text,
            time_context=time_context,
            financial_context=financial_context,
            channel=channel,
        )

        if response_instructions:
            ai_messages.append({"role": "system", "content": response_instructions})

        ai_messages = self._messages_with_attachment(ai_messages, attachment_context)

        ai_kwargs = {}
        if max_response_tokens is not None:
            ai_kwargs["max_tokens"] = max_response_tokens
        llm_started_at = time.perf_counter()
        try:
            rex_response = await self.ai_service.generate_response(
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
        )
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
            memory_status=structured_context.get("memory_status"),
            chat_search_results_loaded=self.truth_service.has_chat_search_results(
                ai_messages
            ),
        )
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            assistant_response,
        )

        memory_changes = self.clarity_action_parser.with_memory_changes(
            None,
            clarity_action_proposals,
        )

        return {
            "conversation_id": conversation_id,
            "response": assistant_response,
            "user_message": user_message,
            "assistant_message": assistant_message,
            "memory_correction": None,
            "memory_changes": memory_changes,
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
    ) -> AsyncIterator[dict]:
        stored_message, brain_message = self._brain_messages(message)
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
        file_text = turn_context.file_text
        attachment_context = turn_context.attachment_context
        conversation_history = turn_context.conversation_history
        long_term_memory = turn_context.long_term_memory
        structured_context = turn_context.structured_context
        time_context = turn_context.time_context
        accountability_signals = turn_context.accountability_signals
        user_message = turn_context.user_message
        yield {"event": "conversation", "conversation_id": conversation_id}
        if include_turn_trace:
            yield self._turn_trace_event(intent_decision, channel)
        goal_command_turn = await self.goal_command_service.handle_turn(
            brain_message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if goal_command_turn:
            yield {"event": "token", "token": goal_command_turn["response"]}
            yield {
                "event": "done",
                "conversation_id": conversation_id,
                "response": goal_command_turn["response"],
                "messages": goal_command_turn["messages"],
                "memory_changes": goal_command_turn["memory_changes"],
                "assistant_message": goal_command_turn["assistant_message"],
            }
            return
        simple_memory_turn = await self.memory_turn_service.handle_turn(
            brain_message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if simple_memory_turn:
            yield {"event": "token", "token": simple_memory_turn["response"]}
            yield {
                "event": "done",
                "conversation_id": conversation_id,
                "response": simple_memory_turn["response"],
                "messages": simple_memory_turn["messages"],
                "memory_changes": simple_memory_turn["memory_changes"],
                "assistant_message": simple_memory_turn["assistant_message"],
            }
            return
        finance_guard_response = self.financial_guard.guard_response(
            intent_decision,
            financial_context,
        )
        if finance_guard_response:
            yield {"event": "token", "token": finance_guard_response}
            assistant_message = await self.memory_service.save_message(
                conversation_id,
                "assistant",
                finance_guard_response,
            )
            yield {
                "event": "done",
                "conversation_id": conversation_id,
                "response": finance_guard_response,
                "messages": await self.memory_turn_service.recent_public_messages(
                    conversation_id
                ),
                "memory_changes": None,
                "assistant_message": assistant_message,
            }
            return
        conversation_history = self.memory_turn_service.public_messages(
            conversation_history
        )
        ai_messages = self.simple_rex_brain.build_prompt_messages(
            message=brain_message,
            conversation_id=conversation_id,
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            file_text=file_text,
            time_context=time_context,
            financial_context=financial_context,
            channel=channel,
        )

        if response_instructions:
            ai_messages.append({"role": "system", "content": response_instructions})

        ai_messages = self._messages_with_attachment(ai_messages, attachment_context)

        response_parts = []
        stream_filter = ClarityActionStreamFilter()
        ai_kwargs = {}
        if max_response_tokens is not None:
            ai_kwargs["max_tokens"] = max_response_tokens
        token_stream = self.ai_service.stream_response(ai_messages, **ai_kwargs)
        llm_started_at = time.perf_counter()
        try:
            async for token in token_stream:
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
            )
            raise
        await self.usage_recorder.record_llm_usage(
            channel=channel,
            ai_kwargs=ai_kwargs,
            latency_ms=self.usage_recorder.elapsed_ms(llm_started_at),
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
            memory_status=structured_context.get("memory_status"),
            chat_search_results_loaded=self.truth_service.has_chat_search_results(
                ai_messages
            ),
        )
        await self.memory_service.save_message(
            conversation_id,
            "assistant",
            assistant_response,
        )

        memory_changes = self.clarity_action_parser.with_memory_changes(
            None,
            clarity_action_proposals,
        )

        yield {
            "event": "done",
            "conversation_id": conversation_id,
            "response": assistant_response,
            "messages": await self.memory_turn_service.recent_public_messages(
                conversation_id
            ),
            "memory_changes": memory_changes,
        }

    def _turn_trace_event(self, intent_decision, channel: RexBrainChannel) -> dict:
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

    def _messages_with_attachment(
        self,
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

    async def _guarded_turn_response(
        self,
        *,
        conversation_id: str,
        response: str,
        user_message: dict,
    ) -> dict:
        assistant_message = await self.memory_service.save_message(
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
            "messages": await self.memory_turn_service.recent_public_messages(
                conversation_id
            ),
        }

