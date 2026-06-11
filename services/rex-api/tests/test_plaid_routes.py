from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_plaid_api_client, get_plaid_sync_service
from app.main import app
from app.services.plaid_api_client import PlaidApiClientError
from app.services.plaid_config import PlaidConfigurationError
from app.services.plaid_sync_models import PlaidItemStatus, PlaidSyncServiceError


class FakePlaidApiClient:
    payload = None

    async def create_link_token(self, payload):
        self.payload = payload
        return {
            "link_token": "link-sandbox-token",
            "expiration": "2026-06-07T23:59:59Z",
            "access_token": "must-not-leak",
            "item_id": "must-not-leak",
        }


class MissingConfigPlaidApiClient:
    async def create_link_token(self, payload):
        raise PlaidConfigurationError("Plaid is not configured: PLAID_SECRET")


class PlaidErrorApiClient:
    async def create_link_token(self, payload):
        raise PlaidApiClientError(
            "Plaid request failed.",
            status_code=400,
            plaid_error_code="INVALID_REQUEST",
            request_id="request-1",
        )


class FakePlaidDisconnectService:
    disconnect_call = None

    async def disconnect_item(self, **kwargs):
        self.disconnect_call = kwargs
        return PlaidItemStatus(
            plaid_item_record_id=kwargs["item_id"],
            status="disconnected",
            institution_name="Sandbox Bank",
        )


class MissingPlaidDisconnectService:
    async def disconnect_item(self, **kwargs):
        raise PlaidSyncServiceError("Plaid item was not found.", status_code=404)


class FailingPlaidDisconnectService:
    async def disconnect_item(self, **kwargs):
        raise PlaidApiClientError("Plaid could not remove this bank.", status_code=503)


async def fake_current_user():
    return AuthenticatedUser(
        id="user-1",
        email="pedro@example.com",
        access_token="test-token",
    )


def test_link_token_route_returns_only_safe_metadata():
    plaid_client = FakePlaidApiClient()
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_api_client] = lambda: plaid_client

    with TestClient(app) as client:
        response = client.post(
            "/plaid/link-token",
            json={"account_id": "account-1", "platform": "ios"},
        )

    assert response.status_code == 200
    assert response.json() == {
        "link_token": "link-sandbox-token",
        "expiration": "2026-06-07T23:59:59Z",
    }
    assert plaid_client.payload.user_id == "user-1"
    assert plaid_client.payload.platform == "ios"
    assert "access_token" not in response.text
    assert "item_id" not in response.text


def test_link_token_route_allows_matching_future_user_id():
    plaid_client = FakePlaidApiClient()
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_api_client] = lambda: plaid_client

    with TestClient(app) as client:
        response = client.post("/plaid/link-token", json={"user_id": "user-1"})

    assert response.status_code == 200
    assert plaid_client.payload.user_id == "user-1"


def test_link_token_route_rejects_cross_user_token_request():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_api_client] = lambda: FakePlaidApiClient()

    with TestClient(app) as client:
        response = client.post("/plaid/link-token", json={"user_id": "user-2"})

    assert response.status_code == 403
    assert response.json()["detail"] == (
        "Cannot create a Plaid Link token for another user."
    )


def test_link_token_route_returns_503_when_plaid_is_missing_config():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_api_client] = (
        lambda: MissingConfigPlaidApiClient()
    )

    with TestClient(app) as client:
        response = client.post("/plaid/link-token")

    assert response.status_code == 503
    assert response.json()["detail"] == (
        "Plaid is not configured. Add backend Plaid credentials before connecting banks."
    )


def test_link_token_route_returns_normalized_plaid_errors():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_api_client] = lambda: PlaidErrorApiClient()

    with TestClient(app) as client:
        response = client.post("/plaid/link-token")

    assert response.status_code == 400
    assert response.json()["detail"] == "Plaid request failed."
    assert "request-1" not in response.text


def test_link_token_route_requires_authentication():
    async def unauthenticated_user():
        raise HTTPException(status_code=401, detail="Missing Supabase access token.")

    app.dependency_overrides[get_current_user] = unauthenticated_user
    app.dependency_overrides[get_plaid_api_client] = lambda: FakePlaidApiClient()

    with TestClient(app) as client:
        response = client.post("/plaid/link-token")

    assert response.status_code == 401
    assert response.json()["detail"] == "Missing Supabase access token."


def test_disconnect_item_route_returns_safe_disconnected_status():
    sync_service = FakePlaidDisconnectService()
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: sync_service

    with TestClient(app) as client:
        response = client.post("/plaid/disconnect-item/item-record-1")

    assert response.status_code == 200
    assert response.json() == {
        "plaid_item_record_id": "item-record-1",
        "status": "disconnected",
        "institution_name": "Sandbox Bank",
    }
    assert sync_service.disconnect_call == {
        "user_id": "user-1",
        "item_id": "item-record-1",
    }
    assert "access_token" not in response.text


def test_disconnect_item_route_returns_not_found_for_unowned_item():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = (
        lambda: MissingPlaidDisconnectService()
    )

    with TestClient(app) as client:
        response = client.post("/plaid/disconnect-item/item-record-other")

    assert response.status_code == 404
    assert response.json()["detail"] == "Plaid item was not found."


def test_disconnect_item_route_returns_safe_plaid_failure():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = (
        lambda: FailingPlaidDisconnectService()
    )

    with TestClient(app) as client:
        response = client.post("/plaid/disconnect-item/item-record-1")

    assert response.status_code == 503
    assert response.json()["detail"] == "Plaid could not remove this bank."
    assert "access_token" not in response.text


def test_plaid_oauth_fallback_get_is_available():
    with TestClient(app) as client:
        response = client.get("/plaid/oauth?oauth_state_id=state")

    assert response.status_code == 200
    assert "Return to Clarity" in response.text


def test_plaid_oauth_fallback_post_is_available():
    with TestClient(app) as client:
        response = client.post("/plaid/oauth", content="opaque-bank-payload")

    assert response.status_code == 200
    assert "Return to Clarity" in response.text
