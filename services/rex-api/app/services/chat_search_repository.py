import logging
from typing import Optional

from app.services.chat_search_result_mapper import (
    conversation_result_from_ranked_row,
    conversation_result_from_semantic_row,
    message_from_ranked_search_row,
)
from app.services.chat_search_ranking import ChatSearchRanking


CONVERSATION_SELECT = "id,title,timestamp"
MESSAGE_SELECT = "id,conversation_id,role,content,timestamp"
CHAT_SEARCH_RPC = "search_user_chat_messages"
SEMANTIC_CHAT_SEARCH_RPC = "match_user_chat_search_embeddings"
LOGGER = logging.getLogger("rex.context")


class ChatSearchRepository:
    def __init__(self, store: object) -> None:
        self.store = store
        self.search_ranking = ChatSearchRanking()

    async def search_messages(
        self,
        query: str,
        limit: int = 50,
        exclude_conversation_id: Optional[str] = None,
        offset: int = 0,
    ) -> list[dict]:
        rpc_rows = await self._ranked_chat_search_rows(
            query,
            limit=limit,
            exclude_conversation_id=exclude_conversation_id,
            offset=offset,
        )
        if rpc_rows:
            return [
                message
                for row in rpc_rows[offset : offset + limit]
                if (message := message_from_ranked_search_row(row)) is not None
            ]

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

    async def search_conversations(
        self,
        query: str,
        limit: int = 50,
        exclude_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        rpc_rows = await self._ranked_chat_search_rows(
            query,
            limit=limit,
            exclude_conversation_id=exclude_conversation_id,
        )
        if rpc_rows:
            return [
                conversation_result_from_ranked_row(row)
                for row in rpc_rows[:limit]
            ]

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
            if score.score <= 0:
                continue
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
            if score.score <= 0:
                continue
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

    async def search_chat_history(
        self,
        query: str,
        limit: int = 50,
        exclude_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        keyword_results = await self.search_conversations(
            query,
            limit=limit,
            exclude_conversation_id=exclude_conversation_id,
        )
        semantic_results = await self.search_semantic_conversations(
            query,
            limit=limit,
            exclude_conversation_id=exclude_conversation_id,
        )
        return self.merge_search_results(
            keyword_results,
            semantic_results,
            limit=limit,
        )

    async def search_semantic_conversations(
        self,
        query: str,
        *,
        limit: int,
        exclude_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        embedding_service = getattr(self.store, "chat_embedding_service", None)
        if embedding_service is None or not getattr(
            embedding_service,
            "is_configured",
            False,
        ):
            return []
        rpc = getattr(self.store, "_rpc", None)
        if rpc is None:
            return []

        try:
            query_embedding = await embedding_service.embed_query(query)
            if not query_embedding:
                return []
            rows = await rpc(
                SEMANTIC_CHAT_SEARCH_RPC,
                {
                    "query_embedding": query_embedding,
                    "match_embedding_model": embedding_service.model,
                    "match_count": min(max(limit, 1), 200),
                    "exclude_conversation_id": exclude_conversation_id,
                },
            )
        except Exception:
            LOGGER.warning("rex_memory_fetch_failed source=semantic_chat_search")
            return []

        return [
            conversation_result_from_semantic_row(row)
            for row in rows[:limit]
        ]

    def merge_search_results(
        self,
        keyword_results: list[dict],
        semantic_results: list[dict],
        *,
        limit: int,
    ) -> list[dict]:
        merged: dict[tuple[str, str, str], dict] = {}
        for result in [*keyword_results, *semantic_results]:
            conversation_id = str(result.get("conversation_id") or "")
            message = result.get("message")
            message_id = ""
            if isinstance(message, dict):
                message_id = str(message.get("id") or "")
            match_type = str(result.get("match_type") or "")
            key = (conversation_id, message_id, match_type)
            existing = merged.get(key)
            if existing is None or float(result.get("relevance_score") or 0) > float(
                existing.get("relevance_score") or 0,
            ):
                merged[key] = result
        ranked = sorted(
            merged.values(),
            key=lambda result: (
                float(result.get("relevance_score") or 0),
                str(result.get("conversation_timestamp") or ""),
            ),
            reverse=True,
        )
        return ranked[:limit]

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

    def _search_terms(self, query: str) -> list[str]:
        return self.search_ranking.search_terms(query, max_terms=16)

    def _normalize_search_term(self, term: str) -> str:
        return self.search_ranking.normalize_term(term)

    def _simple_term_variants(self, term: str) -> tuple[str, ...]:
        return self.search_ranking.simple_term_variants(term)

    async def _ranked_chat_search_rows(
        self,
        query: str,
        *,
        limit: int,
        exclude_conversation_id: Optional[str] = None,
        offset: int = 0,
    ) -> Optional[list[dict]]:
        rpc = getattr(self.store, "_rpc", None)
        if rpc is None:
            return None

        search_terms = self.search_ranking.search_terms(
            query,
            max_terms=20,
        )
        if not search_terms:
            search_terms = list(self.search_ranking.content_terms(query))
        if not search_terms:
            return None

        payload: dict = {
            "search_query": query,
            "search_terms": search_terms,
            "match_count": min(max(limit + offset, limit), 200),
            "exclude_conversation_id": exclude_conversation_id,
        }
        user_id = getattr(self.store, "user_id", None)
        if user_id:
            payload["match_user_id"] = user_id

        try:
            rows = await rpc(CHAT_SEARCH_RPC, payload)
        except Exception:
            LOGGER.warning("rex_memory_fetch_failed source=indexed_chat_search")
            return None

        return rows or None

    def _rank_messages(self, query: str, rows: list[dict]) -> list[dict]:
        ranked = []
        for row in rows:
            score = self.search_ranking.score_text(
                query,
                str(row.get("content") or ""),
                role=str(row.get("role") or ""),
                timestamp=str(row.get("timestamp") or ""),
            )
            if score.score <= 0:
                continue
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
