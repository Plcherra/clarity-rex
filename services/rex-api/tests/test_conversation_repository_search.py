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
                "content": "I checked chats, but nothing about Lara came up.",
                "timestamp": "2026-06-11T10:00:00Z",
            },
            {
                "id": "message-lara",
                "user_id": "user-123",
                "conversation_id": "conversation-lara",
                "role": "user",
                "content": "Lara recommended the Somerville coffee place.",
                "timestamp": "2026-06-10T10:00:00Z",
            },
            {
                "id": "message-somerville",
                "user_id": "user-123",
                "conversation_id": "conversation-lara",
                "role": "user",
                "content": "I moved the meetup to Somerville for Thursday.",
                "timestamp": "2026-06-10T10:01:00Z",
            },
            {
                "id": "message-deadline",
                "user_id": "user-123",
                "conversation_id": "conversation-deadline",
                "role": "user",
                "content": "The paperwork deadline is on the 24th.",
                "timestamp": "2026-06-09T10:01:00Z",
            },
            {
                "id": "message-notebook",
                "user_id": "user-123",
                "conversation_id": "conversation-notes",
                "role": "user",
                "content": "I prefer blue notebooks for planning.",
                "timestamp": "2026-06-08T10:01:00Z",
            },
            {
                "id": "message-qr",
                "user_id": "user-123",
                "conversation_id": "conversation-notes",
                "role": "user",
                "content": "The QR code is printed on the notebook cover.",
                "timestamp": "2026-06-08T10:02:00Z",
            },
            {
                "id": "message-year-noise",
                "user_id": "user-123",
                "conversation_id": "conversation-year",
                "role": "user",
                "content": "The archive from 2024 is not the deadline date.",
                "timestamp": "2026-06-07T10:01:00Z",
            },
            {
                "id": "message-other-user",
                "user_id": "user-999",
                "conversation_id": "conversation-other-user",
                "role": "user",
                "content": "Lara sent a private note for another user.",
                "timestamp": "2026-06-12T10:01:00Z",
            },
        ]
        self.conversations = {
            "conversation-lara": {
                "id": "conversation-lara",
                "user_id": "user-123",
                "title": "Lara planning",
                "timestamp": "2026-06-10T10:00:00Z",
            },
            "conversation-deadline": {
                "id": "conversation-deadline",
                "user_id": "user-123",
                "title": "Paperwork deadline",
                "timestamp": "2026-06-09T10:00:00Z",
            },
            "conversation-notes": {
                "id": "conversation-notes",
                "user_id": "user-123",
                "title": "Notebook planning",
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
                "title": "Other user Lara",
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

    results = await repository.search_conversations("What did I say about Lara?")

    assert results[0]["conversation_id"] == "conversation-lara"
    assert results[0]["match_type"] == "title"
    assert results[0]["relevance_score"] > 0
    assert "lara" in results[0]["matched_terms"]
    assert any(
        result["message"] and result["message"]["id"] == "message-lara"
        for result in results
    )
    assert all("search_reason" in result for result in results)


@pytest.mark.asyncio
async def test_conversation_repository_ranked_search_does_not_leak_other_users():
    repository = ConversationRepository(_SearchStore(user_id="user-123"))

    results = await repository.search_conversations("Lara private note")

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

    results = await repository.search_conversations("What did I say about Lara?")
    message_results = [result for result in results if result["match_type"] == "message"]

    assert message_results[0]["conversation_id"] == "conversation-lara"
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
        ("Lara", "conversation-lara", "Lara recommended"),
        ("Somerville", "conversation-lara", "Somerville"),
        ("24", "conversation-deadline", "24th"),
        ("twenty-fourth", "conversation-deadline", "24th"),
        ("notebooks", "conversation-notes", "blue notebooks"),
        ("QR code", "conversation-notes", "QR code"),
        ("Lara Somerville", "conversation-lara", "Somerville"),
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

    results = await repository.search_conversations("24")

    assert any(result["conversation_id"] == "conversation-deadline" for result in results)
    assert all(result["conversation_id"] != "conversation-year" for result in results)
