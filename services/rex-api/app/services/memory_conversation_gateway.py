from __future__ import annotations

from typing import Optional

from app.services.conversation_repository import ConversationRepository


class MemoryConversationGateway:
    def _get_conversation_repository(self) -> ConversationRepository:
        repository = getattr(self, "conversation_repository", None)
        if repository is None:
            repository = ConversationRepository(self)
            self.conversation_repository = repository
        return repository

    async def create_conversation(self) -> str:
        return await self._get_conversation_repository().create_conversation()

    async def create_conversation_record(self) -> dict:
        return await self._get_conversation_repository().create_conversation_record()

    async def list_conversations(self, limit: int = 50) -> list[dict]:
        return await self._get_conversation_repository().list_conversations(limit=limit)

    async def conversation_exists(self, conversation_id: str) -> bool:
        return await self._get_conversation_repository().conversation_exists(
            conversation_id,
        )

    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        return await self._get_conversation_repository().save_message(
            conversation_id,
            role,
            content,
        )

    async def get_recent_messages(
        self,
        conversation_id: str,
        limit: int = 20,
    ) -> list[dict]:
        return await self._get_conversation_repository().get_recent_messages(
            conversation_id,
            limit=limit,
        )

    async def get_conversation_messages(
        self,
        conversation_id: str,
        limit: int = 100,
    ) -> Optional[list[dict]]:
        return await self._get_conversation_repository().get_conversation_messages(
            conversation_id,
            limit=limit,
        )

    async def list_messages(
        self,
        limit: int = 200,
        offset: int = 0,
        exclude_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        return await self._get_conversation_repository().list_messages(
            limit=limit,
            offset=offset,
            exclude_conversation_id=exclude_conversation_id,
        )

    async def search_messages(
        self,
        query: str,
        limit: int = 50,
        exclude_conversation_id: Optional[str] = None,
        offset: int = 0,
    ) -> list[dict]:
        return await self._get_conversation_repository().search_messages(
            query,
            limit=limit,
            exclude_conversation_id=exclude_conversation_id,
            offset=offset,
        )

    async def search_conversations(
        self,
        query: str,
        limit: int = 50,
        exclude_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        return await self._get_conversation_repository().search_conversations(
            query,
            limit=limit,
            exclude_conversation_id=exclude_conversation_id,
        )

    async def search_chat_history(
        self,
        query: str,
        limit: int = 50,
        exclude_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        return await self._get_conversation_repository().search_chat_history(
            query,
            limit=limit,
            exclude_conversation_id=exclude_conversation_id,
        )

    async def delete_conversation(self, conversation_id: str) -> bool:
        return await self._get_conversation_repository().delete_conversation(
            conversation_id,
        )

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
        return await self._get_conversation_repository().save_voice_turn(
            conversation_id=conversation_id,
            user_message_id=user_message_id,
            assistant_message_id=assistant_message_id,
            transcript_confidence=transcript_confidence,
            audio_duration_seconds=audio_duration_seconds,
            input_mime_type=input_mime_type,
            output_audio_encoding=output_audio_encoding,
            stt_vendor=stt_vendor,
            tts_vendor=tts_vendor,
            metadata=metadata,
        )
