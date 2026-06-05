from collections.abc import AsyncIterator
from typing import Optional

from fastapi import UploadFile

from app.services.ai_service import AIService
from app.services.accountability_service import AccountabilityService
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
from app.services.goal_command_service import GoalCommandService
from app.services.memory_intent_service import MemoryIntentService
from app.services.memory_turn_service import MemoryTurnService
from app.services.prompt_service import PromptService
from app.services.rex_brain import RexBrain
from app.services.rex_brain_chat_service import RexBrainChatService
from app.services.rex_brain_contracts import (
    RexBrainChannel,
)
from app.services.rex_intent_router import RexIntentRouter
from app.services.rex_model_router import RexModelRouter
from app.services.rex_observability import RexBrainObserver
from app.services.time_context_service import TimeContextService


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
        rex_brain_chat_service: Optional[RexBrainChatService] = None,
        rex_brain: Optional[RexBrain] = None,
        rex_model_router: Optional[RexModelRouter] = None,
        rex_brain_observer: Optional[RexBrainObserver] = None,
        rex_intent_router: Optional[RexIntentRouter] = None,
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
        self.rex_brain_chat_service = rex_brain_chat_service or RexBrainChatService(
            rex_brain=rex_brain,
            rex_model_router=rex_model_router,
            rex_brain_observer=rex_brain_observer,
        )
        self.chat_context_service = chat_context_service or ChatContextService(
            memory_service,
            prompt_service=self.prompt_service,
            time_context_service=self.time_context_service,
            accountability_service=self.accountability_service,
            rex_brain_chat_service=self.rex_brain_chat_service,
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
        intent_decision = self.rex_intent_router.classify(
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
        rex_brain_plan = self.rex_brain_chat_service.safe_plan_chat_turn(
            message=message,
            conversation_id=conversation_id,
            file_text=file_text,
            financial_context=financial_context,
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            channel=channel,
            user_requested_deep_thinking=user_requested_deep_thinking,
        )
        request_id = self.rex_brain_chat_service.request_id(
            conversation_id,
            user_message,
        )
        self.rex_brain_chat_service.log_turn(
            rex_brain_plan,
            channel=channel,
            request_id=request_id,
            status="planned",
        )
        ai_messages = self.chat_context_service.build_prompt_messages_for_rex_brain(
            message=message,
            conversation_id=conversation_id,
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            file_text=file_text,
            time_context=time_context,
            financial_context=financial_context,
            rex_brain_plan=rex_brain_plan,
        )

        if response_instructions:
            ai_messages.append({"role": "system", "content": response_instructions})

        ai_messages = self.rex_brain_chat_service.apply_chat_contract(
            ai_messages,
            rex_brain_plan,
        )

        ai_kwargs = self.rex_brain_chat_service.ai_kwargs(rex_brain_plan)
        if max_response_tokens is not None:
            ai_kwargs["max_tokens"] = max_response_tokens
        rex_response = await self.ai_service.generate_response(
            ai_messages,
            **ai_kwargs,
        )
        assistant_response, clarity_action_proposals = (
            self.clarity_action_parser.extract_proposals(rex_response)
        )
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            assistant_response,
        )
        self.rex_brain_chat_service.log_turn(
            rex_brain_plan,
            channel=channel,
            request_id=request_id,
            status="completed",
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
        intent_decision = self.rex_intent_router.classify(
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
        rex_brain_plan = self.rex_brain_chat_service.safe_plan_chat_turn(
            message=message,
            conversation_id=conversation_id,
            file_text=file_text,
            financial_context=financial_context,
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            channel=channel,
            user_requested_deep_thinking=user_requested_deep_thinking,
        )
        request_id = self.rex_brain_chat_service.request_id(
            conversation_id,
            user_message,
        )
        self.rex_brain_chat_service.log_turn(
            rex_brain_plan,
            channel=channel,
            request_id=request_id,
            status="planned",
        )
        ai_messages = self.chat_context_service.build_prompt_messages_for_rex_brain(
            message=message,
            conversation_id=conversation_id,
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            file_text=file_text,
            time_context=time_context,
            financial_context=financial_context,
            rex_brain_plan=rex_brain_plan,
        )

        if response_instructions:
            ai_messages.append({"role": "system", "content": response_instructions})

        ai_messages = self.rex_brain_chat_service.apply_chat_contract(
            ai_messages,
            rex_brain_plan,
        )

        response_parts = []
        stream_filter = ClarityActionStreamFilter()
        ai_kwargs = self.rex_brain_chat_service.ai_kwargs(rex_brain_plan)
        if max_response_tokens is not None:
            ai_kwargs["max_tokens"] = max_response_tokens
        token_stream = self.ai_service.stream_response(ai_messages, **ai_kwargs)
        async for token in token_stream:
            response_parts.append(token)
            for visible_token in stream_filter.feed(token):
                if visible_token:
                    yield {"event": "token", "token": visible_token}
        for visible_token in stream_filter.finish():
            if visible_token:
                yield {"event": "token", "token": visible_token}

        rex_response = "".join(response_parts).strip()
        assistant_response, clarity_action_proposals = (
            self.clarity_action_parser.extract_proposals(rex_response)
        )
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            assistant_response,
        )
        self.rex_brain_chat_service.log_turn(
            rex_brain_plan,
            channel=channel,
            request_id=request_id,
            status="completed",
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
