from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Optional

from fastapi import UploadFile

from app.services.ai_service import AIService
from app.services.accountability_service import AccountabilityService
from app.services.chat_context_service import ChatContextService
from app.services.chat_financial_guard import (
    FINANCIAL_CONTEXT_UNAVAILABLE_RESPONSE,
    ChatFinancialGuard,
)
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_context import (
    ChatTurnContextService,
    ConversationNotFoundError,
    MemoryService,
)
from app.services.chat_turn_orchestrator import ChatTurnOrchestrator
from app.services.chat_usage_recorder import ChatUsageRecorder
from app.services.chat_voice_metadata import ChatVoiceMetadataMixin
from app.services.clarity_action_parser import ClarityActionParser
from app.services.file_service import FileService
from app.services.goal_command_service import GoalCommandService
from app.services.conversational_plan_service import ConversationalPlanService
from app.services.durable_write_service import DurableWriteService
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_intent_service import MemoryIntentService
from app.services.memory_turn_service import MemoryTurnService
from app.services.prompt_service import PromptService
from app.services.rex_channel import RexBrainChannel
from app.services.rex_intent_router import RexIntentRouter
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
        discipline = MemoryDisciplineService(memory_service)
        self.goal_command_service = goal_command_service or GoalCommandService(
            memory_service
        )
        self.conversational_plan_service = ConversationalPlanService(
            memory_service,
            discipline=discipline,
            plan_service=self.goal_command_service.plan_service,
            commitment_service=self.goal_command_service.commitment_service,
        )
        self.durable_write_service = DurableWriteService(
            memory_service,
            plan_service=self.conversational_plan_service.plan_service,
            conversational_plan_service=self.conversational_plan_service,
        )
        self.memory_turn_service = memory_turn_service or MemoryTurnService(
            memory_service,
            memory_intent_service=memory_intent_service,
            discipline=discipline,
            durable_write_service=self.durable_write_service,
        )
        self.goal_command_service.durable_write_service = self.durable_write_service
        if memory_turn_service is not None:
            self.memory_turn_service.durable_write_service = self.durable_write_service
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
        self.financial_guard = ChatFinancialGuard()
        self.truth_service = ChatResponseTruthService()
        self.usage_recorder = ChatUsageRecorder(
            ai_service=ai_service,
            memory_service=memory_service,
            usage_tracking_service=self.usage_tracking_service,
        )
        self.turn_orchestrator = ChatTurnOrchestrator(
            ai_service=ai_service,
            memory_service=memory_service,
            simple_rex_brain=self.simple_rex_brain,
            chat_turn_context_service=self.chat_turn_context_service,
            memory_turn_service=self.memory_turn_service,
            goal_command_service=self.goal_command_service,
            conversational_plan_service=self.conversational_plan_service,
            durable_write_service=self.durable_write_service,
            clarity_action_parser=self.clarity_action_parser,
            financial_guard=self.financial_guard,
            truth_service=self.truth_service,
            usage_recorder=self.usage_recorder,
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
        locale: Optional[str] = None,
        write_confirmation: Optional[dict] = None,
    ) -> dict:
        return await self.turn_orchestrator.send_message(
            message=message,
            conversation_id=conversation_id,
            file=file,
            financial_context=financial_context,
            response_instructions=response_instructions,
            max_response_tokens=max_response_tokens,
            channel=channel,
            user_requested_deep_thinking=user_requested_deep_thinking,
            locale=locale,
            write_confirmation=write_confirmation,
        )

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
        async for event in self.turn_orchestrator.stream_message(
            message=message,
            conversation_id=conversation_id,
            file=file,
            response_instructions=response_instructions,
            max_response_tokens=max_response_tokens,
            financial_context=financial_context,
            channel=channel,
            user_requested_deep_thinking=user_requested_deep_thinking,
            include_turn_trace=include_turn_trace,
            locale=locale,
            write_confirmation=write_confirmation,
        ):
            yield event
