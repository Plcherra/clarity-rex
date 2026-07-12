import re

import pytest

from app.services.conversation_repository import ConversationRepository


class _Settings:
    supabase_conversations_table = "conversations"
    supabase_messages_table = "messages"
    supabase_chat_search_embeddings_table = "chat_search_embeddings"


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
                "id": "message-mom",
                "user_id": "user-123",
                "conversation_id": "conversation-family",
                "role": "user",
                "content": "My mom's birthday is June 18.",
                "timestamp": "2026-06-06T10:01:00Z",
            },
            {
                "id": "message-payroll",
                "user_id": "user-123",
                "conversation_id": "conversation-payroll",
                "role": "user",
                "content": "Bom Dough payroll should land on Friday.",
                "timestamp": "2026-06-05T10:01:00Z",
            },
            {
                "id": "message-immigration",
                "user_id": "user-123",
                "conversation_id": "conversation-immigration",
                "role": "user",
                "content": "I need to check my immigration status before the trip.",
                "timestamp": "2026-06-04T10:01:00Z",
            },
            {
                "id": "message-pc",
                "user_id": "user-123",
                "conversation_id": "conversation-pc",
                "role": "user",
                "content": "I own an Omen PC forty five.",
                "timestamp": "2026-06-03T10:01:00Z",
            },
            {
                "id": "message-pc-game",
                "user_id": "user-123",
                "conversation_id": "conversation-games",
                "role": "user",
                "content": "Awesome. I'm going to buy my first PC game.",
                "timestamp": "2026-06-03T10:02:00Z",
            },
            {
                "id": "message-legacy",
                "user_id": "user-123",
                "conversation_id": "conversation-games",
                "role": "user",
                "content": "It's Legacy of Kain on GOG.",
                "timestamp": "2026-06-03T10:03:00Z",
            },
            {
                "id": "message-random-name",
                "user_id": "user-123",
                "conversation_id": "conversation-random-name",
                "role": "user",
                "content": "Marisol recommended the quiet study room.",
                "timestamp": "2026-06-02T10:01:00Z",
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
            "conversation-family": {
                "id": "conversation-family",
                "user_id": "user-123",
                "title": "Family dates",
                "timestamp": "2026-06-06T10:00:00Z",
            },
            "conversation-payroll": {
                "id": "conversation-payroll",
                "user_id": "user-123",
                "title": "Payroll",
                "timestamp": "2026-06-05T10:00:00Z",
            },
            "conversation-immigration": {
                "id": "conversation-immigration",
                "user_id": "user-123",
                "title": "Immigration planning",
                "timestamp": "2026-06-04T10:00:00Z",
            },
            "conversation-pc": {
                "id": "conversation-pc",
                "user_id": "user-123",
                "title": "PC details",
                "timestamp": "2026-06-03T10:00:00Z",
            },
            "conversation-games": {
                "id": "conversation-games",
                "user_id": "user-123",
                "title": "PC gaming",
                "timestamp": "2026-06-03T10:00:00Z",
            },
            "conversation-random-name": {
                "id": "conversation-random-name",
                "user_id": "user-123",
                "title": "Random name",
                "timestamp": "2026-06-02T10:00:00Z",
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

    def _first_row(self, rows: list[dict]) -> dict:
        return rows[0]


class _RpcSearchStore(_SearchStore):
    def __init__(self, *, user_id: str = "user-123"):
        super().__init__(user_id=user_id)
        self.rpc_calls = []

    async def _rpc(self, function_name, body=None):
        self.rpc_calls.append({"function_name": function_name, "body": body or {}})
        return [
            {
                "message_id": "message-omen",
                "conversation_id": "conversation-omen",
                "role": "user",
                "content": "I own an Omen PC forty five.",
                "message_timestamp": "2026-06-23T21:13:00Z",
                "conversation_title": "PC details",
                "conversation_timestamp": "2026-06-23T21:13:00Z",
                "match_type": "message",
                "rank": 12.5,
                "search_reason": "Matched message content with indexed chat search.",
                "matched_terms": ["pc", "45"],
            }
        ]


class _EmptyRpcSearchStore(_SearchStore):
    def __init__(self, *, user_id: str = "user-123"):
        super().__init__(user_id=user_id)
        self.rpc_calls = []

    async def _rpc(self, function_name, body=None):
        self.rpc_calls.append({"function_name": function_name, "body": body or {}})
        return []


class _FakeEmbeddingService:
    is_configured = True
    model = "test-embedding-model"

    def __init__(self):
        self.embedded_queries = []
        self.embedded_texts = []

    async def embed_query(self, text):
        self.embedded_queries.append(text)
        return [0.1, 0.2, 0.3]

    async def embed_text(self, text):
        self.embedded_texts.append(text)
        return [0.1, 0.2, 0.3]

    def content_hash(self, content):
        return f"hash-{len(content)}"

    def embedding_record(
        self,
        *,
        conversation_id,
        content,
        embedding,
        source_kind="message",
        message_id=None,
    ):
        return {
            "conversation_id": conversation_id,
            "message_id": message_id,
            "source_kind": source_kind,
            "content": content,
            "content_hash": self.content_hash(content),
            "embedding_model": self.model,
            "embedding": embedding,
        }


class _HybridSearchStore(_SearchStore):
    def __init__(self, *, user_id: str = "user-123"):
        super().__init__(user_id=user_id)
        self.rpc_calls = []
        self.chat_embedding_service = _FakeEmbeddingService()

    async def _rpc(self, function_name, body=None):
        self.rpc_calls.append({"function_name": function_name, "body": body or {}})
        if function_name == "search_user_chat_messages":
            return [
                {
                    "message_id": "message-assistant-noise",
                    "conversation_id": "conversation-noise",
                    "role": "assistant",
                    "content": "I checked chats, but nothing about your PC came up.",
                    "message_timestamp": "2026-06-11T10:00:00Z",
                    "conversation_title": "Failed search",
                    "conversation_timestamp": "2026-06-11T10:00:00Z",
                    "match_type": "message",
                    "rank": 2.0,
                    "search_reason": "Matched message content with indexed chat search.",
                    "matched_terms": ["pc"],
                }
            ]
        if function_name == "match_user_chat_search_embeddings":
            return [
                {
                    "message_id": "message-omen",
                    "conversation_id": "conversation-omen",
                    "role": "user",
                    "content": "The model is an Omen 45L.",
                    "message_timestamp": "2026-06-23T21:13:00Z",
                    "conversation_title": "PC details",
                    "conversation_timestamp": "2026-06-23T21:13:00Z",
                    "match_type": "semantic_message",
                    "rank": 9.1,
                    "search_reason": "Matched message content with semantic chat search.",
                    "matched_terms": [],
                }
            ]
        return []


class _EmbeddingSaveStore(_SearchStore):
    def __init__(self, *, user_id: str = "user-123"):
        super().__init__(user_id=user_id)
        self.chat_embedding_service = _FakeEmbeddingService()
        self.created_embeddings = []
        self.conversations["conversation-omen"] = {
            "id": "conversation-omen",
            "user_id": user_id,
            "title": "",
            "timestamp": "2026-06-23T21:13:00Z",
        }

    async def _request(self, method, table, *, query=None, body=None, prefer=None, **kwargs):
        if method == "POST" and table == "messages":
            return [
                {
                    "id": "message-new",
                    "conversation_id": body["conversation_id"],
                    "role": body["role"],
                    "content": body["content"],
                    "timestamp": "2026-06-23T21:13:00Z",
                }
            ]
        if method == "POST" and table == "chat_search_embeddings":
            self.created_embeddings.append(
                {
                    "body": body,
                    "query": query,
                    "prefer": prefer,
                }
            )
            return [{"id": "embedding-1"}]
        return await super()._request(
            method,
            table,
            query=query,
            body=body,
            prefer=prefer,
            **kwargs,
        )


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
async def test_conversation_repository_uses_ranked_chat_search_rpc_when_available():
    store = _RpcSearchStore(user_id="user-123")
    repository = ConversationRepository(store)

    results = await repository.search_conversations("What kind PC do I have?")

    assert store.rpc_calls[0]["function_name"] == "search_user_chat_messages"
    assert store.rpc_calls[0]["body"]["search_query"] == "What kind PC do I have?"
    assert "pc" in store.rpc_calls[0]["body"]["search_terms"]
    assert store.rpc_calls[0]["body"]["match_user_id"] == "user-123"
    assert results[0]["conversation_id"] == "conversation-omen"
    assert results[0]["message"]["id"] == "message-omen"
    assert results[0]["matched_terms"] == ["pc", "45"]


@pytest.mark.asyncio
async def test_conversation_repository_keeps_shared_search_keyword_only_for_parity():
    store = _HybridSearchStore(user_id="user-123")
    repository = ConversationRepository(store)

    await repository.search_conversations("What kind PC do I have?", limit=10)

    assert [call["function_name"] for call in store.rpc_calls] == [
        "search_user_chat_messages",
    ]
    assert store.chat_embedding_service.embedded_queries == []


@pytest.mark.asyncio
async def test_conversation_repository_passes_exclusion_to_ranked_chat_search_rpc():
    store = _RpcSearchStore(user_id="user-123")
    repository = ConversationRepository(store)

    await repository.search_messages(
        "PC model",
        limit=12,
        exclude_conversation_id="conversation-current",
    )

    assert store.rpc_calls[0]["body"]["match_count"] == 12
    assert store.rpc_calls[0]["body"]["exclude_conversation_id"] == (
        "conversation-current"
    )
    assert store.rpc_calls[0]["body"]["match_user_id"] == "user-123"


@pytest.mark.asyncio
async def test_conversation_repository_falls_back_when_ranked_rpc_returns_empty():
    store = _EmptyRpcSearchStore(user_id="user-123")
    repository = ConversationRepository(store)

    results = await repository.search_conversations("games")

    assert store.rpc_calls
    assert any(
        result["conversation_id"] == "conversation-games"
        and "first PC game" in result["preview"]
        for result in results
    )
    store = _HybridSearchStore(user_id="user-123")
    repository = ConversationRepository(store)

    results = await repository.search_chat_history("What kind PC do I have?", limit=10)

    assert store.rpc_calls[0]["function_name"] == "search_user_chat_messages"
    assert store.rpc_calls[1]["function_name"] == "match_user_chat_search_embeddings"
    assert store.rpc_calls[1]["body"]["match_embedding_model"] == "test-embedding-model"
    assert results[0]["conversation_id"] == "conversation-omen"
    assert any(
        result["conversation_id"] == "conversation-omen"
        and result["match_type"] == "semantic_message"
        and "semantic chat search" in result["search_reason"]
        for result in results
    )


@pytest.mark.asyncio
async def test_conversation_repository_saves_message_embedding_when_configured():
    store = _EmbeddingSaveStore(user_id="user-123")
    repository = ConversationRepository(store)

    message = await repository.save_message(
        "conversation-omen",
        "user",
        "The model is an Omen 45L.",
    )

    assert message["id"] == "message-new"
    assert store.chat_embedding_service.embedded_texts == ["The model is an Omen 45L."]
    created = store.created_embeddings[0]
    assert created["body"]["conversation_id"] == "conversation-omen"
    assert created["body"]["message_id"] == "message-new"
    assert created["body"]["source_kind"] == "message"
    assert created["body"]["embedding_model"] == "test-embedding-model"
    assert created["query"]["on_conflict"] == "user_id,content_hash,embedding_model"
    assert "resolution=merge-duplicates" in created["prefer"]


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
        ("mom", "conversation-family", "mom's birthday"),
        ("Bom Dough payroll", "conversation-payroll", "payroll should land"),
        ("immigration", "conversation-immigration", "immigration status"),
        ("PC", "conversation-pc", "Omen PC"),
        ("games", "conversation-games", "first PC game"),
        ("gog", "conversation-games", "Legacy of Kain"),
        ("Marisol", "conversation-random-name", "Marisol recommended"),
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
