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
    def __init__(self):
        self.sync_cursors = []
        self.refresh_calls = 0
        self.balance_get_calls = 0
        self.get_transaction_calls = 0

    async def get_transactions(
        self,
        access_token,
        *,
        start_date,
        end_date,
        offset=0,
        count=500,
    ):
        assert access_token == "access-token-secret"
        self.get_transaction_calls += 1
        return {"transactions": [], "total_transactions": 0}

    async def exchange_public_token(self, public_token):
        raise AssertionError("exchange should not be called during sync")

    async def refresh_transactions(self, access_token):
        assert access_token == "access-token-secret"
        self.refresh_calls += 1
        return {"request_id": "refresh-1"}

    async def get_account_balances(self, access_token):
        assert access_token == "access-token-secret"
        self.balance_get_calls += 1
        return await self.get_accounts(access_token)

    async def get_accounts(self, access_token):
        assert access_token == "access-token-secret"
        return {
            "accounts": [
                {
                    "account_id": "plaid-account-1",
                    "name": "depository Account 1234",
                    "type": "depository",
                    "subtype": "checking",
                    "mask": "1234",
                    "balances": {
                        "current": 101.25,
                        "available": 90.0,
                        "iso_currency_code": "USD",
                    },
                },
                {
                    "account_id": "plaid-account-2",
                    "name": "credit Account 9876",
                    "type": "credit",
                    "subtype": "credit card",
                    "mask": "9876",
                    "balances": {
                        "current": 321.98,
                        "available": 1200.0,
                        "limit": 1500.0,
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


class FailingAccountsPlaidClient(FullSyncPlaidClient):
    async def get_accounts(self, access_token):
        raise PlaidApiClientError(
            "plaid unavailable",
            status_code=503,
            plaid_error_code="INSTITUTION_ERROR",
        )


class DisconnectPlaidClient(FakePlaidClient):
    def __init__(self):
        self.removed_tokens = []

    async def remove_item(self, access_token):
        self.removed_tokens.append(access_token)
        return {"request_id": "remove-request-1"}


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
                    "institution_name": "Bank of Test",
                    "sync_cursor": "cursor-old",
                    "status": "active",
                }
            ]
        )
    if "/plaid_item_secrets?" in url:
        return response(json_data=[{"access_token_ref": token_ref}])
    if "/accounts?" in url:
        linked_id = (
            "linked-account-2"
            if body and body.get("plaid_account_id") == "plaid-account-2"
            else "linked-account-1"
        )
        return response(json_data=[{"id": linked_id}])
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


@pytest.mark.asyncio
async def test_mark_item_sync_degraded_updates_item_status(monkeypatch):
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

    await service.mark_item_sync_degraded("item-record-1")

    assert calls == [
        {
            "method": "PATCH",
            "url": (
                "https://example.supabase.co/rest/v1/plaid_items?"
                "id=eq.item-record-1"
            ),
            "headers": {
                "apikey": "service-role-key",
                "Authorization": "Bearer service-role-key",
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            },
            "json": {
                "status": "degraded",
                "metadata": {"last_sync_error": "initial_sync_failed"},
            },
        }
    ]


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
async def test_disconnect_item_removes_plaid_item_and_marks_local_records(monkeypatch):
    calls = []
    plaid_client = DisconnectPlaidClient()
    service = PlaidSyncService(
        plaid_client=plaid_client,
        settings=settings(),
    )
    token_ref = service._encrypted_access_token_ref("access-token-secret")

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        if "/plaid_items?" in url and method == "GET":
            return response(
                json_data=[
                    {
                        "id": "item-record-1",
                        "user_id": "user-1",
                        "plaid_item_id": "plaid-item-id",
                        "institution_name": "Bank of Test",
                        "sync_cursor": "cursor-old",
                        "status": "active",
                    }
                ]
            )
        if "/plaid_item_secrets?" in url and method == "GET":
            return response(json_data=[{"access_token_ref": token_ref}])
        return response(status_code=204, text="")

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )

    result = await service.disconnect_item(
        user_id="user-1",
        item_id="item-record-1",
    )

    assert result.plaid_item_record_id == "item-record-1"
    assert result.status == "disconnected"
    assert result.institution_name == "Bank of Test"
    assert plaid_client.removed_tokens == ["access-token-secret"]
    patch_calls = [call for call in calls if call["method"] == "PATCH"]
    assert [call["json"]["status"] for call in patch_calls[:2]] == [
        "disconnected",
        "disconnected",
    ]
    assert patch_calls[0]["url"].startswith(
        "https://example.supabase.co/rest/v1/plaid_items?"
    )
    assert "user_id=eq.user-1" in patch_calls[0]["url"]
    assert "id=eq.item-record-1" in patch_calls[0]["url"]
    assert patch_calls[1]["url"].startswith(
        "https://example.supabase.co/rest/v1/plaid_accounts?"
    )
    assert patch_calls[2]["url"].startswith(
        "https://example.supabase.co/rest/v1/accounts?"
    )
    assert patch_calls[2]["json"] == {"sync_status": "disconnected"}


