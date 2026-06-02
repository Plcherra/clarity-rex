import logging
from collections.abc import AsyncIterator
from typing import Optional, Protocol

from fastapi import UploadFile

from app.services.ai_service import AIService
from app.services.accountability_service import AccountabilityService
from app.services.chat_context_service import ChatContextService
from app.services.clarity_action_parser import (
    ClarityActionParser,
    ClarityActionStreamFilter,
)
from app.services.file_service import FileService
from app.services.memory_candidate_decision_service import (
    MemoryCandidateDecisionService,
)
from app.services.memory_candidate_service import MemoryCandidateService
from app.services.memory_extraction_service import MemoryExtractionService
from app.services.memory_correction_service import MemoryCorrectionService
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_intent_service import MemoryIntentService
from app.services.memory_post_turn_service import MemoryPostTurnService
from app.services.memory_turn_service import MemoryTurnService
from app.services.prompt_service import PromptService
from app.services.rex_brain import RexBrain
from app.services.rex_brain_chat_service import RexBrainChatService
from app.services.rex_brain_contracts import (
    RexBrainChannel,
)
from app.services.rex_model_router import RexModelRouter
from app.services.rex_observability import RexBrainObserver
from app.services.time_context_service import TimeContextService

LOGGER = logging.getLogger("rex.chat")


class ConversationNotFoundError(Exception):
    pass


class MemoryService(Protocol):
    async def create_conversation(self) -> str:
        pass

    async def conversation_exists(self, conversation_id: str) -> bool:
        pass

    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        pass

    async def get_recent_messages(
        self,
        conversation_id: str,
        limit: int = 20,
    ) -> list[dict]:
        pass

    async def save_long_term_memory(
        self,
        memory_type: str,
        content: str,
        source_conversation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
        importance: int = 3,
    ) -> dict:
        pass

    async def get_relevant_memories(self, query: str, limit: int = 8) -> list[dict]:
        pass

    async def get_structured_memory_context(self, query: str) -> dict:
        pass

    async def save_voice_turn(
        self,
        conversation_id: str,
        user_message_id: Optional[str] = None,
        assistant_message_id: Optional[str] = None,
        transcript_confidence: Optional[float] = None,
        audio_duration_seconds: Optional[float] = None,
        input_mime_type: Optional[str] = None,
        output_audio_encoding: Optional[str] = None,
        stt_vendor: str = "deepgram",
        tts_vendor: str = "google_tts",
        metadata: Optional[dict] = None,
    ) -> dict:
        pass


