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
            if "id" in query:
                conversation_id = str(query["id"]).removeprefix("eq.")
                row = self.conversations.get(conversation_id)
                return [row] if row and row.get("user_id") == self.user_id else []
            return [
                row
                for row in self.conversations.values()
                if row.get("user_id") == self.user_id
                and "immigration" in str(row.get("title") or "").lower()
            ]
        if table == "messages":
            return [
                message
                for message in self.messages
                if message.get("user_id") == self.user_id
            ]
        return []


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