@pytest.mark.asyncio
async def test_webhook_sync_updates_runs_item_sync(monkeypatch):
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

    result = await service.handle_webhook_event(
        payload={
            "webhook_type": "TRANSACTIONS",
            "webhook_code": "SYNC_UPDATES_AVAILABLE",
            "item_id": "plaid-item-id",
        }
    )

    assert result.action == "sync_completed"
    assert plaid_client.sync_cursors == ["cursor-old", "cursor-mid"]
    assert calls[0]["method"] == "PATCH"
    assert "plaid_item_id=eq.plaid-item-id" in calls[0]["url"]
    assert "status=neq.disconnected" in calls[0]["url"]
    assert calls[0]["json"]["status"] == "active"
    assert calls[0]["json"]["metadata"]["sync_requested"] is True
    assert any(
        call["method"] == "POST" and "/transactions?" in call["url"] for call in calls
    )
    cursor_call = next(
        call
        for call in calls
        if call["method"] == "PATCH"
        and "/plaid_items?" in call["url"]
        and "id=eq.item-record-1" in call["url"]
    )
    assert cursor_call["json"]["sync_cursor"] == "cursor-final"


@pytest.mark.asyncio
async def test_webhook_sync_rate_limit_marks_retryable_degraded(monkeypatch):
    calls = []
    service = PlaidSyncService(
        plaid_client=RateLimitedPlaidClient(),
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

    result = await service.handle_webhook_event(
        payload={
            "webhook_type": "TRANSACTIONS",
            "webhook_code": "SYNC_UPDATES_AVAILABLE",
            "item_id": "plaid-item-id",
        }
    )

    assert result.action == "sync_retryable"
    degraded_call = calls[-1]
    assert degraded_call["method"] == "PATCH"
    assert "id=eq.item-record-1" in degraded_call["url"]
    assert degraded_call["json"] == {
        "status": "degraded",
        "metadata": {
            "last_webhook_event": "SYNC_UPDATES_AVAILABLE",
            "sync_requested": True,
            "last_sync_error": "rate_limited",
            "retryable": True,
        },
    }


@pytest.mark.asyncio
async def test_webhook_sync_failure_marks_non_retryable_degraded(monkeypatch):
    calls = []
    service = PlaidSyncService(
        plaid_client=FailingAccountsPlaidClient(),
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

    result = await service.handle_webhook_event(
        payload={
            "webhook_type": "TRANSACTIONS",
            "webhook_code": "SYNC_UPDATES_AVAILABLE",
            "item_id": "plaid-item-id",
        }
    )

    assert result.action == "sync_degraded"
    degraded_call = calls[-1]
    assert degraded_call["method"] == "PATCH"
    assert "id=eq.item-record-1" in degraded_call["url"]
    assert degraded_call["json"] == {
        "status": "degraded",
        "metadata": {
            "last_webhook_event": "SYNC_UPDATES_AVAILABLE",
            "sync_requested": True,
            "last_sync_error": "plaid_api_failed",
            "retryable": False,
        },
    }


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

    assert result.accounts_synced == 2
    assert result.transactions_added == 2
    assert result.transactions_modified == 1
    assert result.transactions_removed == 1
    assert result.next_cursor == "cursor-final"
    assert plaid_client.sync_cursors == ["cursor-old", "cursor-mid"]

    account_calls = [
        call
        for call in calls
        if "/accounts?" in call["url"] and call["method"] == "POST"
    ]
    assert len(account_calls) == 2
    assert account_calls[0]["json"]["source"] == "plaid"
    assert account_calls[0]["json"]["name"] == "Bank of Test Checking 1234"
    assert account_calls[0]["json"]["institution"] == "Bank of Test"
    assert account_calls[0]["json"]["plaid_account_id"] == "plaid-account-1"
    assert account_calls[1]["json"]["name"] == "Bank of Test Credit Card 9876"
    assert account_calls[1]["json"]["plaid_account_id"] == "plaid-account-2"
    assert account_calls[1]["json"]["type"] == "credit card"
    assert account_calls[1]["json"]["balance"] == 321.98

    plaid_account_calls = [
        call
        for call in calls
        if "/plaid_accounts?" in call["url"] and call["method"] == "POST"
    ]
    assert len(plaid_account_calls) == 2
    assert plaid_account_calls[0]["json"]["institution_name"] == "Bank of Test"
    assert plaid_account_calls[0]["json"]["name"] == "Bank of Test Checking 1234"
    assert plaid_account_calls[0]["json"]["mask"] == "1234"
    assert plaid_account_calls[0]["json"]["account_subtype"] == "checking"
    assert plaid_account_calls[1]["json"]["institution_name"] == "Bank of Test"
    assert (
        plaid_account_calls[1]["json"]["name"] == "Bank of Test Credit Card 9876"
    )
    assert plaid_account_calls[1]["json"]["mask"] == "9876"
    assert plaid_account_calls[1]["json"]["account_subtype"] == "credit card"
    assert plaid_account_calls[1]["json"]["credit_limit"] == 1500.0
    assert "credit_limit" not in plaid_account_calls[0]["json"]

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

    cursor_call = next(
        call
        for call in calls
        if call["method"] == "PATCH"
        and "/plaid_items?" in call["url"]
        and "id=eq.item-record-1" in call["url"]
    )
    assert cursor_call["json"]["sync_cursor"] == "cursor-final"
    assert "access-token-secret" not in str(calls)


@pytest.mark.asyncio
async def test_sync_item_with_bank_refresh_requests_fresh_data(monkeypatch):
    calls = []
    plaid_client = FullSyncPlaidClient()
    active_settings = settings()
    active_settings.plaid_enable_transactions_refresh = True
    service = PlaidSyncService(
        plaid_client=plaid_client,
        settings=active_settings,
    )
    token_ref = service._encrypted_access_token_ref("access-token-secret")

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return sync_storage_response(url, kwargs.get("json"), token_ref)

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )

    result = await service.sync_item(
        "item-record-1",
        request_bank_refresh=True,
    )

    assert result.accounts_synced == 2
    assert result.balances_refreshed is True
    assert result.transactions_refresh_status == "ok"
    assert plaid_client.refresh_calls == 1
    assert plaid_client.balance_get_calls == 1


@pytest.mark.asyncio
async def test_sync_item_skips_transactions_refresh_when_disabled(monkeypatch):
    plaid_client = FullSyncPlaidClient()
    service = PlaidSyncService(
        plaid_client=plaid_client,
        settings=settings(),
    )
    token_ref = service._encrypted_access_token_ref("access-token-secret")

    async def fake_request(method, url, **kwargs):
        return sync_storage_response(url, kwargs.get("json"), token_ref)

    monkeypatch.setattr(
        "app.services.plaid_cursor_service.request_with_retries",
        fake_request,
    )

    result = await service.sync_item(
        "item-record-1",
        request_bank_refresh=True,
    )

    assert result.balances_refreshed is True
    assert result.transactions_refresh_status == "skipped"
    assert plaid_client.refresh_calls == 0
    assert plaid_client.balance_get_calls == 1


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
