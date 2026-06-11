from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_plaid_sync_service, get_plaid_webhook_verifier
from app.main import app
from app.services.plaid_sync_service import (
    PlaidItemStatus,
    PlaidSyncResult,
    PlaidSyncServiceError,
)
from app.services.plaid_webhook_verifier import PlaidWebhookVerificationError


class FakePlaidWebhookVerifier:
    plaid_verification = None
    raw_body = None

    async def verify(self, *, plaid_verification, raw_body):
        self.plaid_verification = plaid_verification
        self.raw_body = raw_body
        if plaid_verification != "valid-signature":
            raise PlaidWebhookVerificationError("invalid")


class FakePlaidSyncService:
    status_call = None
    webhook_payloads = []

    async def handle_webhook_event(self, *, payload):
        self.webhook_payloads.append(payload)

    async def get_item_status(self, *, user_id, item_id):
        self.status_call = {"user_id": user_id, "item_id": item_id}
        return PlaidItemStatus(
            plaid_item_record_id=item_id,
            status="active",
            institution_name="Sandbox Bank",
            last_synced_at="2026-06-07T12:00:00Z",
            webhook_last_received_at="2026-06-07T12:01:00Z",
        )


class MissingPlaidItemService(FakePlaidSyncService):
    async def get_item_status(self, *, user_id, item_id):
        raise PlaidSyncServiceError("Plaid item was not found.", status_code=404)


class FakePlaidManualSyncService(FakePlaidSyncService):
    sync_item_id = None

    async def sync_item(self, item_id):
        self.sync_item_id = item_id
        return PlaidSyncResult(
            plaid_item_record_id=item_id,
            accounts_synced=2,
            transactions_added=3,
            transactions_modified=1,
            transactions_removed=1,
            next_cursor="cursor-next",
        )


class FailingPlaidManualSyncService(FakePlaidSyncService):
    async def sync_item(self, item_id):
        raise PlaidSyncServiceError("Plaid item was not found.", status_code=404)


async def fake_current_user():
    return AuthenticatedUser(
        id="user-1",
        email="pedro@example.com",
        access_token="test-token",
    )


def test_webhook_accepts_verified_payload_and_runs_background_handler():
    service = FakePlaidSyncService()
    verifier = FakePlaidWebhookVerifier()
    service.webhook_payloads = []
    app.dependency_overrides[get_plaid_sync_service] = lambda: service
    app.dependency_overrides[get_plaid_webhook_verifier] = lambda: verifier
    raw_body = (
        b'{"webhook_type":"TRANSACTIONS","webhook_code":"SYNC_UPDATES_AVAILABLE",'
        b'"item_id":"plaid-item-id"}'
    )

    with TestClient(app) as client:
        response = client.post(
            "/plaid/webhook",
            headers={"Plaid-Verification": "valid-signature"},
            content=raw_body,
        )

    assert response.status_code == 200
    assert response.json() == {"received": True}
    assert verifier.plaid_verification == "valid-signature"
    assert verifier.raw_body == raw_body
    assert service.webhook_payloads == [
        {
            "webhook_type": "TRANSACTIONS",
            "webhook_code": "SYNC_UPDATES_AVAILABLE",
            "item_id": "plaid-item-id",
        }
    ]
    assert "access_token" not in response.text


def test_webhook_rejects_missing_or_invalid_signature():
    service = FakePlaidSyncService()
    service.webhook_payloads = []
    app.dependency_overrides[get_plaid_sync_service] = lambda: service
    app.dependency_overrides[get_plaid_webhook_verifier] = (
        lambda: FakePlaidWebhookVerifier()
    )

    with TestClient(app) as client:
        response = client.post(
            "/plaid/webhook",
            json={"webhook_code": "SYNC_UPDATES_AVAILABLE"},
        )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid Plaid webhook verification."
    assert service.webhook_payloads == []


def test_webhook_rejects_invalid_payload_even_with_valid_signature():
    app.dependency_overrides[get_plaid_sync_service] = lambda: FakePlaidSyncService()
    app.dependency_overrides[get_plaid_webhook_verifier] = (
        lambda: FakePlaidWebhookVerifier()
    )

    with TestClient(app) as client:
        response = client.post(
            "/plaid/webhook",
            headers={"Plaid-Verification": "valid-signature"},
            json={"webhook_code": "SYNC_UPDATES_AVAILABLE"},
        )

    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid Plaid webhook payload."


def test_webhook_rejects_item_event_without_item_id():
    app.dependency_overrides[get_plaid_sync_service] = lambda: FakePlaidSyncService()
    app.dependency_overrides[get_plaid_webhook_verifier] = (
        lambda: FakePlaidWebhookVerifier()
    )

    with TestClient(app) as client:
        response = client.post(
            "/plaid/webhook",
            headers={"Plaid-Verification": "valid-signature"},
            json={
                "webhook_type": "TRANSACTIONS",
                "webhook_code": "SYNC_UPDATES_AVAILABLE",
            },
        )

    assert response.status_code == 400
    assert response.json()["detail"] == "Plaid webhook item_id is required."


def test_item_status_route_returns_current_users_item_status():
    service = FakePlaidSyncService()
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: service

    with TestClient(app) as client:
        response = client.get("/plaid/item-status/item-record-1")

    assert response.status_code == 200
    assert response.json() == {
        "plaid_item_record_id": "item-record-1",
        "status": "active",
        "institution_name": "Sandbox Bank",
        "last_synced_at": "2026-06-07T12:00:00Z",
        "webhook_last_received_at": "2026-06-07T12:01:00Z",
    }
    assert service.status_call == {"user_id": "user-1", "item_id": "item-record-1"}
    assert "access_token" not in response.text


def test_item_status_route_returns_safe_not_found():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: MissingPlaidItemService()

    with TestClient(app) as client:
        response = client.get("/plaid/item-status/missing-item")

    assert response.status_code == 404
    assert response.json()["detail"] == "Plaid item was not found."


def test_item_status_route_requires_authentication():
    async def unauthenticated_user():
        raise HTTPException(status_code=401, detail="Missing Supabase access token.")

    app.dependency_overrides[get_current_user] = unauthenticated_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: FakePlaidSyncService()

    with TestClient(app) as client:
        response = client.get("/plaid/item-status/item-record-1")

    assert response.status_code == 401
    assert response.json()["detail"] == "Missing Supabase access token."


def test_manual_sync_route_requires_current_user_item_access():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: MissingPlaidItemService()

    with TestClient(app) as client:
        response = client.post("/plaid/sync-item/item-record-1")

    assert response.status_code == 404
    assert response.json()["detail"] == "Plaid item was not found."


def test_manual_sync_route_returns_safe_counts_for_current_user_item():
    service = FakePlaidManualSyncService()
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: service

    with TestClient(app) as client:
        response = client.post("/plaid/sync-item/item-record-1")

    assert response.status_code == 200
    assert response.json() == {
        "plaid_item_record_id": "item-record-1",
        "accounts_synced": 2,
        "transactions_added": 3,
        "transactions_modified": 1,
        "transactions_removed": 1,
        "next_cursor": "cursor-next",
    }
    assert service.status_call == {"user_id": "user-1", "item_id": "item-record-1"}
    assert service.sync_item_id == "item-record-1"
    assert "access_token" not in response.text


def test_manual_sync_route_returns_safe_sync_error():
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = (
        lambda: FailingPlaidManualSyncService()
    )

    with TestClient(app) as client:
        response = client.post("/plaid/sync-item/missing-item")

    assert response.status_code == 404
    assert response.json()["detail"] == "Plaid item was not found."