class ChatService:
    def __init__(
        self,
        ai_service: AIService,
        file_service: FileService,
        memory_service: MemoryService,
        memory_extraction_service: Optional[MemoryExtractionService] = None,
        prompt_service: Optional[PromptService] = None,
        time_context_service: Optional[TimeContextService] = None,
        accountability_service: Optional[AccountabilityService] = None,
        memory_discipline_service: Optional[MemoryDisciplineService] = None,
        memory_correction_service: Optional[MemoryCorrectionService] = None,
        memory_candidate_service: Optional[MemoryCandidateService] = None,
        memory_intent_service: Optional[MemoryIntentService] = None,
        memory_turn_service: Optional[MemoryTurnService] = None,
        memory_candidate_decision_service: Optional[
            MemoryCandidateDecisionService
        ] = None,
        chat_context_service: Optional[ChatContextService] = None,
        memory_post_turn_service: Optional[MemoryPostTurnService] = None,
        clarity_action_parser: Optional[ClarityActionParser] = None,
        rex_brain_chat_service: Optional[RexBrainChatService] = None,
        rex_brain: Optional[RexBrain] = None,
        rex_model_router: Optional[RexModelRouter] = None,
        rex_brain_observer: Optional[RexBrainObserver] = None,
    ) -> None:
        self.ai_service = ai_service
        self.file_service = file_service
        self.memory_service = memory_service
        self.memory_extraction_service = memory_extraction_service
        self.prompt_service = prompt_service or PromptService()
        self.time_context_service = time_context_service or TimeContextService()
        self.accountability_service = accountability_service or AccountabilityService()
        self.memory_discipline_service = memory_discipline_service
        self.memory_correction_service = memory_correction_service
        self.memory_candidate_service = memory_candidate_service
        self.memory_candidate_decision_service = (
            memory_candidate_decision_service
            or MemoryCandidateDecisionService(memory_candidate_service)
        )
        self.memory_turn_service = memory_turn_service or MemoryTurnService(
            memory_service,
            memory_intent_service=memory_intent_service,
        )
        self.clarity_action_parser = clarity_action_parser or ClarityActionParser()
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
        self.memory_post_turn_service = (
            memory_post_turn_service
            or MemoryPostTurnService(
                memory_extraction_service=memory_extraction_service,
                memory_correction_service=memory_correction_service,
                memory_candidate_service=memory_candidate_service,
            )
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
        conversation_id = await self._existing_conversation_id(conversation_id)
        file_text = await self.file_service.read_text_file(file) if file else None

        (
            conversation_history,
            long_term_memory,
            structured_context,
        ) = await self.chat_context_service.fetch_prompt_context(
            message=message,
            conversation_id=conversation_id,
        )

        if conversation_id is None:
            conversation_id = await self.memory_service.create_conversation()

        time_context = self.chat_context_service.current_time_context(
            conversation_history
        )
        accountability_signals = await self.chat_context_service.accountability_signals(
            message=message,
            time_context=time_context,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
        )

        user_message = await self.memory_service.save_message(
            conversation_id,
            "user",
            message,
        )
        simple_memory_turn = await self.memory_turn_service.handle_turn(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if simple_memory_turn:
            return simple_memory_turn

        candidate_decision = await self.memory_candidate_decision_service.handle_decision(
            message,
            conversation_id=conversation_id,
        )
        if candidate_decision:
            assistant_message = await self.memory_service.save_message(
                conversation_id,
                "assistant",
                candidate_decision["response"],
            )
            return {
                "conversation_id": conversation_id,
                "response": candidate_decision["response"],
                "user_message": user_message,
                "assistant_message": assistant_message,
                "memory_correction": None,
                "memory_changes": candidate_decision["memory_changes"],
                "messages": await self.memory_turn_service.recent_public_messages(
                    conversation_id
                ),
            }
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
        brain_metadata = self.rex_brain_chat_service.memory_metadata(rex_brain_plan)
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

        memory_correction = await self.memory_post_turn_service.apply_memory_correction(
            message,
            conversation_id=conversation_id,
            user_message_id=str(user_message.get("id") or ""),
            brain_metadata=brain_metadata,
        )
        if memory_correction:
            ai_messages.append(
                self.memory_post_turn_service.memory_correction_prompt(
                    memory_correction
                )
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

        memory_changes = None
        if self.memory_post_turn_service.correction_blocks_extraction(
            memory_correction
        ):
            memory_changes = self.memory_post_turn_service.memory_change_summary(
                [],
                memory_correction=memory_correction,
                skipped_reason="correction_already_handled",
            )
        else:
            extracted_memories = (
                await self.memory_post_turn_service.extract_memory_after_success(
                    conversation_id,
                    user_message,
                    assistant_message,
                    brain_metadata=brain_metadata,
                )
            )
            memory_changes = self.memory_post_turn_service.memory_change_summary(
                extracted_memories,
                memory_correction=memory_correction,
            )
        memory_changes = self.clarity_action_parser.with_memory_changes(
            memory_changes,
            clarity_action_proposals,
        )

        return {
            "conversation_id": conversation_id,
            "response": assistant_response,
            "user_message": user_message,
            "assistant_message": assistant_message,
            "memory_correction": memory_correction,
            "memory_changes": memory_changes,
            "messages": await self.memory_turn_service.recent_public_messages(
                conversation_id
            ),
        }

    async def save_voice_turn_metadata(
        self,
        conversation_id: str,
        user_message_id: Optional[str] = None,
        assistant_message_id: Optional[str] = None,
        transcript_confidence: Optional[float] = None,
        audio_duration_seconds: Optional[float] = None,
        input_mime_type: Optional[str] = None,
        output_audio_encoding: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        try:
            return await self.memory_service.save_voice_turn(
                conversation_id=conversation_id,
                user_message_id=user_message_id,
                assistant_message_id=assistant_message_id,
                transcript_confidence=transcript_confidence,
                audio_duration_seconds=audio_duration_seconds,
                input_mime_type=input_mime_type,
                output_audio_encoding=output_audio_encoding,
                metadata=metadata,
            )
        except Exception:
            # Voice metadata is useful for debugging, but raw conversation
            # success should not depend on trace metadata persistence.
            return None

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
    ) -> AsyncIterator[dict]:
        conversation_id = await self._existing_conversation_id(conversation_id)
        file_text = await self.file_service.read_text_file(file) if file else None

        (
            conversation_history,
            long_term_memory,
            structured_context,
        ) = await self.chat_context_service.fetch_prompt_context(
            message=message,
            conversation_id=conversation_id,
        )

        if conversation_id is None:
            conversation_id = await self.memory_service.create_conversation()

        time_context = self.chat_context_service.current_time_context(
            conversation_history
        )
        accountability_signals = await self.chat_context_service.accountability_signals(
            message=message,
            time_context=time_context,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
        )

        user_message = await self.memory_service.save_message(
            conversation_id,
            "user",
            message,
        )
        yield {"event": "conversation", "conversation_id": conversation_id}
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

        candidate_decision = await self.memory_candidate_decision_service.handle_decision(
            message,
            conversation_id=conversation_id,
        )
        if candidate_decision:
            assistant_message = await self.memory_service.save_message(
                conversation_id,
                "assistant",
                candidate_decision["response"],
            )
            yield {
                "event": "memory_candidate_decision",
                "memory_candidate_decision": candidate_decision,
            }
            yield {
                "event": "done",
                "conversation_id": conversation_id,
                "response": candidate_decision["response"],
                "messages": await self.memory_turn_service.recent_public_messages(
                    conversation_id
                ),
                "memory_changes": candidate_decision["memory_changes"],
                "assistant_message": assistant_message,
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
        brain_metadata = self.rex_brain_chat_service.memory_metadata(rex_brain_plan)
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

        memory_correction = await self.memory_post_turn_service.apply_memory_correction(
            message,
            conversation_id=conversation_id,
            user_message_id=str(user_message.get("id") or ""),
            brain_metadata=brain_metadata,
        )
        if memory_correction:
            ai_messages.append(
                self.memory_post_turn_service.memory_correction_prompt(
                    memory_correction
                )
            )
            yield {"event": "memory_correction", "memory_correction": memory_correction}

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

        memory_changes = None
        if self.memory_post_turn_service.correction_blocks_extraction(
            memory_correction
        ):
            memory_changes = self.memory_post_turn_service.memory_change_summary(
                [],
                memory_correction=memory_correction,
                skipped_reason="correction_already_handled",
            )
        else:
            self.memory_post_turn_service.schedule_memory_extraction(
                conversation_id,
                user_message,
                assistant_message,
                brain_metadata=brain_metadata,
            )
        memory_changes = self.clarity_action_parser.with_memory_changes(
            memory_changes,
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

    async def _existing_conversation_id(
        self,
        conversation_id: Optional[str],
    ) -> Optional[str]:
        if conversation_id is None:
            return None

        if not await self.memory_service.conversation_exists(conversation_id):
            raise ConversationNotFoundError()

        return conversation_id
