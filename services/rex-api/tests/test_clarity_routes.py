import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_clarity_control_service
from app.main import app
from app.services.clarity_control_service import (
    ClarityControlService,
    ClarityControlServiceError,
)


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


def test_clarity_budget_action_accepts_category_identity(client):
    fake_service = FakeClarityControlService()
    app.dependency_overrides[get_clarity_control_service] = lambda: fake_service

    response = client.post(
        "/clarity/actions",
        json={
            "action": "create_budget",
            "confirmed": True,
            "payload": {
                "name": "Groceries",
                "category_id": "category-grocery",
                "category_key": "grocery supermarket",
                "amount": 500,
                "period": "monthly",
                "start_date": "2026-06-01",
            },
        },
    )

    assert response.status_code == 200
    assert fake_service.calls == [
        {
            "action": "create_budget",
            "payload": {
                "name": "Groceries",
                "category_id": "category-grocery",
                "category_key": "grocery supermarket",
                "amount": 500,
                "period": "monthly",
                "start_date": "2026-06-01",
            },
            "confirmed": True,
        }
    ]


@pytest.mark.asyncio
async def test_clarity_control_service_writes_budget_category_identity():
    service = ClarityControlService(user_id="user-1", access_token="token")
    calls = []

    async def fake_request(method, table, **kwargs):
        calls.append({"method": method, "table": table, **kwargs})
        return [{"id": "budget-1"}]

    service._request = fake_request

    result = await service.execute(
        "create_budget",
        {
            "name": "Groceries",
            "category_id": "category-grocery",
            "category_key": "grocery supermarket",
            "amount": 500,
            "period": "monthly",
            "start_date": "2026-06-01",
        },
        confirmed=True,
    )

    assert result == [{"id": "budget-1"}]
    assert calls == [
        {
            "method": "POST",
            "table": "budgets",
            "body": {
                "name": "Groceries",
                "category_id": "category-grocery",
                "category_key": "grocery supermarket",
                "amount": 500,
                "period": "monthly",
                "start_date": "2026-06-01",
            },
            "prefer": "return=representation",
        }
    ]
