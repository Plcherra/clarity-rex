import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_memory_service, get_memory_write_service
from app.main import app
from app.models.memory import MemoryCreateRequest
from app.services.memory_discipline_writes import MemoryWriteError
from app.services.memory_service import MemoryServiceError


@pytest.fixture
def client():
    app.dependency_overrides.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


class FakeMemoryWriteService:
    def __init__(self, *, error=None, record=None, verify_active=True):
        self.error = error
        self.record = record or {
            "id": "memory-new",
            "memory_type": "fact",
            "content": "Pedro lives in Somerville.",
            "source_conversation_id": None,
            "source_message_id": None,
            "importance": 3,
            "active": True,
            "superseded_by": None,
            "confidence": None,
            "correction_group": None,
            "metadata": {"memory_category": "Places"},
            "created_at": "2026-06-01T10:00:00Z",
            "updated_at": "2026-06-01T10:00:00Z",
            "last_accessed_at": None,
        }
        self.verify_active = verify_active
        self.last_request = None

    async def create_memory(self, request: MemoryCreateRequest):
        if self.error is not None:
            raise self.error
        self.last_request = request
        return dict(self.record)


class FakeMemoryManagementService:
    def __init__(self, *, error=None, active_ids=None):
        self.error = error
        self.active_ids = {"memory-new"} if active_ids is None else active_ids
        self.list_calls = []

    def _raise_if_configured(self):
        if self.error is not None:
            raise self.error

    async def list_long_term_memory(self, limit=50, memory_type=None, active=None):
        self._raise_if_configured()
        self.list_calls.append(
            {"limit": limit, "memory_type": memory_type, "active": active}
        )
        if active is not True:
            return []
        return [
            {
                "id": memory_id,
                "memory_type": "fact",
                "content": "Pedro lives in Somerville.",
                "source_conversation_id": None,
                "source_message_id": None,
                "importance": 3,
                "active": True,
                "superseded_by": None,
                "confidence": None,
                "correction_group": None,
                "metadata": {},
                "created_at": "2026-06-01T10:00:00Z",
                "updated_at": "2026-06-01T10:00:00Z",
                "last_accessed_at": None,
            }
            for memory_id in self.active_ids
        ]


def override_create_dependencies(
    *,
    write_service,
    memory_service=None,
):
    app.dependency_overrides[get_memory_write_service] = lambda: write_service
    app.dependency_overrides[get_memory_service] = lambda: (
        memory_service or FakeMemoryManagementService()
    )


def test_create_memory_returns_201_with_confirmed_record(client):
    write_service = FakeMemoryWriteService()
    memory_service = FakeMemoryManagementService()
    override_create_dependencies(
        write_service=write_service,
        memory_service=memory_service,
    )

    response = client.post(
        "/memory",
        json={
            "memory_type": "fact",
            "content": "Pedro lives in Somerville.",
            "importance": 4,
            "memory_category": "Places",
        },
    )

    assert response.status_code == 201
    data = response.json()
    assert data["id"] == "memory-new"
    assert data["content"] == "Pedro lives in Somerville."
    assert write_service.last_request.memory_type == "fact"
    assert write_service.last_request.memory_category == "Places"
    assert memory_service.list_calls == [
        {"limit": 100, "memory_type": None, "active": True}
    ]


def test_create_memory_validates_payload(client):
    override_create_dependencies(write_service=FakeMemoryWriteService())

    response = client.post("/memory", json={"memory_type": "fact", "content": ""})

    assert response.status_code == 422


def test_create_memory_maps_write_errors(client):
    override_create_dependencies(
        write_service=FakeMemoryWriteService(
            error=MemoryWriteError("Similar memory already exists.", 409)
        )
    )

    response = client.post(
        "/memory",
        json={"memory_type": "fact", "content": "Pedro lives in Somerville."},
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Similar memory already exists."


def test_create_memory_returns_409_when_not_visible(client):
    memory_service = FakeMemoryManagementService(active_ids=set())
    override_create_dependencies(
        write_service=FakeMemoryWriteService(),
        memory_service=memory_service,
    )

    response = client.post(
        "/memory",
        json={"memory_type": "fact", "content": "Pedro lives in Somerville."},
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Memory create was not confirmed."
    assert memory_service.list_calls == [
        {"limit": 100, "memory_type": None, "active": True}
    ]


def test_create_memory_maps_service_errors(client):
    override_create_dependencies(
        write_service=FakeMemoryWriteService(
            error=MemoryServiceError("Supabase unavailable.", status_code=503)
        )
    )

    response = client.post(
        "/memory",
        json={"memory_type": "preference", "content": "Pedro prefers email."},
    )

    assert response.status_code == 503
    assert response.json()["detail"] == "Supabase unavailable."
