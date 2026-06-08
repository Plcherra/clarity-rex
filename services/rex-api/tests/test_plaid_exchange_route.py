from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_plaid_sync_service
from app.main import app
from app.services.plaid_api_client import PlaidApiClientError
from app.services.plaid_sync_service import PlaidExchangeResult, PlaidSyncServiceError


class FakePlaidSyncService:
    call = None

    async def exchange_public_token(self, **kwargs):
        self.call = kwargs
        return PlaidExchangeResult(
            plaid_item_record_id="item-record-1",
            status="active",
            institution_name="Sandbox Bank",
        )


class PlaidExchangeFailureService:
    async def exchange_public_token(self, **kwargs):
        raise PlaidApiClientError("public token invalid", status_code=400)


class PlaidStorageFailureService:
    async def exchange_public_token(self, **kwargs):
        raise PlaidSyncServiceError("Cannot save Plaid connection right now.")


async def fake_current_user():
    return AuthenticatedUser(
        id="user-1",
        email="pedro@example.com",
        access_token="test-token",
    )


def test_exchange_token_route_returns_safe_item_summary():
    sync_service = FakePlaidSyncService()
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: sync_service

    with TestClient(app) as client:
        response = client.post(
            "/plaid/exchange-token",
            json={
                "public_token": " public-sandbox-token ",
                "institution_id": "ins_1",
                "institution_name": "Sandbox Bank",
            },
        )

    assert response.status_code == 200
    assert response.json() == {
        "plaid_item_record_id": "item-record-1",
        "status": "active",
        "institution_name": "Sandbox Bank",
        "accounts": [],
    }
    assert sync_service.call == {
        "user_id": "user-1",
        "public_token": "public-sandbox-token",
        "institution_id": "ins_1",
        "institution_name": "Sandbox Bank",
    }
    assert "access_token" not in response.text
    assert "public-sandbox-token" not in response.text
    assert "plaid-item-id" not in response.text


def test_exchange_token_route_requires_public_token():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: FakePlaidSyncService()

    with TestClient(app) as client:
        response = client.post("/plaid/exchange-token", json={"public_token": " "})

    assert response.status_code == 400
    assert response.json()["detail"] == "public_token is required."


def test_exchange_token_route_returns_safe_plaid_error():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = (
        lambda: PlaidExchangeFailureService()
    )

    with TestClient(app) as client:
        response = client.post(
            "/plaid/exchange-token",
            json={"public_token": "public-token"},
        )

    assert response.status_code == 400
    assert response.json()["detail"] == "public token invalid"


def test_exchange_token_route_returns_safe_storage_error():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = (
        lambda: PlaidStorageFailureService()
    )

    with TestClient(app) as client:
        response = client.post(
            "/plaid/exchange-token",
            json={"public_token": "public-token"},
        )

    assert response.status_code == 503
    assert response.json()["detail"] == "Cannot save Plaid connection right now."


def test_exchange_token_route_requires_authentication():
    async def unauthenticated_user():
        raise HTTPException(status_code=401, detail="Missing Supabase access token.")

    app.dependency_overrides[get_current_user] = unauthenticated_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: FakePlaidSyncService()

    with TestClient(app) as client:
        response = client.post(
            "/plaid/exchange-token",
            json={"public_token": "public-token"},
        )

    assert response.status_code == 401
    assert response.json()["detail"] == "Missing Supabase access token."
