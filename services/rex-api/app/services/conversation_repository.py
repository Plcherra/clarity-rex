import re
from typing import Optional

from app.services.memory_retrieval_terms import STOP_WORDS

from app.services.memory_errors import MemoryServiceError

CONVERSATION_SELECT = "id,title,timestamp"
MESSAGE_SELECT = "id,conversation_id,role,content,timestamp"
VOICE_TURN_SELECT = (
    "id,conversation_id,user_message_id,assistant_message_id,"
    "transcript_confidence,audio_duration_seconds,input_mime_type,"
    "output_audio_encoding,stt_vendor,tts_vendor,metadata,created_at"
)
FAMILY_TERM_ALIASES = {
    "mom": ("mom", "mother", "mum", "mama"),
    "mother": ("mom", "mother", "mum", "mama"),
    "mum": ("mom", "mother", "mum", "mama"),
    "mama": ("mom", "mother", "mum", "mama"),
    "dad": ("dad", "father", "papa"),
    "father": ("dad", "father", "papa"),
    "papa": ("dad", "father", "papa"),
}
MESSAGE_SEARCH_STOP_WORDS = STOP_WORDS | {
    "anything",
    "know",
    "knows",
    "memories",
    "memory",
    "remember",
    "rex",
}


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

    async def search_messages(
        self,
        query: str,
        limit: int = 50,
        exclude_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        terms = self._search_terms(query)
        if not terms:
            return []

        filters = ",".join(f"content.ilike.*{term}*" for term in terms)
        query_params = {
            "select": MESSAGE_SELECT,
            "or": f"({filters})",
            "order": "timestamp.desc",
            "limit": str(limit),
        }
        if exclude_conversation_id:
            query_params["conversation_id"] = f"neq.{exclude_conversation_id}"
        rows = await self.store._request(
            "GET",
            self.store.settings.supabase_messages_table,
            query=query_params,
        )
        return rows

    async def search_conversations(self, query: str, limit: int = 50) -> list[dict]:
        terms = self._search_terms(query)
        if not terms:
            return []

        results: list[dict] = []
        seen: set[tuple[str, str]] = set()
        title_filters = ",".join(f"title.ilike.*{term}*" for term in terms)
        title_rows = await self.store._request(
            "GET",
            self.store.settings.supabase_conversations_table,
            query={
                "select": CONVERSATION_SELECT,
                "or": f"({title_filters})",
                "order": "timestamp.desc",
                "limit": str(limit),
            },
        )
        for conversation in title_rows:
            conversation_id = str(conversation.get("id") or "")
            if not conversation_id:
                continue
            key = (conversation_id, "title")
            if key in seen:
                continue
            seen.add(key)
            title = str(conversation.get("title") or "").strip()
            results.append(
                {
                    "conversation_id": conversation_id,
                    "conversation_title": conversation.get("title"),
                    "conversation_timestamp": conversation.get("timestamp"),
                    "message": None,
                    "match_type": "title",
                    "preview": title or "Matched conversation title.",
                }
            )
            if len(results) >= limit:
                return results

        message_rows = await self.search_messages(query, limit=limit)
        conversation_cache: dict[str, dict] = {}
        for message in message_rows:
            conversation_id = str(message.get("conversation_id") or "")
            message_id = str(message.get("id") or "")
            if not conversation_id or not message_id:
                continue
            key = (conversation_id, message_id)
            if key in seen:
                continue
            seen.add(key)
            conversation = conversation_cache.get(conversation_id)
            if conversation is None:
                conversation = await self._conversation_by_id(conversation_id)
                conversation_cache[conversation_id] = conversation
            results.append(
                {
                    "conversation_id": conversation_id,
                    "conversation_title": conversation.get("title"),
                    "conversation_timestamp": conversation.get("timestamp"),
                    "message": message,
                    "match_type": "message",
                    "preview": str(message.get("content") or "").strip(),
                }
            )
            if len(results) >= limit:
                break
        return results

    async def delete_conversation(self, conversation_id: str) -> bool:
        if not await self.conversation_exists(conversation_id):
            return False

        await self.store._request(
            "DELETE",
            self.store.settings.supabase_conversations_table,
            query={"id": f"eq.{conversation_id}"},
        )
        return True

    async def _conversation_by_id(self, conversation_id: str) -> dict:
        rows = await self.store._request(
            "GET",
            self.store.settings.supabase_conversations_table,
            query={
                "id": f"eq.{conversation_id}",
                "select": CONVERSATION_SELECT,
                "limit": "1",
            },
        )
        return rows[0] if rows else {}

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

    def _search_terms(self, query: str) -> list[str]:
        raw_terms = [
            self._normalize_search_term(term)
            for term in re.findall(r"[a-z0-9']+", query.lower())
        ]
        expanded_terms = []
        for term in raw_terms:
            if len(term) < 3 or term in MESSAGE_SEARCH_STOP_WORDS:
                continue
            expanded_terms.extend(FAMILY_TERM_ALIASES.get(term, (term,)))

        unique_terms = []
        for term in expanded_terms:
            if term not in unique_terms:
                unique_terms.append(term)
        return unique_terms[:8]

    def _normalize_search_term(self, term: str) -> str:
        normalized = term.strip("'")
        if normalized.endswith("'s"):
            normalized = normalized[:-2]
        return normalized
