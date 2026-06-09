from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

import httpx

from app.config import Settings, get_settings
from app.services.http_client import request_with_retries
from app.services.plaid_config import require_plaid_configured


class PlaidApiClientError(Exception):
    def __init__(
        self,
        detail: str,
        *,
        status_code: int = 503,
        plaid_error_code: str | None = None,
        request_id: str | None = None,
    ) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code
        self.plaid_error_code = plaid_error_code
        self.request_id = request_id


@dataclass(frozen=True)
class PlaidLinkTokenPayload:
    user_id: str
    platform: str | None = None
    client_name: str = "Clarity"
    language: str = "en"
    products: tuple[str, ...] = ()
    country_codes: tuple[str, ...] = ()


class PlaidApiClient:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    async def create_link_token(self, payload: PlaidLinkTokenPayload) -> dict[str, Any]:
        user_id = payload.user_id.strip()
        if not user_id:
            raise PlaidApiClientError("user_id is required", status_code=400)

        config = require_plaid_configured(self.settings)
        platform = (payload.platform or "").strip().lower()
        body: dict[str, Any] = {
            "client_name": payload.client_name,
            "language": payload.language,
            "country_codes": list(payload.country_codes or config.country_codes),
            "products": list(payload.products or config.products),
            "user": {"client_user_id": user_id},
        }
        if self.settings.plaid_redirect_uri and platform != "android":
            body["redirect_uri"] = self.settings.plaid_redirect_uri
        if self.settings.plaid_android_package_name and platform == "android":
            body["android_package_name"] = self.settings.plaid_android_package_name
        if self.settings.plaid_webhook_url:
            body["webhook"] = self.settings.plaid_webhook_url
        if self.settings.plaid_account_filters_json:
            body["account_filters"] = self._account_filters()

        return await self._post("/link/token/create", body)

    async def exchange_public_token(self, public_token: str) -> dict[str, Any]:
        normalized_token = public_token.strip()
        if not normalized_token:
            raise PlaidApiClientError("public_token is required", status_code=400)

        return await self._post(
            "/item/public_token/exchange",
            {"public_token": normalized_token},
        )

    async def get_accounts(self, access_token: str) -> dict[str, Any]:
        return await self._post(
            "/accounts/get",
            {"access_token": self._required_access_token(access_token)},
        )

    async def sync_transactions(
        self,
        access_token: str,
        *,
        cursor: str | None = None,
        count: int = 100,
    ) -> dict[str, Any]:
        body: dict[str, Any] = {
            "access_token": self._required_access_token(access_token),
            "count": count,
        }
        if cursor:
            body["cursor"] = cursor

        return await self._post("/transactions/sync", body)

    async def remove_item(self, access_token: str) -> dict[str, Any]:
        return await self._post(
            "/item/remove",
            {"access_token": self._required_access_token(access_token)},
        )

    async def _post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        require_plaid_configured(self.settings)
        request_payload = {
            **payload,
            "client_id": self.settings.plaid_client_id,
            "secret": self.settings.plaid_secret,
        }

        try:
            response = await request_with_retries(
                "POST",
                f"{self.settings.plaid_base_url}{path}",
                json=request_payload,
                headers={"Content-Type": "application/json"},
                timeout=self.settings.plaid_timeout_seconds,
            )
            response.raise_for_status()
        except httpx.HTTPStatusError as error:
            raise self._http_status_error(error.response) from error
        except (httpx.RequestError, TimeoutError) as error:
            raise PlaidApiClientError("Cannot reach Plaid right now.") from error

        try:
            data = response.json()
        except ValueError as error:
            raise PlaidApiClientError(
                "Plaid returned an unreadable response.",
                status_code=502,
            ) from error

        if not isinstance(data, dict):
            raise PlaidApiClientError(
                "Plaid returned an unexpected response.",
                status_code=502,
            )
        return data

    def _http_status_error(self, response: httpx.Response) -> PlaidApiClientError:
        payload = self._safe_error_payload(response)
        status_code = 400 if response.status_code == 400 else 503
        detail = payload.get("error_message") or payload.get("display_message")
        return PlaidApiClientError(
            str(detail or "Plaid request failed."),
            status_code=status_code,
            plaid_error_code=_string_or_none(payload.get("error_code")),
            request_id=_string_or_none(payload.get("request_id")),
        )

    @staticmethod
    def _safe_error_payload(response: httpx.Response) -> dict[str, Any]:
        try:
            data = response.json()
        except ValueError:
            return {}
        return data if isinstance(data, dict) else {}

    def _account_filters(self) -> dict[str, Any]:
        raw_filters = (self.settings.plaid_account_filters_json or "").strip()
        if not raw_filters:
            return {}
        try:
            filters = json.loads(raw_filters)
        except json.JSONDecodeError as error:
            raise PlaidApiClientError(
                "PLAID_ACCOUNT_FILTERS_JSON must be valid JSON.",
                status_code=500,
            ) from error
        if not isinstance(filters, dict):
            raise PlaidApiClientError(
                "PLAID_ACCOUNT_FILTERS_JSON must be a JSON object.",
                status_code=500,
            )
        return filters

    @staticmethod
    def _required_access_token(access_token: str) -> str:
        normalized_token = access_token.strip()
        if not normalized_token:
            raise PlaidApiClientError("access_token is required", status_code=400)
        return normalized_token


def _string_or_none(value: Any) -> str | None:
    return value if isinstance(value, str) and value else None
