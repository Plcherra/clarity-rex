import re

import pytest

from app.services.conversation_repository import ConversationRepository


class _Settings:
    supabase_conversations_table = "conversations"
    supabase_messages_table = "messages"


class _SearchStore:
    settings = _Settings()

    def __init__(self, *, user_id: str = "user-123"):
        self.user_id = user_id
        self.messages = [
            {
                "id": "message-assistant-noise",
                "user_id": "user-123",
                "conversation_id": "conversation-noise",
                "role": "assistant",
                "content": "I checked chats, but nothing about immigration came up.",
                "timestamp": "2026-06-11T10:00:00Z",
            },
            {
                "id": "message-ead",
                "user_id": "user-123",
                "conversation_id": "conversation-immigration",
                "role": "user",
                "content": "My EAD renewal and USCIS paperwork are due soon.",
                "timestamp": "2026-06-10T10:00:00Z",
            },
            {
                "id": "message-immigration",
                "user_id": "user-123",
                "conversation_id": "conversation-immigration",
                "role": "user",
                "content": "I need to check my immigration status before the trip.",
                "timestamp": "2026-06-10T10:01:00Z",
            },
            {
                "id": "message-mom-birthday",
                "user_id": "user-123",
                "conversation_id": "conversation-family",
                "role": "user",
                "content": "My mom's birthday is June 18th.",
                "timestamp": "2026-06-09T10:01:00Z",
            },
            {
                "id": "message-pc-game",
                "user_id": "user-123",
                "conversation_id": "conversation-pc",
                "role": "user",
                "content": "Awesome. I'm going to buy my first PC game.",
                "timestamp": "2026-06-08T10:01:00Z",
            },
            {
                "id": "message-legacy",
                "user_id": "user-123",
                "conversation_id": "conversation-pc",
                "role": "user",
                "content": "It's Legacy of Kain.",
                "timestamp": "2026-06-08T10:02:00Z",
            },
            {
                "id": "message-year-noise",
                "user_id": "user-123",
                "conversation_id": "conversation-year",
                "role": "user",
                "content": "The archive from 2018 is not the birthday date.",
                "timestamp": "2026-06-07T10:01:00Z",
            },
            {
                "id": "message-other-user",
                "user_id": "user-999",
                "conversation_id": "conversation-other-user",
                "role": "user",
                "content": "My immigration case has a green card interview tomorrow.",
                "timestamp": "2026-06-12T10:01:00Z",
            },
        ]
        self.conversations = {
            "conversation-immigration": {
                "id": "conversation-immigration",
                "user_id": "user-123",
                "title": "Immigration planning",
                "timestamp": "2026-06-10T10:00:00Z",
            },
            "conversation-family": {
                "id": "conversation-family",
                "user_id": "user-123",
                "title": "Family dates",
                "timestamp": "2026-06-09T10:00:00Z",
            },
            "conversation-pc": {
                "id": "conversation-pc",
                "user_id": "user-123",
                "title": "PC games",
                "timestamp": "2026-06-08T10:00:00Z",
            },
            "conversation-year": {
                "id": "conversation-year",
                "user_id": "user-123",
                "title": "Old archive",
                "timestamp": "2026-06-07T10:00:00Z",
            },
            "conversation-noise": {
                "id": "conversation-noise",
                "user_id": "user-123",
                "title": "Failed search",
                "timestamp": "2026-06-11T10:00:00Z",
            },
            "conversation-other-user": {
                "id": "conversation-other-user",
                "user_id": "user-999",
                "title": "Other user immigration",
                "timestamp": "2026-06-12T10:00:00Z",
            },
        }

    async def _request(self, method, table, *, query=None, **kwargs):
        query = query or {}
        if table == "conversations":
            rows = [
                row
                for row in self.conversations.values()
                if row.get("user_id") == self.user_id
            ]
            if "id" in query:
                conversation_id = str(query["id"]).removeprefix("eq.")
                return [row for row in rows if row.get("id") == conversation_id]
            terms = self._terms_from_or(query.get("or"), "title")
            if terms:
                rows = [
                    row
                    for row in rows
                    if self._matches_terms(row.get("title"), terms)
                ]
            return self._slice(rows, query)
        if table == "messages":
            rows = [
                message
                for message in self.messages
                if message.get("user_id") == self.user_id
            ]
            conversation_filter = str(query.get("conversation_id") or "")
            if conversation_filter.startswith("neq."):
                excluded = conversation_filter.removeprefix("neq.")
                rows = [
                    row for row in rows if row.get("conversation_id") != excluded
                ]
            elif conversation_filter.startswith("eq."):
                included = conversation_filter.removeprefix("eq.")
                rows = [
                    row for row in rows if row.get("conversation_id") == included
                ]
            terms = self._terms_from_or(query.get("or"), "content")
            if terms:
                rows = [
                    row
                    for row in rows
                    if self._matches_terms(row.get("content"), terms)
                ]
            return self._slice(rows, query)
        return []

    def _terms_from_or(self, clause, field: str) -> list[str]:
        if not clause:
            return []
        return [
            match.lower()
            for match in re.findall(rf"{field}\.ilike\.\*([^*,)]+)\*", str(clause))
        ]

    def _matches_terms(self, value, terms: list[str]) -> bool:
        haystack = str(value or "").lower()
        return any(term in haystack for term in terms)

    def _slice(self, rows: list[dict], query: dict) -> list[dict]:
        ordered = sorted(
            rows,
            key=lambda row: str(row.get("timestamp") or ""),
            reverse=True,
        )
        offset = int(query.get("offset") or 0)
        limit = int(query.get("limit") or len(ordered))
        return ordered[offset : offset + limit]


