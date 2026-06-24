import logging
from typing import Optional

from app.services.chat_recall_filters import (
    is_chat_search_no_result_message,
    is_memory_rejection_message,
)


CHAT_SEARCH_EMBEDDING_SELECT = (
    "id,conversation_id,message_id,source_kind,content_hash,embedding_model,"
    "created_at,updated_at"
)
LOGGER = logging.getLogger("rex.context")


class ChatEmbeddingRepository:
    def __init__(self, store: object) -> None:
        self.store = store

    async def save_message_chat_embedding(self, message: dict) -> None:
        if not self.should_embed_message(message):
            return
        await self.save_chat_search_embedding(
            conversation_id=str(message.get("conversation_id") or ""),
            message_id=str(message.get("id") or ""),
            source_kind="message",
            content=str(message.get("content") or ""),
        )

    async def save_conversation_summary_embedding(
        self,
        *,
        conversation_id: str,
        summary: str,
    ) -> None:
        await self.save_chat_search_embedding(
            conversation_id=conversation_id,
            message_id=None,
            source_kind="conversation_summary",
            content=summary,
        )

    async def save_chat_search_embedding(
        self,
        *,
        conversation_id: str,
        message_id: Optional[str],
        source_kind: str,
        content: str,
    ) -> None:
        embedding_service = getattr(self.store, "chat_embedding_service", None)
        if (
            embedding_service is None
            or not getattr(embedding_service, "is_configured", False)
            or not conversation_id
            or not str(content or "").strip()
        ):
            return
        try:
            embedding = await embedding_service.embed_text(content)
            if not embedding:
                return
            record = embedding_service.embedding_record(
                conversation_id=conversation_id,
                message_id=message_id,
                source_kind=source_kind,
                content=content,
                embedding=embedding,
            )
            await self.store._request(
                "POST",
                self.store.settings.supabase_chat_search_embeddings_table,
                body=record,
                query={
                    "select": CHAT_SEARCH_EMBEDDING_SELECT,
                    "on_conflict": "user_id,content_hash,embedding_model",
                },
                prefer="resolution=merge-duplicates,return=representation",
            )
        except Exception:
            LOGGER.warning("rex_memory_fetch_failed source=chat_embedding_save")

    def should_embed_message(self, message: dict) -> bool:
        content = str(message.get("content") or "").strip()
        if not content:
            return False
        if is_chat_search_no_result_message(message):
            return False
        if is_memory_rejection_message(message):
            return False
        return bool(str(message.get("conversation_id") or "") and message.get("id"))
