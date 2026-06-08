import httpx
import pytest

from app.config import Settings
from app.services.plaid_api_client import PlaidApiClientError
from app.services.plaid_sync_service import PlaidSyncService, PlaidSyncServiceError


class FakePlaidClient:
    async def exchange_public_token(self, public_token):
        assert public_token == "public-token"
        return {
            "access_token": "access-token-secret",
            "item_id": "plaid-item-id",
            "request_id": "request-1",
        }


class MissingAccessTokenPlaidClient:
    async def exchange_public_token(self, public_token):
        return {"item_id": "plaid-item-id"}


class FullSyncPlaidClient:
    sync_cursors = []

    async def exchange_public_token(self, public_token):
        raise AssertionError("exchange should not be called during sync")

    async def get_accounts(self, access_token):
        assert access_token == "access-token-secret"
        return {
            "accounts": [
                {
                    "account_id": "plaid-account-1",
                    "name": "Checking",
                    "type": "depository",
                    "subtype": "checking",
                    "mask": "1234",
                    "balances": {
                        "current": 101.25,
                        "available": 90.0,
                        "iso_currency_code": "USD",
                    },
                }
            ]
        }

    async def sync_transactions(self, access_token, *, cursor=None, count=100):
        assert access_token == "access-token-secret"
        self.sync_cursors.append(cursor)
        if cursor == "cursor-old":
            return {
                "added": [
                    {
                        "transaction_id": "txn-added-1",
                        "account_id": "plaid-account-1",
                        "amount": 12.5,
                        "date": "2026-06-01",
                        "name": "Coffee",
                        "merchant_name": "Coffee Shop",
                        "pending": False,
                    }
                ],
                "modified": [
                    {
                        "transaction_id": "txn-modified-1",
                        "account_id": "plaid-account-1",
                        "amount": -200.0,
                        "date": "2026-06-02",
                        "name": "Payroll",
                        "pending": False,
                    }
                ],
                "removed": [{"transaction_id": "txn-removed-1"}],
                "next_cursor": "cursor-mid",
                "has_more": True,
            }
        return {
            "added": [
                {
                    "transaction_id": "txn-added-2",
                    "account_id": "plaid-account-1",
                    "amount": 44.0,
                    "date": "2026-06-03",
                    "name": "Groceries",
                    "pending": True,
                    "pending_transaction_id": "pending-1",
                }
            ],
            "modified": [],
            "removed": [],
            "next_cursor": "cursor-final",
            "has_more": False,
        }


class RateLimitedPlaidClient(FullSyncPlaidClient):
    async def sync_transactions(self, access_token, *, cursor=None, count=100):
        raise PlaidApiClientError(
            "rate limited",
            status_code=503,
            plaid_error_code="RATE_LIMIT_EXCEEDED",
        )


def settings(**overrides):
    values = {
        "supabase_url": "https://example.supabase.co",
        "supabase_service_role_key": "service-role-key",
        "plaid_client_id": "plaid-client-id",
        "plaid_secret": "plaid-secret",
        "plaid_token_encryption_secret": "token-encryption-secret",
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)


def response(status_code=200, json_data=None, text=None):
    request = httpx.Request("POST", "https://example.supabase.co/rest/v1/test")
    if json_data is not None:
        return httpx.Response(status_code, json=json_data, request=request)
    return httpx.Response(status_code, text=text or "", request=request)


def sync_storage_response(url, body, token_ref):
    if "/plaid_items?" in url and "select=" in url:
        return response(
            json_data=[
                {
                    "id": "item-record-1",
                    "user_id": "user-1",
                    "plaid_item_id": "plaid-item-id",
                    "sync_cursor": "cursor-old",
                    "status": "active",
                }
            ]
        )
    if "/plaid_item_secrets?" in url:
        return response(json_data=[{"access_token_ref": token_ref}])
    if "/accounts?" in url:
        return response(json_data=[{"id": "linked-account-1"}])
    return response(status_code=204, text="")