@pytest.mark.asyncio
async def test_conversation_repository_ranks_user_matches_and_exposes_metadata():
    repository = ConversationRepository(_SearchStore())

    results = await repository.search_conversations("What did I say about immigration?")

    assert results[0]["conversation_id"] == "conversation-immigration"
    assert results[0]["match_type"] == "title"
    assert results[0]["relevance_score"] > 0
    assert "immigration" in results[0]["matched_terms"]
    assert any(
        result["message"] and result["message"]["id"] == "message-ead"
        for result in results
    )
    assert all("search_reason" in result for result in results)


@pytest.mark.asyncio
async def test_conversation_repository_ranked_search_does_not_leak_other_users():
    repository = ConversationRepository(_SearchStore(user_id="user-123"))

    results = await repository.search_conversations("immigration green card")

    assert results
    assert all(result["conversation_id"] != "conversation-other-user" for result in results)
    assert all(
        not result.get("message")
        or result["message"]["id"] != "message-other-user"
        for result in results
    )


@pytest.mark.asyncio
async def test_conversation_repository_prefers_repeated_user_conversation_over_noise():
    repository = ConversationRepository(_SearchStore(user_id="user-123"))

    results = await repository.search_conversations("What did I say about immigration?")
    message_results = [result for result in results if result["match_type"] == "message"]

    assert message_results[0]["conversation_id"] == "conversation-immigration"
    assert message_results[0]["relevance_score"] > message_results[-1]["relevance_score"]


@pytest.mark.asyncio
async def test_conversation_repository_list_messages_stays_user_scoped():
    repository = ConversationRepository(_SearchStore(user_id="user-123"))

    results = await repository.list_messages(limit=200)

    assert results
    assert all(message["user_id"] == "user-123" for message in results)
    assert all(message["conversation_id"] != "conversation-other-user" for message in results)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("query", "conversation_id", "expected_preview"),
    [
        ("mom", "conversation-family", "mom's birthday"),
        ("June", "conversation-family", "June 18th"),
        ("18", "conversation-family", "June 18th"),
        ("June 18", "conversation-family", "June 18th"),
        ("PC game", "conversation-pc", "first PC game"),
        ("Legacy of Kain", "conversation-pc", "Legacy of Kain"),
    ],
)
async def test_conversation_repository_searches_manual_keyword_cases(
    query,
    conversation_id,
    expected_preview,
):
    repository = ConversationRepository(_SearchStore(user_id="user-123"))

    results = await repository.search_conversations(query)

    assert any(
        result["conversation_id"] == conversation_id
        and expected_preview in result["preview"]
        for result in results
    )


@pytest.mark.asyncio
async def test_conversation_repository_numeric_search_rejects_year_substrings():
    repository = ConversationRepository(_SearchStore(user_id="user-123"))

    results = await repository.search_conversations("18")

    assert any(result["conversation_id"] == "conversation-family" for result in results)
    assert all(result["conversation_id"] != "conversation-year" for result in results)
