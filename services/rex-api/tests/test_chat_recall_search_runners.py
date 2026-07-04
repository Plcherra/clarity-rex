import pytest

from app.services.chat_recall_search import ChatRecallSearchResult
from app.services.chat_recall_search_runners import (
    CHAT_SEARCH_RESULTS_LIMIT,
    PAST_CHAT_FULL_SCAN_MAX_MESSAGES,
    PAST_CHAT_SEARCH_MAX_PAGES,
    run_conversation_search,
)


class FakeScorer:
    def is_current_query_echo(self, query, message):
        return False

    def scored_conversation_search_result(self, query, item, *, query_mode):
        message = item.get("message") or {}
        return {
            "message": message,
            "score": 1.0,
            "query_mode": query_mode,
        }


class FakeSearch:
    def __init__(self):
        self.scorer = FakeScorer()
        self.add_best_message_calls = 0

    def add_best_message(self, messages_by_id, scored):
        self.add_best_message_calls += 1
        message = scored["message"]
        message_id = str(message.get("id") or "")
        if message_id:
            messages_by_id[message_id] = scored


@pytest.mark.asyncio
async def test_run_conversation_search_records_query_modes_and_caps_results():
    result = ChatRecallSearchResult()
    search = FakeSearch()
    pages_seen = {"count": 0}

    async def search_conversations(query, limit):
        pages_seen["count"] += 1
        return [
            {
                "message": {
                    "id": f"message-{pages_seen['count']}",
                    "content": f"{query} hit",
                    "conversation_id": "conversation-1",
                }
            }
        ]

    await run_conversation_search(
        search,
        result,
        query="payroll date",
        search_queries=[("payroll", "primary"), ("date", "alias")],
        target_match_count=CHAT_SEARCH_RESULTS_LIMIT,
        search_conversations=search_conversations,
    )

    assert pages_seen["count"] == 2
    assert "conversation_search" in result.query_modes
    assert search.add_best_message_calls == 2
    assert len(result.attempted_queries) == 2


def test_recall_search_runner_pagination_constants_are_bounded():
    assert PAST_CHAT_SEARCH_MAX_PAGES >= 1
    assert PAST_CHAT_FULL_SCAN_MAX_MESSAGES >= PAST_CHAT_SEARCH_MAX_PAGES