@pytest.mark.asyncio
async def test_exchange_public_token_persists_encrypted_backend_token_ref(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        if "/plaid_items" in url:
            return response(
                json_data=[
                    {
                        "id": "item-record-1",
                        "status": "active",
                        "institution_name": "Sandbox Bank",
                    }
                ]
            )
        return response(status_code=201, text="")

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )
    service = PlaidSyncService(
        plaid_client=FakePlaidClient(),
        settings=settings(),
    )

    result = await service.exchange_public_token(
        user_id="user-1",
        public_token="public-token",
        institution_id="ins_1",
        institution_name="Sandbox Bank",
    )

    assert result.plaid_item_record_id == "item-record-1"
    assert result.status == "active"
    assert result.institution_name == "Sandbox Bank"
    assert calls[0]["url"].startswith(
        "https://example.supabase.co/rest/v1/plaid_items"
    )
    assert calls[0]["headers"]["Authorization"] == "Bearer service-role-key"
    assert calls[0]["json"]["user_id"] == "user-1"
    assert calls[0]["json"]["plaid_item_id"] == "plaid-item-id"
    assert calls[1]["url"].startswith(
        "https://example.supabase.co/rest/v1/plaid_item_secrets"
    )
    token_ref = calls[1]["json"]["access_token_ref"]
    assert token_ref.startswith("fernet:v1:")
    assert "access-token-secret" not in token_ref
    assert "plaid-item-id" not in token_ref


@pytest.mark.asyncio
async def test_exchange_public_token_requires_valid_plaid_response():
    service = PlaidSyncService(
        plaid_client=MissingAccessTokenPlaidClient(),
        settings=settings(),
    )

    with pytest.raises(PlaidSyncServiceError, match="invalid access_token"):
        await service.exchange_public_token(
            user_id="user-1",
            public_token="public-token",
        )


@pytest.mark.asyncio
async def test_exchange_public_token_requires_supabase_service_role(monkeypatch):
    async def fake_request(method, url, **kwargs):
        raise AssertionError("Supabase should not be called")

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )
    service = PlaidSyncService(
        plaid_client=FakePlaidClient(),
        settings=settings(supabase_service_role_key=None),
    )

    with pytest.raises(PlaidSyncServiceError, match="not configured"):
        await service.exchange_public_token(
            user_id="user-1",
            public_token="public-token",
        )


def test_webhook_signature_requires_plaid_config_and_header():
    service = PlaidSyncService(
        plaid_client=FakePlaidClient(),
        settings=settings(),
    )

    assert service.verify_webhook_signature("signature") is True
    assert service.verify_webhook_signature(" ") is False

    missing_config_service = PlaidSyncService(
        plaid_client=FakePlaidClient(),
        settings=settings(plaid_client_id=None),
    )
    assert missing_config_service.verify_webhook_signature("signature") is False


@pytest.mark.asyncio
async def test_get_item_status_queries_current_user_item(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return response(
            json_data=[
                {
                    "id": "item-record-1",
                    "status": "active",
                    "institution_name": "Sandbox Bank",
                    "last_synced_at": "2026-06-07T12:00:00Z",
                    "webhook_last_received_at": "2026-06-07T12:01:00Z",
                }
            ]
        )

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )
    service = PlaidSyncService(
        plaid_client=FakePlaidClient(),
        settings=settings(),
    )

    result = await service.get_item_status(user_id="user-1", item_id="item-record-1")

    assert result.plaid_item_record_id == "item-record-1"
    assert result.status == "active"
    assert result.institution_name == "Sandbox Bank"
    assert calls[0]["method"] == "GET"
    assert "user_id=eq.user-1" in calls[0]["url"]
    assert "id=eq.item-record-1" in calls[0]["url"]


@pytest.mark.asyncio
async def test_webhook_sync_updates_marks_sync_requested(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return response(status_code=204, text="")

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )
    service = PlaidSyncService(
        plaid_client=FakePlaidClient(),
        settings=settings(),
    )

    result = await service.handle_webhook_event(
        payload={
            "webhook_type": "TRANSACTIONS",
            "webhook_code": "SYNC_UPDATES_AVAILABLE",
            "item_id": "plaid-item-id",
        }
    )

    assert result.action == "sync_requested"
    assert calls[0]["method"] == "PATCH"
    assert "plaid_item_id=eq.plaid-item-id" in calls[0]["url"]
    assert calls[0]["json"]["status"] == "active"
    assert calls[0]["json"]["metadata"]["sync_requested"] is True


