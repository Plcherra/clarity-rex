import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_memory_service
from app.main import app
from app.services.memory_service import MemoryServiceError


@pytest.fixture
def client():
    app.dependency_overrides.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


class FakeConversationMemoryService:
    def __init__(self, error=None):
        self.error = error
        self.deleted_conversation_ids = []
        self.search_conversation_calls = []
        self.search_message_calls = []
        self.pending_actions = {}
        self.conversations = [
            {
                "id": "conversation-1",
                "title": "Work stress",
                "timestamp": "2026-05-11T10:00:00Z",
                "last_message": {
                    "id": "message-2",
                    "conversation_id": "conversation-1",
                    "role": "assistant",
                    "content": "Let's be practical.",
                    "timestamp": "2026-05-11T10:02:00Z",
                },
            },
            {
                "id": "conversation-2",
                "title": None,
                "timestamp": "2026-05-11T11:00:00Z",
                "last_message": None,
            },
        ]
        self.messages = {
            "conversation-1": [
                {
                    "id": "message-1",
                    "conversation_id": "conversation-1",
                    "role": "user",
                    "content": "I am stressed about work.",
                    "timestamp": "2026-05-11T10:01:00Z",
                },
                {
                    "id": "message-2",
                    "conversation_id": "conversation-1",
                    "role": "assistant",
                    "content": "Let's be practical.",
                    "timestamp": "2026-05-11T10:02:00Z",
                },
            ]
        }

    def _raise_if_configured(self):
        if self.error is not None:
            raise self.error

    async def list_conversations(self):
        self._raise_if_configured()
        return self.conversations

    async def create_conversation_record(self):
        self._raise_if_configured()
        return {
            "id": "conversation-new",
            "title": None,
            "timestamp": "2026-05-11T12:00:00Z",
            "last_message": None,
        }

    async def get_conversation_messages(self, conversation_id):
        self._raise_if_configured()
        return self.messages.get(conversation_id)

    async def search_messages(self, query, limit=50):
        self._raise_if_configured()
        self.search_message_calls.append({"query": query, "limit": limit})
        normalized_query = query.lower()
        matches = []
        for messages in self.messages.values():
            for message in messages:
                if normalized_query in message["content"].lower():
                    matches.append(message)
                if len(matches) >= limit:
                    return matches
        return matches

    async def search_conversations(self, query, limit=50):
        self._raise_if_configured()
        self.search_conversation_calls.append({"query": query, "limit": limit})
        normalized_query = query.lower()
        results = []
        for conversation in self.conversations:
            title = conversation.get("title") or ""
            if normalized_query in title.lower():
                results.append(
                    {
                        "conversation_id": conversation["id"],
                        "conversation_title": conversation.get("title"),
                        "conversation_timestamp": conversation.get("timestamp"),
                        "message": None,
                        "match_type": "title",
                        "preview": title,
                        "relevance_score": 4.6,
                        "search_reason": "exact terms, conversation title",
                        "matched_terms": ["work"],
                    }
                )
                if len(results) >= limit:
                    return results
        for message in await self.search_messages(query, limit=limit):
            conversation = next(
                item
                for item in self.conversations
                if item["id"] == message["conversation_id"]
            )
            results.append(
                {
                    "conversation_id": message["conversation_id"],
                    "conversation_title": conversation.get("title"),
                    "conversation_timestamp": conversation.get("timestamp"),
                    "message": message,
                    "match_type": "message",
                    "preview": message["content"],
                    "relevance_score": 3.6,
                    "search_reason": "exact terms, user-authored",
                    "matched_terms": ["work"],
                }
            )
            if len(results) >= limit:
                break
        return results

    async def delete_conversation(self, conversation_id):
        self._raise_if_configured()
        if conversation_id not in {"conversation-1", "conversation-2"}:
            return False

        self.deleted_conversation_ids.append(conversation_id)
        return True

    async def update_conversation_title(self, conversation_id, title):
        self._raise_if_configured()
        cleaned = " ".join((title or "").split()).strip()
        if not cleaned:
            raise MemoryServiceError(
                "Conversation title cannot be empty.",
                status_code=400,
            )
        for conversation in self.conversations:
            if conversation["id"] == conversation_id:
                conversation["title"] = cleaned
                return dict(conversation)
        return None

    async def get_conversation_pending_action(self, conversation_id):
        self._raise_if_configured()
        return self.pending_actions.get(conversation_id)


def override_memory_service(fake_memory_service):
    app.dependency_overrides[get_memory_service] = lambda: fake_memory_service


def test_list_conversations_returns_last_message_preview(client):
    fake_memory_service = FakeConversationMemoryService()
    override_memory_service(fake_memory_service)

    response = client.get("/conversations")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["id"] == "conversation-1"
    assert data[0]["last_message"]["content"] == "Let's be practical."
    assert data[1]["last_message"] is None


def test_list_conversations_maps_service_errors(client):
    override_memory_service(
        FakeConversationMemoryService(
            error=MemoryServiceError("Supabase unavailable.", status_code=503)
        )
    )

    response = client.get("/conversations")

    assert response.status_code == 503
    assert response.json()["detail"] == "Supabase unavailable."


def test_create_conversation(client):
    override_memory_service(FakeConversationMemoryService())

    response = client.post("/conversations")

    assert response.status_code == 201
    assert response.json()["id"] == "conversation-new"
    assert response.json()["last_message"] is None


def test_get_conversation_messages(client):
    override_memory_service(FakeConversationMemoryService())

    response = client.get("/conversations/conversation-1/messages")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["role"] == "user"
    assert data[1]["role"] == "assistant"


