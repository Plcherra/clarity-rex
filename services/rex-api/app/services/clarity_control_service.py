import json
from typing import Any, Optional
from urllib.parse import quote, urlencode

import httpx

from app.config import Settings, get_settings
from app.services.http_client import request_with_retries

PROTECTED_FIELDS = {"id", "user_id", "created_at", "updated_at"}
MUTATING_ACTIONS = {
    "create_transaction",
    "update_transaction",
    "delete_transaction",
    "bulk_update_transaction_category",
    "delete_import_batch",
    "create_account",
    "update_account",
    "delete_account",
    "create_category",
    "update_category",
    "delete_category",
    "create_budget",
    "update_budget",
    "delete_budget",
}


class ClarityControlServiceError(Exception):
    def __init__(self, detail: str, status_code: int = 400) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


class ClarityControlService:
    def __init__(
        self,
        user_id: str,
        access_token: str,
        settings: Optional[Settings] = None,
    ) -> None:
        self.user_id = user_id
        self.access_token = access_token
        self.settings = settings or get_settings()

    async def execute(
        self,
        action: str,
        payload: dict[str, Any],
        *,
        confirmed: bool = False,
    ) -> list[dict[str, Any]]:
        cleaned_action = action.strip()
        if cleaned_action in MUTATING_ACTIONS and not confirmed:
            raise ClarityControlServiceError(
                "This Clarity action requires explicit confirmation.",
                status_code=428,
            )

        handler = getattr(self, f"_execute_{cleaned_action}", None)
        if handler is None:
            raise ClarityControlServiceError("Unsupported Clarity action.", 400)
        return await handler(payload)

    async def _execute_create_transaction(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        body = self._required_payload(
            payload,
            required=("account_id", "amount", "type", "date"),
            optional=(
                "category_id",
                "description",
                "merchant",
                "imported_from_csv",
                "import_id",
            ),
        )
        return await self._request(
            "POST",
            "transactions",
            body=body,
            prefer="return=representation",
        )

    async def _execute_update_transaction(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        record_id = self._required_id(payload)
        body = self._write_payload(
            payload,
            allowed=(
                "account_id",
                "category_id",
                "amount",
                "type",
                "description",
                "date",
                "merchant",
                "imported_from_csv",
                "import_id",
            ),
        )
        return await self._patch_by_id("transactions", record_id, body)

    async def _execute_delete_transaction(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        return await self._delete_by_id("transactions", self._required_id(payload))

    async def _execute_bulk_update_transaction_category(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        ids = payload.get("ids")
        category_id = str(payload.get("category_id") or "").strip()
        if not isinstance(ids, list) or not ids or not category_id:
            raise ClarityControlServiceError(
                "ids and category_id are required for bulk category updates.",
                400,
            )
        cleaned_ids = [str(value).strip() for value in ids if str(value).strip()]
        if not cleaned_ids:
            raise ClarityControlServiceError("At least one transaction id is required.")
        return await self._request(
            "PATCH",
            "transactions",
            body={"category_id": category_id},
            query={
                "id": f"in.({','.join(cleaned_ids)})",
                "select": "*",
            },
            prefer="return=representation",
        )

    async def _execute_delete_import_batch(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        account_id = str(payload.get("account_id") or "").strip()
        import_id = str(payload.get("import_id") or "").strip()
        if not account_id or not import_id:
            raise ClarityControlServiceError("account_id and import_id are required.")
        return await self._request(
            "DELETE",
            "transactions",
            query={
                "account_id": f"eq.{account_id}",
                "import_id": f"eq.{import_id}",
                "select": "*",
            },
            prefer="return=representation",
        )

    async def _execute_create_account(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        body = self._required_payload(
            payload,
            required=("name", "type"),
            optional=("institution", "balance", "currency", "is_active"),
        )
        body.setdefault("currency", "USD")
        body.setdefault("is_active", True)
        return await self._request(
            "POST",
            "accounts",
            body=body,
            prefer="return=representation",
        )

    async def _execute_update_account(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        record_id = self._required_id(payload)
        body = self._write_payload(
            payload,
            allowed=("name", "type", "institution", "balance", "currency", "is_active"),
        )
        return await self._patch_by_id("accounts", record_id, body)

    async def _execute_delete_account(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        return await self._delete_by_id("accounts", self._required_id(payload))

    async def _execute_create_category(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        body = self._required_payload(
            payload,
            required=("name", "type"),
            optional=("color", "icon"),
        )
        return await self._request(
            "POST",
            "categories",
            body=body,
            prefer="return=representation",
        )

    async def _execute_update_category(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        record_id = self._required_id(payload)
        body = self._write_payload(payload, allowed=("name", "type", "color", "icon"))
        return await self._patch_by_id("categories", record_id, body)

    async def _execute_delete_category(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        return await self._delete_by_id("categories", self._required_id(payload))

    async def _execute_create_budget(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        body = self._required_payload(
            payload,
            required=("name", "amount", "period"),
            optional=("category_id", "category_key", "start_date"),
        )
        return await self._request(
            "POST",
            "budgets",
            body=body,
            prefer="return=representation",
        )

    async def _execute_update_budget(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        record_id = self._required_id(payload)
        body = self._write_payload(
            payload,
            allowed=(
                "name",
                "category_id",
                "category_key",
                "amount",
                "period",
                "start_date",
            ),
        )
        return await self._patch_by_id("budgets", record_id, body)

    async def _execute_delete_budget(
        self,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        return await self._delete_by_id("budgets", self._required_id(payload))

    async def _patch_by_id(
        self,
        table: str,
        record_id: str,
        body: dict[str, Any],
    ) -> list[dict[str, Any]]:
        if not body:
            raise ClarityControlServiceError("At least one update field is required.")
        return await self._request(
            "PATCH",
            table,
            body=body,
            query={"id": f"eq.{record_id}", "select": "*"},
            prefer="return=representation",
        )

    async def _delete_by_id(self, table: str, record_id: str) -> list[dict[str, Any]]:
        return await self._request(
            "DELETE",
            table,
            query={"id": f"eq.{record_id}", "select": "*"},
            prefer="return=representation",
        )

    async def _request(
        self,
        method: str,
        table: str,
        body: Optional[dict[str, Any]] = None,
        query: Optional[dict[str, str]] = None,
        prefer: Optional[str] = None,
    ) -> list[dict[str, Any]]:
        rest_url = self.settings.supabase_rest_url
        api_key = self.settings.supabase_anon_key
        if not rest_url or not api_key or not self.access_token:
            raise ClarityControlServiceError("Supabase Clarity control is not configured.")

        scoped_query = {**(query or {})}
        if method.upper() != "POST":
            scoped_query["user_id"] = f"eq.{self.user_id}"
        url = f"{rest_url}/{quote(table)}"
        if scoped_query:
            url = f"{url}?{urlencode(scoped_query)}"

        headers = {
            "apikey": api_key,
            "Authorization": f"Bearer {self.access_token}",
            "Accept": "application/json",
        }
        json_body = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            json_body = self._body_with_user(method, body)
        if prefer:
            headers["Prefer"] = prefer

        try:
            response = await request_with_retries(
                method,
                url,
                headers=headers,
                json=json_body,
            )
            response.raise_for_status()
            raw_response = response.text
        except httpx.HTTPStatusError as error:
            raise ClarityControlServiceError(
                "Supabase Clarity control returned an error.",
                status_code=502,
            ) from error
        except (httpx.RequestError, TimeoutError) as error:
            raise ClarityControlServiceError(
                "Cannot reach Supabase Clarity control.",
                status_code=503,
            ) from error

        if not raw_response:
            return []
        try:
            data = json.loads(raw_response)
        except json.JSONDecodeError as error:
            raise ClarityControlServiceError(
                "Supabase Clarity control returned an unreadable response.",
                status_code=500,
            ) from error
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            return [data]
        raise ClarityControlServiceError(
            "Supabase Clarity control returned an unreadable response.",
            status_code=500,
        )

    def _body_with_user(self, method: str, body: dict[str, Any]) -> dict[str, Any]:
        cleaned = {
            key: value
            for key, value in body.items()
            if value is not None and key not in PROTECTED_FIELDS
        }
        if method.upper() == "POST":
            return {**cleaned, "user_id": self.user_id}
        return cleaned

    def _required_payload(
        self,
        payload: dict[str, Any],
        *,
        required: tuple[str, ...],
        optional: tuple[str, ...],
    ) -> dict[str, Any]:
        missing = [
            field
            for field in required
            if payload.get(field) is None or str(payload.get(field)).strip() == ""
        ]
        if missing:
            raise ClarityControlServiceError(
                f"Missing required field(s): {', '.join(missing)}.",
                400,
            )
        return self._write_payload(payload, allowed=(*required, *optional))

    def _write_payload(
        self,
        payload: dict[str, Any],
        *,
        allowed: tuple[str, ...],
    ) -> dict[str, Any]:
        return {
            key: payload[key]
            for key in allowed
            if key in payload and payload[key] is not None and key not in PROTECTED_FIELDS
        }

    def _required_id(self, payload: dict[str, Any]) -> str:
        record_id = str(payload.get("id") or "").strip()
        if not record_id:
            raise ClarityControlServiceError("id is required.", 400)
        return record_id