@pytest.mark.asyncio
async def test_webhook_item_login_repaired_marks_active(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return response(status_code=204, text="")

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )
    service = PlaidSyncService(
        plaid_client=FakePlaidClient(),
        settings=settings(),
    )

    result = await service.handle_webhook_event(
        payload={
            "webhook_type": "ITEM",
            "webhook_code": "ITEM_LOGIN_REPAIRED",
            "item_id": "plaid-item-id",
        }
    )

    assert result.action == "item_login_repaired"
    assert calls[0]["json"]["status"] == "active"


@pytest.mark.asyncio
async def test_webhook_item_remove_marks_disconnected(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return response(status_code=204, text="")

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )
    service = PlaidSyncService(
        plaid_client=FakePlaidClient(),
        settings=settings(),
    )

    result = await service.handle_webhook_event(
        payload={
            "webhook_type": "ITEMS",
            "webhook_code": "REMOVE",
            "item_id": "plaid-item-id",
        }
    )

    assert result.action == "item_removed"
    assert calls[0]["json"]["status"] == "disconnected"


@pytest.mark.asyncio
async def test_sync_item_persists_accounts_transactions_and_cursor(monkeypatch):
    calls = []
    plaid_client = FullSyncPlaidClient()
    service = PlaidSyncService(
        plaid_client=plaid_client,
        settings=settings(),
    )
    token_ref = service._encrypted_access_token_ref("access-token-secret")

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return sync_storage_response(url, kwargs.get("json"), token_ref)

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )

    result = await service.sync_item("item-record-1")

    assert result.accounts_synced == 1
    assert result.transactions_added == 2
    assert result.transactions_modified == 1
    assert result.transactions_removed == 1
    assert result.next_cursor == "cursor-final"
    assert plaid_client.sync_cursors == ["cursor-old", "cursor-mid"]

    account_call = next(
        call for call in calls if "/accounts?" in call["url"] and call["method"] == "POST"
    )
    assert account_call["json"]["source"] == "plaid"
    assert account_call["json"]["plaid_account_id"] == "plaid-account-1"

    transaction_calls = [
        call
        for call in calls
        if "/transactions?" in call["url"] and call["method"] == "POST"
    ]
    assert len(transaction_calls) == 3
    assert transaction_calls[0]["json"]["source"] == "plaid"
    assert transaction_calls[0]["json"]["type"] == "expense"
    assert transaction_calls[1]["json"]["type"] == "income"
    assert transaction_calls[1]["json"]["amount"] == 200.0

    removed_call = next(
        call for call in calls if "/transactions?" in call["url"] and call["method"] == "PATCH"
    )
    assert "plaid_transaction_id=eq.txn-removed-1" in removed_call["url"]
    assert removed_call["json"]["removed_at"] is not None

    cursor_call = calls[-1]
    assert cursor_call["method"] == "PATCH"
    assert "/plaid_items?" in cursor_call["url"]
    assert cursor_call["json"]["sync_cursor"] == "cursor-final"
    assert "access-token-secret" not in str(calls)


@pytest.mark.asyncio
async def test_sync_item_handles_plaid_rate_limit(monkeypatch):
    service = PlaidSyncService(
        plaid_client=RateLimitedPlaidClient(),
        settings=settings(),
    )
    token_ref = service._encrypted_access_token_ref("access-token-secret")

    async def fake_request(method, url, **kwargs):
        return sync_storage_response(url, kwargs.get("json"), token_ref)

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )

    with pytest.raises(PlaidSyncServiceError) as exc_info:
        await service.sync_item("item-record-1")

    assert exc_info.value.status_code == 429
    assert "rate limited" in exc_info.value.detail
