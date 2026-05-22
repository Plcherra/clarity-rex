import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_clarity_control_service
from app.main import app
from app.services.clarity_control_service import ClarityControlServiceError


@pytest.fixture
def client():
    app.dependency_overrides.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


class FakeClarityControlService:
    def __init__(self, error=None):
        self.calls = []
        self.error = error

    async def execute(self, action, payload, *, confirmed=False):
        self.calls.append(
            {
                "action": action,
                "payload": payload,
                "confirmed": confirmed,
            }
        )
        if self.error is not None:
            raise self.error
        return [{"id": "transaction-1", "merchant": "Coffee Shop"}]


def test_clarity_action_executes_confirmed_control(client):
    fake_service = FakeClarityControlService()
    app.dependency_overrides[get_clarity_control_service] = lambda: fake_service

    response = client.post(
        "/clarity/actions",
        json={
            "action": "update_transaction",
            "confirmed": True,
            "payload": {
                "id": "transaction-1",
                "merchant": "Coffee Shop",
            },
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "action": "update_transaction",
        "status": "applied",
        "result": [{"id": "transaction-1", "merchant": "Coffee Shop"}],
    }
    assert fake_service.calls == [
        {
            "action": "update_transaction",
            "payload": {
                "id": "transaction-1",
                "merchant": "Coffee Shop",
            },
            "confirmed": True,
        }
    ]


def test_clarity_action_returns_confirmation_requirement(client):
    fake_service = FakeClarityControlService(
        error=ClarityControlServiceError(
            "This Clarity action requires explicit confirmation.",
            status_code=428,
        )
    )
    app.dependency_overrides[get_clarity_control_service] = lambda: fake_service

    response = client.post(
        "/clarity/actions",
        json={
            "action": "delete_transaction",
            "payload": {"id": "transaction-1"},
        },
    )

    assert response.status_code == 428
    assert response.json() == {
        "detail": "This Clarity action requires explicit confirmation."
    }
