from typing import Optional

from app.services.memory_errors import MemoryServiceError

CONVERSATION_SELECT = "id,title,timestamp"
MESSAGE_SELECT = "id,conversation_id,role,content,timestamp"
VOICE_TURN_SELECT = (
    "id,conversation_id,user_message_id,assistant_message_id,"
    "transcript_confidence,audio_duration_seconds,input_mime_type,"
    "output_audio_encoding,stt_vendor,tts_vendor,metadata,created_at"
)


class ConversationRepository:
    def __init__(self, store: object) -> None:
        self.store = store

    async def create_conversation(self) -> str:
        row = await self.create_conversation_record()
        conversation_id = row.get("id")
        if not conversation_id:
            raise MemoryServiceError("Supabase did not return a conversation id.")

        return str(conversation_id)

    async def create_conversation_record(self) -> dict:
        rows = await self.store._request(
            "POST",
            self.store.settings.supabase_conversations_table,
            body={},
            query={"select": CONVERSATION_SELECT},
            prefer="return=representation",
        )
        return self._conversation_with_preview(self.store._first_row(rows), None)

    async def list_conversations(self, limit: int = 50) -> list[dict]:
        rows = await self.store._request(
            "GET",
            self.store.settings.supabase_conversations_table,
            query={
                "select": CONVERSATION_SELECT,
                "order": "timestamp.desc",
                "limit": str(limit),
            },
        )

        conversations = []
        for row in rows:
            conversation_id = str(row.get("id", ""))
            recent_messages = await self.get_recent_messages(
                conversation_id,
                limit=1,
            )
            last_message = recent_messages[-1] if recent_messages else None
            conversations.append(self._conversation_with_preview(row, last_message))

        return conversations

    async def conversation_exists(self, conversation_id: str) -> bool:
        rows = await self.store._request(
            "GET",
            self.store.settings.supabase_conversations_table,
            query={
                "id": f"eq.{conversation_id}",
                "select": "id",
                "limit": "1",
            },
        )
        return bool(rows)

    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        rows = await self.store._request(
            "POST",
            self.store.settings.supabase_messages_table,
            body={
                "conversation_id": conversation_id,
                "role": role,
                "content": content,
            },
            query={"select": MESSAGE_SELECT},
            prefer="return=representation",
        )
        return self.store._first_row(rows)

    async def get_recent_messages(
        self,
        conversation_id: str,
        limit: int = 20,
    ) -> list[dict]:
        rows = await self.store._request(
            "GET",
            self.store.settings.supabase_messages_table,
            query={
                "conversation_id": f"eq.{conversation_id}",
                "select": MESSAGE_SELECT,
                "order": "timestamp.desc",
                "limit": str(limit),
            },
        )
        return list(reversed(rows))

    async def get_conversation_messages(
        self,
        conversation_id: str,
        limit: int = 100,
    ) -> Optional[list[dict]]:
        if not await self.conversation_exists(conversation_id):
            return None

        return await self.get_recent_messages(conversation_id, limit=limit)

    async def delete_conversation(self, conversation_id: str) -> bool:
        if not await self.conversation_exists(conversation_id):
            return False

        await self.store._request(
            "DELETE",
            self.store.settings.supabase_conversations_table,
            query={"id": f"eq.{conversation_id}"},
        )
        return True

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
        rows = await self.store._request(
            "POST",
            self.store.settings.supabase_voice_turns_table,
            body={
                "conversation_id": conversation_id,
                "user_message_id": user_message_id,
                "assistant_message_id": assistant_message_id,
                "transcript_confidence": transcript_confidence,
                "audio_duration_seconds": audio_duration_seconds,
                "input_mime_type": input_mime_type,
                "output_audio_encoding": output_audio_encoding,
                "stt_vendor": stt_vendor,
                "tts_vendor": tts_vendor,
                "metadata": metadata or {},
            },
            query={"select": VOICE_TURN_SELECT},
            prefer="return=representation",
        )
        return self.store._first_row(rows)

    def _conversation_with_preview(
        self,
        row: dict,
        last_message: Optional[dict],
    ) -> dict:
        return {
            "id": str(row.get("id", "")),
            "title": row.get("title"),
            "timestamp": row.get("timestamp"),
            "last_message": last_message,
        }
