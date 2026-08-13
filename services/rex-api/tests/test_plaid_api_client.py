import httpx
import pytest

from app.config import Settings
from app.services.plaid_api_client import (
    PlaidApiClient,
    PlaidApiClientError,
    PlaidLinkTokenPayload,
)


def configured_settings(**overrides):
    values = {
        "plaid_client_id": "client-id",
        "plaid_secret": "secret-value",
        "plaid_environment": "sandbox",
        "plaid_products": "transactions",
        "plaid_country_codes": "US",
        "plaid_timeout_seconds": 12,
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)


def make_response(status_code=200, json_data=None, text=None):
    request = httpx.Request("POST", "https://sandbox.plaid.com/test")
    if json_data is not None:
        return httpx.Response(status_code, json=json_data, request=request)
    return httpx.Response(status_code, text=text or "", request=request)


@pytest.mark.asyncio
async def test_create_link_token_posts_ios_oauth_payload(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return make_response(
            json_data={"link_token": "link-sandbox", "expiration": "soon"}
        )

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(
        configured_settings(
            plaid_android_package_name="com.app",
            plaid_ios_bundle_id="com.ios.app",
            plaid_redirect_uri="https://app.example.com/plaid/oauth",
            plaid_webhook_url="https://api.example.com/plaid/webhook",
            plaid_account_filters_json='{"depository":{"account_subtypes":["checking","savings"]}}',
        )
    )

    result = await client.create_link_token(
        PlaidLinkTokenPayload(user_id="user-1", platform="ios")
    )

    assert result["link_token"] == "link-sandbox"
    call = calls[0]
    assert call["method"] == "POST"
    assert call["url"] == "https://sandbox.plaid.com/link/token/create"
    assert call["timeout"] == 12
    assert call["json"]["client_id"] == "client-id"
    assert call["json"]["secret"] == "secret-value"
    assert call["json"]["client_name"] == "Clarity"
    assert call["json"]["products"] == ["transactions"]
    assert call["json"]["required_if_supported_products"] == ["liabilities"]
    assert call["json"]["country_codes"] == ["US"]
    assert call["json"]["user"] == {"client_user_id": "user-1"}
    assert call["json"]["redirect_uri"] == "https://app.example.com/plaid/oauth"
    assert call["json"]["webhook"] == "https://api.example.com/plaid/webhook"
    assert call["json"]["account_filters"] == {
        "depository": {"account_subtypes": ["checking", "savings"]}
    }
    assert "android_package_name" not in call["json"]
    assert "ios_bundle_id" not in call["json"]


@pytest.mark.asyncio
async def test_create_link_token_posts_web_oauth_payload(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return make_response(json_data={"link_token": "link-sandbox"})

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(
        configured_settings(
            plaid_android_package_name="com.app",
            plaid_redirect_uri="https://api.goclarity.app/plaid/oauth",
            plaid_web_redirect_uri="https://goclarity.app/app/",
        )
    )

    await client.create_link_token(
        PlaidLinkTokenPayload(user_id="user-1", platform="web")
    )

    assert calls[0]["json"]["redirect_uri"] == "https://goclarity.app/app/"
    assert "android_package_name" not in calls[0]["json"]


@pytest.mark.asyncio
async def test_create_link_token_web_falls_back_to_shared_redirect_uri(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return make_response(json_data={"link_token": "link-production"})

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(
        configured_settings(
            plaid_redirect_uri="https://api.goclarity.app/plaid/oauth",
        )
    )

    await client.create_link_token(
        PlaidLinkTokenPayload(user_id="user-1", platform="web")
    )

    assert calls[0]["json"]["redirect_uri"] == "https://api.goclarity.app/plaid/oauth"


@pytest.mark.asyncio
async def test_create_link_token_posts_android_package_payload(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return make_response(json_data={"link_token": "link-sandbox"})

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(
        configured_settings(
            plaid_android_package_name="com.app",
            plaid_redirect_uri="https://app.example.com/plaid/oauth",
        )
    )

    await client.create_link_token(
        PlaidLinkTokenPayload(user_id="user-1", platform="android")
    )

    assert calls[0]["json"]["android_package_name"] == "com.app"
    assert "redirect_uri" not in calls[0]["json"]


@pytest.mark.asyncio
async def test_plaid_methods_use_expected_endpoints(monkeypatch):
    endpoints = []

    async def fake_request(method, url, **kwargs):
        endpoints.append((url, kwargs["json"]))
        return make_response(json_data={"ok": True})

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(configured_settings())

    await client.exchange_public_token("public-token")
    await client.get_accounts("access-token")
    await client.sync_transactions("access-token", cursor="next", count=42)
    await client.remove_item("access-token")
    await client.get_webhook_verification_key("key-1")

    assert [url for url, _payload in endpoints] == [
        "https://sandbox.plaid.com/item/public_token/exchange",
        "https://sandbox.plaid.com/accounts/get",
        "https://sandbox.plaid.com/transactions/sync",
        "https://sandbox.plaid.com/item/remove",
        "https://sandbox.plaid.com/webhook_verification_key/get",
    ]
    assert endpoints[0][1]["public_token"] == "public-token"
    assert endpoints[1][1]["access_token"] == "access-token"
    assert endpoints[2][1]["cursor"] == "next"
    assert endpoints[2][1]["count"] == 42
    assert endpoints[3][1]["access_token"] == "access-token"
    assert endpoints[4][1]["key_id"] == "key-1"


@pytest.mark.asyncio
async def test_missing_config_fails_before_http(monkeypatch):
    async def fake_request(method, url, **kwargs):
        raise AssertionError("HTTP should not be called")

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(Settings(_env_file=None))

    with pytest.raises(RuntimeError, match="Plaid is not configured"):
        await client.create_link_token(PlaidLinkTokenPayload(user_id="user-1"))


@pytest.mark.asyncio
async def test_plaid_http_errors_are_sanitized(monkeypatch):
    async def fake_request(method, url, **kwargs):
        return make_response(
            status_code=400,
            json_data={
                "error_code": "INVALID_PUBLIC_TOKEN",
                "error_message": "public token invalid",
                "request_id": "request-1",
                "access_token": "should-not-surface",
            },
        )

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(configured_settings())

    with pytest.raises(PlaidApiClientError) as exc_info:
        await client.exchange_public_token("public-token")

    assert exc_info.value.status_code == 400
    assert exc_info.value.plaid_error_code == "INVALID_PUBLIC_TOKEN"
    assert exc_info.value.request_id == "request-1"
    assert "should-not-surface" not in exc_info.value.detail


@pytest.mark.asyncio
async def test_required_tokens_are_validated_before_http(monkeypatch):
    client = PlaidApiClient(configured_settings())

    with pytest.raises(PlaidApiClientError, match="public_token is required"):
        await client.exchange_public_token(" ")

    with pytest.raises(PlaidApiClientError, match="access_token is required"):
        await client.get_accounts(" ")

    with pytest.raises(PlaidApiClientError, match="key_id is required"):
        await client.get_webhook_verification_key(" ")


@pytest.mark.asyncio
async def test_invalid_account_filters_json_fails_before_http(monkeypatch):
    async def fake_request(method, url, **kwargs):
        raise AssertionError("HTTP should not be called")

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(configured_settings(plaid_account_filters_json="not-json"))

    with pytest.raises(PlaidApiClientError, match="valid JSON"):
        await client.create_link_token(PlaidLinkTokenPayload(user_id="user-1"))


@pytest.mark.asyncio
async def test_create_link_token_retries_without_liabilities_when_unsupported(
    monkeypatch,
):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        if len(calls) == 1:
            return make_response(
                status_code=400,
                json_data={
                    "error_code": "INVALID_FIELD",
                    "error_message": "required_if_supported_products is invalid",
                },
            )
        return make_response(json_data={"link_token": "link-sandbox"})

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(configured_settings())

    result = await client.create_link_token(
        PlaidLinkTokenPayload(user_id="user-1", platform="web")
    )

    assert result["link_token"] == "link-sandbox"
    assert len(calls) == 2
    assert calls[0]["json"]["required_if_supported_products"] == ["liabilities"]
    assert "required_if_supported_products" not in calls[1]["json"]


@pytest.mark.asyncio
async def test_get_account_balances_requests_a_live_institution_refresh(
    monkeypatch,
):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return make_response(
            json_data={
                "accounts": [
                    {
                        "account_id": "cap-card",
                        "balances": {
                            "current": 270.68,
                            "available": 608.08,
                            "limit": 878.76,
                        },
                    }
                ]
            }
        )

    monkeypatch.setattr(
        "app.services.plaid_api_client.request_with_retries",
        fake_request,
    )
    client = PlaidApiClient(configured_settings())

    result = await client.get_account_balances("access-token")

    assert result["accounts"][0]["balances"]["available"] == 608.08
    assert calls[0]["url"] == "https://sandbox.plaid.com/accounts/balance/get"
    assert "min_last_updated_datetime" in calls[0]["json"]["options"]