def test_get_conversation_messages_returns_404_for_missing_conversation(client):
    override_memory_service(FakeConversationMemoryService())

    response = client.get("/conversations/missing/messages")

    assert response.status_code == 404
    assert response.json()["detail"] == "Conversation not found."


def test_search_conversation_messages(client):
    fake_memory_service = FakeConversationMemoryService()
    override_memory_service(fake_memory_service)

    response = client.get("/conversations/search?q=work")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["conversation_id"] == "conversation-1"
    assert data[0]["match_type"] == "title"
    assert data[0]["preview"] == "Work stress"
    assert data[0]["relevance_score"] == 4.6
    assert data[0]["matched_terms"] == ["work"]
    assert data[1]["message"]["id"] == "message-1"
    assert data[1]["preview"] == "I am stressed about work."
    assert fake_memory_service.search_conversation_calls == [
        {"query": "work", "limit": 50}
    ]


def test_search_route_uses_shared_conversation_search_contract(client):
    fake_memory_service = FakeConversationMemoryService()
    override_memory_service(fake_memory_service)

    response = client.get("/conversations/search?q=work&limit=12")

    assert response.status_code == 200
    assert fake_memory_service.search_conversation_calls == [
        {"query": "work", "limit": 12}
    ]


def test_delete_conversation(client):
    fake_memory_service = FakeConversationMemoryService()
    override_memory_service(fake_memory_service)

    response = client.delete("/conversations/conversation-1")

    assert response.status_code == 204
    assert fake_memory_service.deleted_conversation_ids == ["conversation-1"]


def test_update_conversation_title(client):
    fake_memory_service = FakeConversationMemoryService()
    override_memory_service(fake_memory_service)

    response = client.patch(
        "/conversations/conversation-2",
        json={"title": "  Budget check-in  "},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "conversation-2"
    assert data["title"] == "Budget check-in"
    assert fake_memory_service.conversations[1]["title"] == "Budget check-in"


def test_update_conversation_title_returns_404_for_missing_conversation(client):
    override_memory_service(FakeConversationMemoryService())

    response = client.patch(
        "/conversations/missing",
        json={"title": "Missing chat"},
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "Conversation not found."


def test_get_pending_write_returns_empty_when_no_pending_action(client):
    override_memory_service(FakeConversationMemoryService())

    response = client.get("/conversations/conversation-1/pending-write")

    assert response.status_code == 200
    assert response.json()["write_proposals"] == []


def test_get_pending_write_returns_open_thread_proposal(client):
    fake_memory_service = FakeConversationMemoryService()
    fake_memory_service.pending_actions["conversation-1"] = {
        "action_type": "durable_write",
        "context": {
            "surface_client_cards": True,
            "durable_write_proposal": {
                "write_kind": "open_thread",
                "title": "Money stress",
                "body": "Money has been tight lately.",
                "editable_fields": ["title", "body"],
                "apply_snapshot": {
                    "type": "open_thread",
                    "payload": {
                        "title": "Money stress",
                        "summary": "Money has been tight lately.",
                        "status": "active",
                    },
                },
                "proposal_id": "proposal-1",
                "risk_level": "medium",
            }
        },
    }
    override_memory_service(fake_memory_service)

    response = client.get("/conversations/conversation-1/pending-write")

    assert response.status_code == 200
    payload = response.json()
    assert payload["confirmation_required"] == 1
    assert payload["write_proposals"][0]["write_kind"] == "open_thread"


def test_get_pending_write_uses_propose_time_text_surface(client):
    fake_memory_service = FakeConversationMemoryService()
    fake_memory_service.pending_actions["conversation-1"] = {
        "action_type": "durable_write",
        "context": {
            "surface_client_cards": False,
            "durable_write_proposal": {
                "write_kind": "open_thread",
                "title": "Wake at 6am",
                "body": "Wake at 6am",
                "editable_fields": ["title", "body"],
                "apply_snapshot": {
                    "type": "open_thread",
                    "payload": {
                        "title": "Wake at 6am",
                        "summary": None,
                        "status": "active",
                    },
                },
                "proposal_id": "proposal-text-1",
                "risk_level": "medium",
            },
        },
    }
    override_memory_service(fake_memory_service)

    response = client.get("/conversations/conversation-1/pending-write")

    assert response.status_code == 200
    payload = response.json()
    assert payload["confirmation_required"] == 1
    assert payload.get("text_confirmation_pending") is True
    assert payload.get("write_proposals") == []
    assert payload.get("pending_proposal_id") == "proposal-text-1"


def test_get_pending_write_legacy_without_surface_flag_fails_closed_to_text(client):
    fake_memory_service = FakeConversationMemoryService()
    fake_memory_service.pending_actions["conversation-1"] = {
        "action_type": "durable_write",
        "context": {
            "durable_write_proposal": {
                "write_kind": "open_thread",
                "title": "Legacy pending",
                "body": "Legacy pending",
                "editable_fields": ["title", "body"],
                "apply_snapshot": {
                    "type": "open_thread",
                    "payload": {
                        "title": "Legacy pending",
                        "summary": None,
                        "status": "active",
                    },
                },
                "proposal_id": "proposal-legacy-1",
                "risk_level": "medium",
            }
        },
    }
    override_memory_service(fake_memory_service)

    response = client.get("/conversations/conversation-1/pending-write")

    assert response.status_code == 200
    payload = response.json()
    assert payload.get("text_confirmation_pending") is True
    assert payload.get("write_proposals") == []


def test_delete_conversation_returns_404_for_missing_conversation(client):
    override_memory_service(FakeConversationMemoryService())

    response = client.delete("/conversations/missing")

    assert response.status_code == 404
    assert response.json()["detail"] == "Conversation not found."
