from typing import Optional

from app.services.chat_search_ranking import ChatSearchRanking
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
        self.search_ranking = ChatSearchRanking()

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

    async def list_messages(
        self,
        limit: int = 200,
        offset: int = 0,
        exclude_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        query_params = {
            "select": MESSAGE_SELECT,
            "order": "timestamp.desc",
            "limit": str(limit),
        }
        if offset > 0:
            query_params["offset"] = str(offset)
        if exclude_conversation_id:
            query_params["conversation_id"] = f"neq.{exclude_conversation_id}"

        return await self.store._request(
            "GET",
            self.store.settings.supabase_messages_table,
            query=query_params,
        )

    async def search_messages(
        self,
        query: str,
        limit: int = 50,
        exclude_conversation_id: Optional[str] = None,
        offset: int = 0,
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
        if offset > 0:
            query_params["offset"] = str(offset)
        if exclude_conversation_id:
            query_params["conversation_id"] = f"neq.{exclude_conversation_id}"
        rows = await self.store._request(
            "GET",
            self.store.settings.supabase_messages_table,
            query=query_params,
        )
        return self._rank_messages(query, rows)

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
            score = self.search_ranking.score_text(
                query,
                title,
                timestamp=str(conversation.get("timestamp") or ""),
                title_match=True,
            )
            results.append(
                {
                    "conversation_id": conversation_id,
                    "conversation_title": conversation.get("title"),
                    "conversation_timestamp": conversation.get("timestamp"),
                    "message": None,
                    "match_type": "title",
                    "preview": title or "Matched conversation title.",
                    "relevance_score": score.score,
                    "search_reason": score.reason,
                    "matched_terms": list(score.matched_terms),
                }
            )

        message_rows = await self.search_messages(query, limit=limit)
        repeated_counts: dict[str, int] = {}
        for message in message_rows:
            conversation_id = str(message.get("conversation_id") or "")
            if conversation_id:
                repeated_counts[conversation_id] = repeated_counts.get(
                    conversation_id,
                    0,
                ) + 1

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
            score = self.search_ranking.score_text(
                query,
                str(message.get("content") or ""),
                role=str(message.get("role") or ""),
                timestamp=str(message.get("timestamp") or ""),
                repeated_mentions=repeated_counts.get(conversation_id, 1),
            )
            results.append(
                {
                    "conversation_id": conversation_id,
                    "conversation_title": conversation.get("title"),
                    "conversation_timestamp": conversation.get("timestamp"),
                    "message": message,
                    "match_type": "message",
                    "preview": str(message.get("content") or "").strip(),
                    "relevance_score": score.score,
                    "search_reason": score.reason,
                    "matched_terms": list(score.matched_terms),
                }
            )
        results.sort(
            key=lambda result: (
                float(result.get("relevance_score") or 0),
                str(result.get("conversation_timestamp") or ""),
            ),
            reverse=True,
        )
        return results[:limit]

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
        return self.search_ranking.expand_terms(query, max_terms=8)

    def _normalize_search_term(self, term: str) -> str:
        return self.search_ranking.normalize_term(term)

    def _simple_term_variants(self, term: str) -> tuple[str, ...]:
        return self.search_ranking.simple_term_variants(term)

    def _rank_messages(self, query: str, rows: list[dict]) -> list[dict]:
        ranked = []
        for row in rows:
            score = self.search_ranking.score_text(
                query,
                str(row.get("content") or ""),
                role=str(row.get("role") or ""),
                timestamp=str(row.get("timestamp") or ""),
            )
            ranked.append(
                {
                    **row,
                    "relevance_score": score.score,
                    "search_reason": score.reason,
                    "matched_terms": list(score.matched_terms),
                }
            )
        ranked.sort(
            key=lambda item: (
                float(item.get("relevance_score") or 0),
                str(item.get("timestamp") or ""),
            ),
            reverse=True,
        )
        return ranked
