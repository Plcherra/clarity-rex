from dataclasses import dataclass
from typing import Optional, Protocol

from fastapi import UploadFile

from app.services.chat_context_service import ChatContextService
from app.services.file_service import AttachmentContext, FileService
from app.services.rex_intent_router import RexIntentDecision


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

    async def get_conversation_messages(
        self,
        conversation_id: str,
        limit: int = 100,
    ) -> Optional[list[dict]]:
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

    async def search_messages(
        self,
        query: str,
        limit: int = 50,
        exclude_conversation_id: Optional[str] = None,
        offset: int = 0,
    ) -> list[dict]:
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


@dataclass(frozen=True)
class ChatTurnContext:
    conversation_id: str
    file_text: Optional[str]
    attachment_context: Optional[AttachmentContext]
    conversation_history: list[dict]
    long_term_memory: list[dict]
    structured_context: dict
    time_context: dict
    accountability_signals: list
    user_message: dict


class ChatTurnContextService:
    def __init__(
        self,
        *,
        file_service: FileService,
        memory_service: MemoryService,
        chat_context_service: ChatContextService,
    ) -> None:
        self.file_service = file_service
        self.memory_service = memory_service
        self.chat_context_service = chat_context_service

    async def prepare(
        self,
        *,
        message: str,
        conversation_id: Optional[str],
        file: Optional[UploadFile],
        intent_decision: Optional[RexIntentDecision] = None,
    ) -> ChatTurnContext:
        conversation_id = await self.existing_conversation_id(conversation_id)
        attachment_context = (
            await self.file_service.read_attachment(file) if file else None
        )
        file_text = attachment_context.prompt_context if attachment_context else None

        (
            conversation_history,
            long_term_memory,
            structured_context,
        ) = await self.chat_context_service.fetch_prompt_context(
            message=message,
            conversation_id=conversation_id,
            intent_decision=intent_decision,
        )

        if conversation_id is None:
            conversation_id = await self.memory_service.create_conversation()

        time_context = self.chat_context_service.current_time_context(
            conversation_history
        )
        accountability_signals = []
        if self.chat_context_service.should_analyze_accountability(intent_decision):
            accountability_signals = (
                await self.chat_context_service.accountability_signals(
                    message=message,
                    time_context=time_context,
                    long_term_memory=long_term_memory,
                    structured_context=structured_context,
                )
            )
        user_message = await self.memory_service.save_message(
            conversation_id,
            "user",
            message,
        )

        return ChatTurnContext(
            conversation_id=conversation_id,
            file_text=file_text,
            attachment_context=attachment_context,
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            time_context=time_context,
            accountability_signals=accountability_signals,
            user_message=user_message,
        )

    async def existing_conversation_id(
        self,
        conversation_id: Optional[str],
    ) -> Optional[str]:
        if conversation_id is None:
            return None

        if not await self.memory_service.conversation_exists(conversation_id):
            raise ConversationNotFoundError()

        return conversation_id
