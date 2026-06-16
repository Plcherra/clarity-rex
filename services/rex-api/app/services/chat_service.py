from collections.abc import AsyncIterator
import time
from typing import Optional

from fastapi import UploadFile

from app.services.ai_service import AIService
from app.services.accountability_service import AccountabilityService
from app.services.action_truth_policy import (
    safe_degraded_memory_search_response,
    safe_old_chat_search_response,
    safe_pending_action_response,
    safe_unexecuted_memory_response,
    safe_unsupported_action_response,
)
from app.services.chat_context_service import ChatContextService
from app.services.chat_turn_context import (
    ChatTurnContextService,
    ConversationNotFoundError,
    MemoryService,
)
from app.services.clarity_action_parser import (
    ClarityActionParser,
    ClarityActionStreamFilter,
)
from app.services.chat_voice_metadata import ChatVoiceMetadataMixin
from app.services.file_service import FileService
from app.services.file_service import AttachmentContext
from app.services.goal_command_service import GoalCommandService
from app.services.memory_intent_service import MemoryIntentService
from app.services.memory_turn_service import MemoryTurnService
from app.services.prompt_service import PromptService
from app.services.rex_brain_contracts import (
    RexBrainChannel,
)
from app.services.rex_intent_router import RexIntent, RexIntentRouter
from app.services.simple_rex_brain import SimpleRexBrain
from app.services.time_context_service import TimeContextService
from app.services.usage_tracking_service import UsageTrackingService


