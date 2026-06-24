from typing import Optional

from app.services.chat_search_ranking import ChatSearchRanking


class ChatRecallScorer:
    def __init__(
        self, *, chat_search_ranking: Optional[ChatSearchRanking] = None
    ) -> None:
        self.chat_search_ranking = chat_search_ranking or ChatSearchRanking()

    def past_chat_search_queries(self, query: str) -> list[tuple[str, str]]:
        return [
            (item.query, item.mode)
            for item in self.chat_search_ranking.build_queries(
                query,
                max_terms=10,
            )
        ]

    def is_current_query_echo(self, query: str, message: dict) -> bool:
        if str(message.get("role") or "") != "user":
            return False
        content = str(message.get("content") or "")
        return self.normalized_echo_text(content) == self.normalized_echo_text(query)

    def normalized_echo_text(self, text: str) -> str:
        return " ".join(str(text or "").lower().strip().strip(".!?").split())

    def scored_chat_message(self, query: str, message: dict, *, query_mode: str) -> dict:
        score = self.chat_search_ranking.score_text(
            query,
            str(message.get("content") or ""),
            role=str(message.get("role") or ""),
            timestamp=str(message.get("timestamp") or ""),
        )
        return {
            **message,
            "_chat_search_score": score.score,
            "_chat_search_reason": score.reason,
            "_chat_search_query_mode": query_mode,
            "_chat_search_matched_terms": list(score.matched_terms),
        }

    def scored_conversation_search_result(
        self,
        query: str,
        result: dict,
        *,
        query_mode: str,
    ) -> dict:
        conversation_id = str(result.get("conversation_id") or "")
        match_type = str(result.get("match_type") or "conversation")
        message = result.get("message")
        if not isinstance(message, dict):
            message = {
                "id": f"conversation-{conversation_id}-{match_type}",
                "conversation_id": conversation_id,
                "role": "conversation",
                "content": str(
                    result.get("preview")
                    or result.get("conversation_title")
                    or "Matched conversation."
                ),
                "timestamp": result.get("conversation_timestamp"),
            }

        scored_message = self.scored_chat_message(
            query,
            message,
            query_mode=query_mode,
        )
        repository_score = float(result.get("relevance_score") or 0)
        local_score = float(scored_message.get("_chat_search_score") or 0)
        matched_terms = {
            str(term)
            for term in [
                *list(scored_message.get("_chat_search_matched_terms") or []),
                *list(result.get("matched_terms") or []),
            ]
            if str(term)
        }
        return {
            **scored_message,
            "_chat_search_score": max(repository_score, local_score),
            "_chat_search_reason": (
                result.get("search_reason")
                or scored_message.get("_chat_search_reason")
                or "conversation search match"
            ),
            "_chat_search_matched_terms": sorted(matched_terms),
            "_conversation_search_match_type": match_type,
            "_conversation_search_title": result.get("conversation_title"),
            "_conversation_search_preview": result.get("preview"),
        }

    def best_scored_chat_message(
        self, query: str, message: dict, *, search_queries: list[tuple[str, str]]
    ) -> dict:
        best_message = self.scored_chat_message(
            query,
            message,
            query_mode="full_scan",
        )
        for search_query, query_mode in search_queries:
            scored = self.scored_chat_message(
                search_query,
                message,
                query_mode=f"full_scan:{query_mode}",
            )
            if scored.get("_chat_search_score", 0) > best_message.get(
                "_chat_search_score",
                0,
            ):
                best_message = scored
        return best_message

    def recency_ranked_score(self, score: object) -> int:
        return round(float(score or 0) * 2)
