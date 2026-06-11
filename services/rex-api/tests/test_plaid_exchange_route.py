from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import get_plaid_sync_service
from app.main import app
from app.services.plaid_api_client import PlaidApiClientError
from app.services.plaid_sync_service import (
    PlaidExchangeResult,
    PlaidSyncResult,
    PlaidSyncServiceError,
)


class FakePlaidSyncService:
    exchange_call = None
    sync_call = None
    degraded_call = None

    async def exchange_public_token(self, **kwargs):
        self.exchange_call = kwargs
        return PlaidExchangeResult(
            plaid_item_record_id="item-record-1",
            status="active",
            institution_name="Sandbox Bank",
        )

    async def sync_item(self, item_id):
        self.sync_call = item_id
        return PlaidSyncResult(
            plaid_item_record_id=item_id,
            accounts_synced=2,
            transactions_added=3,
            transactions_modified=1,
            transactions_removed=0,
            next_cursor="cursor-1",
        )

    async def sanitized_accounts_for_item(self, **kwargs):
        self.account_summary_call = kwargs
        return [
            {
                "linked_account_id": "account-1",
                "plaid_item_record_id": kwargs["item_id"],
                "institution_name": "Sandbox Bank",
                "name": "Adv Plus Banking",
                "official_name": "Advantage Plus Banking",
                "mask": "1234",
                "account_type": "depository",
                "account_subtype": "checking",
                "status": "active",
                "current_balance": 1250.25,
                "available_balance": 1200.0,
                "iso_currency_code": "USD",
            },
            {
                "linked_account_id": "account-2",
                "plaid_item_record_id": kwargs["item_id"],
                "institution_name": "Sandbox Bank",
                "name": "Travel Rewards",
                "official_name": None,
                "mask": "9876",
                "account_type": "credit",
                "account_subtype": "credit card",
                "status": "active",
                "current_balance": -432.1,
                "available_balance": None,
                "iso_currency_code": "USD",
            },
        ]

    async def mark_item_sync_degraded(self, item_id):
        self.degraded_call = item_id


class PlaidExchangeFailureService:
    async def exchange_public_token(self, **kwargs):
        raise PlaidApiClientError("public token invalid", status_code=400)


class PlaidStorageFailureService:
    async def exchange_public_token(self, **kwargs):
        raise PlaidSyncServiceError("Cannot save Plaid connection right now.")


class PlaidInitialSyncFailureService(FakePlaidSyncService):
    async def sync_item(self, item_id):
        raise PlaidSyncServiceError("Could not sync Plaid accounts right now.")


class PlaidInitialSyncPlaidFailureService(FakePlaidSyncService):
    async def sync_item(self, item_id):
        raise PlaidApiClientError("Plaid sync failed safely.", status_code=503)


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
        "accounts": [
            {
                "linked_account_id": "account-1",
                "plaid_item_record_id": "item-record-1",
                "institution_name": "Sandbox Bank",
                "name": "Adv Plus Banking",
                "official_name": "Advantage Plus Banking",
                "mask": "1234",
                "account_type": "depository",
                "account_subtype": "checking",
                "status": "active",
                "current_balance": 1250.25,
                "available_balance": 1200.0,
                "iso_currency_code": "USD",
            },
            {
                "linked_account_id": "account-2",
                "plaid_item_record_id": "item-record-1",
                "institution_name": "Sandbox Bank",
                "name": "Travel Rewards",
                "official_name": None,
                "mask": "9876",
                "account_type": "credit",
                "account_subtype": "credit card",
                "status": "active",
                "current_balance": -432.1,
                "available_balance": None,
                "iso_currency_code": "USD",
            },
        ],
        "accounts_synced": 2,
        "transactions_added": 3,
        "transactions_modified": 1,
        "transactions_removed": 0,
    }
    assert sync_service.exchange_call == {
        "user_id": "user-1",
        "public_token": "public-sandbox-token",
        "institution_id": "ins_1",
        "institution_name": "Sandbox Bank",
    }
    assert sync_service.sync_call == "item-record-1"
    assert sync_service.account_summary_call == {
        "user_id": "user-1",
        "item_id": "item-record-1",
    }
    assert "access_token" not in response.text
    assert "public-sandbox-token" not in response.text
    assert "plaid-item-id" not in response.text
    assert "plaid_account_id" not in response.text


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


def test_exchange_token_route_returns_safe_initial_sync_error():
    sync_service = PlaidInitialSyncFailureService()
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: sync_service

    with TestClient(app) as client:
        response = client.post(
            "/plaid/exchange-token",
            json={"public_token": "public-token"},
        )

    assert response.status_code == 200
    assert response.json() == {
        "plaid_item_record_id": "item-record-1",
        "status": "degraded",
        "institution_name": "Sandbox Bank",
        "accounts": [],
        "accounts_synced": 0,
        "transactions_added": 0,
        "transactions_modified": 0,
        "transactions_removed": 0,
    }
    assert sync_service.degraded_call == "item-record-1"
    assert "public-token" not in response.text


def test_exchange_token_route_defers_plaid_initial_sync_failure():
    sync_service = PlaidInitialSyncPlaidFailureService()
    app.dependency_overrides[get_current_user] = fake_current_user
    app.dependency_overrides[get_plaid_sync_service] = lambda: sync_service

    with TestClient(app) as client:
        response = client.post(
            "/plaid/exchange-token",
            json={"public_token": "public-token"},
        )

    assert response.status_code == 200
    assert response.json()["status"] == "degraded"
    assert response.json()["plaid_item_record_id"] == "item-record-1"
    assert sync_service.degraded_call == "item-record-1"
    assert "public-token" not in response.text


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