class ChatService(ChatVoiceMetadataMixin):
    def __init__(
        self,
        ai_service: AIService,
        file_service: FileService,
        memory_service: MemoryService,
        prompt_service: Optional[PromptService] = None,
        time_context_service: Optional[TimeContextService] = None,
        accountability_service: Optional[AccountabilityService] = None,
        memory_intent_service: Optional[MemoryIntentService] = None,
        memory_turn_service: Optional[MemoryTurnService] = None,
        goal_command_service: Optional[GoalCommandService] = None,
        chat_context_service: Optional[ChatContextService] = None,
        clarity_action_parser: Optional[ClarityActionParser] = None,
        simple_rex_brain: Optional[SimpleRexBrain] = None,
        rex_intent_router: Optional[RexIntentRouter] = None,
        usage_tracking_service: Optional[UsageTrackingService] = None,
        **experimental_rex_brain_kwargs,
    ) -> None:
        self.ai_service = ai_service
        self.memory_service = memory_service
        self.prompt_service = prompt_service or PromptService()
        self.time_context_service = time_context_service or TimeContextService()
        self.accountability_service = accountability_service or AccountabilityService()
        self.memory_turn_service = memory_turn_service or MemoryTurnService(
            memory_service,
            memory_intent_service=memory_intent_service,
        )
        self.goal_command_service = goal_command_service or GoalCommandService(
            memory_service
        )
        self.clarity_action_parser = clarity_action_parser or ClarityActionParser()
        self.rex_intent_router = rex_intent_router or RexIntentRouter()
        self.usage_tracking_service = usage_tracking_service or UsageTrackingService()
        self.chat_context_service = chat_context_service or ChatContextService(
            memory_service,
            prompt_service=self.prompt_service,
            time_context_service=self.time_context_service,
            accountability_service=self.accountability_service,
        )
        # Production launch brain: one simple Rex Brain surface owns intent and
        # context assembly. Experimental routing kwargs are accepted for old
        # tests/callers but intentionally do not create a second production path.
        _ = experimental_rex_brain_kwargs
        self.simple_rex_brain = simple_rex_brain or SimpleRexBrain(
            intent_router=self.rex_intent_router,
            chat_context_service=self.chat_context_service,
        )
        self.chat_turn_context_service = ChatTurnContextService(
            file_service=file_service,
            memory_service=memory_service,
            chat_context_service=self.chat_context_service,
        )

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
        intent_decision = self.simple_rex_brain.classify(
            message,
            has_file=file is not None,
            has_financial_context=financial_context is not None,
            user_requested_deep_thinking=user_requested_deep_thinking,
        )
        turn_context = await self.chat_turn_context_service.prepare(
            message=message,
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
        simple_memory_turn = await self.memory_turn_service.handle_turn(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if simple_memory_turn:
            return simple_memory_turn
        goal_command_turn = await self.goal_command_service.handle_turn(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if goal_command_turn:
            return goal_command_turn
        conversation_history = self.memory_turn_service.public_messages(
            conversation_history
        )
        ai_messages = self.simple_rex_brain.build_prompt_messages(
            message=message,
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
            await self._record_llm_usage(
                channel=channel,
                ai_kwargs=ai_kwargs,
                latency_ms=self._elapsed_ms(llm_started_at),
                status="failure",
                error_class=error.__class__.__name__,
            )
            raise
        await self._record_llm_usage(
            channel=channel,
            ai_kwargs=ai_kwargs,
            latency_ms=self._elapsed_ms(llm_started_at),
        )
        unsupported_actions = self.clarity_action_parser.unsupported_actions(
            rex_response,
        )
        assistant_response, clarity_action_proposals = (
            self.clarity_action_parser.extract_proposals(rex_response)
        )
        assistant_response = self._truthful_generated_response(
            assistant_response,
            clarity_action_proposals,
            unsupported_actions=unsupported_actions,
            intent_decision=intent_decision,
            memory_status=structured_context.get("memory_status"),
            chat_search_results_loaded=self._has_chat_search_results(ai_messages),
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
        intent_decision = self.simple_rex_brain.classify(
            message,
            has_file=file is not None,
            has_financial_context=financial_context is not None,
            user_requested_deep_thinking=user_requested_deep_thinking,
        )
        turn_context = await self.chat_turn_context_service.prepare(
            message=message,
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
        simple_memory_turn = await self.memory_turn_service.handle_turn(
            message,
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
        goal_command_turn = await self.goal_command_service.handle_turn(
            message,
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
        conversation_history = self.memory_turn_service.public_messages(
            conversation_history
        )
        ai_messages = self.simple_rex_brain.build_prompt_messages(
            message=message,
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
            await self._record_llm_usage(
                channel=channel,
                ai_kwargs=ai_kwargs,
                latency_ms=self._elapsed_ms(llm_started_at),
                status="failure",
                error_class=error.__class__.__name__,
            )
            raise
        await self._record_llm_usage(
            channel=channel,
            ai_kwargs=ai_kwargs,
            latency_ms=self._elapsed_ms(llm_started_at),
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
        assistant_response = self._truthful_generated_response(
            assistant_response,
            clarity_action_proposals,
            unsupported_actions=unsupported_actions,
            intent_decision=intent_decision,
            memory_status=structured_context.get("memory_status"),
            chat_search_results_loaded=self._has_chat_search_results(ai_messages),
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

    def _truthful_generated_response(
        self,
        assistant_response: str,
        clarity_action_proposals: list[dict],
        *,
        unsupported_actions: list[str],
        intent_decision,
        memory_status: object = None,
        chat_search_results_loaded: bool = False,
    ) -> str:
        response = safe_pending_action_response(
            assistant_response,
            clarity_action_proposals,
        )
        if clarity_action_proposals:
            return response
        response = safe_unsupported_action_response(response, unsupported_actions)
        if unsupported_actions:
            return response
        response = safe_degraded_memory_search_response(
            response,
            memory_status=memory_status,
        )
        response = safe_old_chat_search_response(
            response,
            chat_search_results_loaded=chat_search_results_loaded,
            memory_status=memory_status,
        )
        if intent_decision.intent in {RexIntent.MEMORY_SAVE, RexIntent.MEMORY_UPDATE}:
            return safe_unexecuted_memory_response(response)
        return response

    def _has_chat_search_results(self, messages: list[dict]) -> bool:
        for message in messages:
            content = message.get("content")
            if isinstance(content, str) and "Relevant chat search results:" in content:
                return True
        return False

    async def _record_llm_usage(
        self,
        *,
        channel: RexBrainChannel,
        ai_kwargs: dict,
        latency_ms: int,
        status: str = "success",
        error_class: Optional[str] = None,
    ) -> None:
        user_id = getattr(self.memory_service, "user_id", None)
        if not user_id:
            return
        await self.usage_tracking_service.record_llm_turn(
            user_id=user_id,
            surface="assistant",
            channel=channel.value,
            model=self._usage_model(ai_kwargs),
            latency_ms=latency_ms,
            status=status,
            error_class=error_class,
        )

    def _usage_model(self, ai_kwargs: dict) -> str:
        model_override = ai_kwargs.get("model_override")
        if isinstance(model_override, str) and model_override.strip():
            return model_override
        settings = getattr(self.ai_service, "settings", None)
        model = getattr(settings, "grok_model", None)
        return model if isinstance(model, str) and model.strip() else "unknown"

    def _elapsed_ms(self, started_at: float) -> int:
        return max(0, round((time.perf_counter() - started_at) * 1000))
