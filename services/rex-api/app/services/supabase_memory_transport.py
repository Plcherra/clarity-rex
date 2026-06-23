import json
from typing import Optional
from urllib.parse import quote, urlencode

import httpx

from app.services.http_client import request_with_retries
from app.services.memory_errors import MemoryServiceError

PROTECTED_WRITE_FIELDS = {"id", "user_id", "created_at", "updated_at"}


class SupabaseMemoryTransport:
    async def _create_record(self, table: str, body: dict, select: str) -> dict:
        rows = await self._request(
            "POST",
            table,
            body=self._strip_protected_write_fields(body),
            query={"select": select},
            prefer="return=representation",
        )
        return self._first_row(rows)

    async def _list_records(
        self,
        table: str,
        select: str,
        filters: Optional[dict[str, object]] = None,
        order: Optional[str] = None,
        limit: int = 50,
    ) -> list[dict]:
        query = {
            "select": select,
            "limit": str(limit),
        }
        if order is not None:
            query["order"] = order

        for field, value in (filters or {}).items():
            if value is None:
                continue
            query[field] = self._eq_filter(value)

        return await self._request("GET", table, query=query)

    async def _update_record(
        self,
        table: str,
        record_id: str,
        updates: dict[str, object],
        select: str,
        empty_detail: str,
    ) -> Optional[dict]:
        updates = self._write_payload(updates)
        if not updates:
            raise MemoryServiceError(empty_detail, 400)

        rows = await self._request(
            "PATCH",
            table,
            body=updates,
            query={
                "id": f"eq.{record_id}",
                "select": select,
            },
            prefer="return=representation",
        )
        return rows[0] if rows else None

    def _eq_filter(self, value: object) -> str:
        if isinstance(value, bool):
            return f"eq.{str(value).lower()}"

        return f"eq.{value}"

    async def _rpc(
        self,
        function_name: str,
        body: Optional[dict] = None,
    ) -> list[dict]:
        rest_url = self.settings.supabase_rest_url
        api_key = self._supabase_api_key()
        auth_token = self._supabase_auth_token()
        if not rest_url or not api_key or not auth_token:
            raise MemoryServiceError("Supabase memory is not configured.")

        url = f"{rest_url}/rpc/{quote(function_name)}"
        headers = {
            "apikey": api_key,
            "Authorization": f"Bearer {auth_token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        try:
            response = await request_with_retries(
                "POST",
                url,
                headers=headers,
                json=body or {},
            )
            response.raise_for_status()
            raw_response = response.text
        except httpx.HTTPStatusError as error:
            raise MemoryServiceError("Supabase memory returned an error.") from error
        except (httpx.RequestError, TimeoutError) as error:
            raise MemoryServiceError("Cannot reach Supabase memory.") from error

        if not raw_response:
            return []

        try:
            data = json.loads(raw_response)
        except json.JSONDecodeError as error:
            raise MemoryServiceError(
                "Supabase memory returned an unreadable response.",
                status_code=500,
            ) from error

        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            return [data]

        raise MemoryServiceError("Supabase memory returned an unreadable response.")

    async def _request(
        self,
        method: str,
        table: str,
        body: Optional[dict] = None,
        query: Optional[dict[str, str]] = None,
        prefer: Optional[str] = None,
    ) -> list[dict]:
        rest_url = self.settings.supabase_rest_url
        api_key = self._supabase_api_key()
        auth_token = self._supabase_auth_token()
        if not rest_url or not api_key or not auth_token:
            raise MemoryServiceError("Supabase memory is not configured.")

        scoped_query = self._scoped_query(method, query)
        url = f"{rest_url}/{quote(table)}"
        if scoped_query:
            url = f"{url}?{urlencode(scoped_query)}"

        headers = {
            "apikey": api_key,
            "Authorization": f"Bearer {auth_token}",
            "Accept": "application/json",
        }
        json_body = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            json_body = self._scoped_body(method, body)
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
            raise MemoryServiceError("Supabase memory returned an error.") from error
        except (httpx.RequestError, TimeoutError) as error:
            raise MemoryServiceError("Cannot reach Supabase memory.") from error

        if not raw_response:
            return []

        try:
            data = json.loads(raw_response)
        except json.JSONDecodeError as error:
            raise MemoryServiceError(
                "Supabase memory returned an unreadable response.",
                status_code=500,
            ) from error

        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            return [data]

        raise MemoryServiceError("Supabase memory returned an unreadable response.")

    def _supabase_api_key(self) -> Optional[str]:
        if self.access_token and self.settings.supabase_anon_key:
            return self.settings.supabase_anon_key
        return self.settings.supabase_service_role_key

    def _supabase_auth_token(self) -> Optional[str]:
        if self.access_token and self.settings.supabase_anon_key:
            return self.access_token
        return self.settings.supabase_service_role_key

    def _scoped_body(self, method: str, body: dict) -> dict:
        body = self._strip_protected_write_fields(body)
        if method.upper() != "POST" or self.user_id is None:
            return body
        return {**body, "user_id": self.user_id}

    def _scoped_query(
        self,
        method: str,
        query: Optional[dict[str, str]],
    ) -> Optional[dict[str, str]]:
        if self.user_id is None or method.upper() == "POST":
            return query
        return {**(query or {}), "user_id": f"eq.{self.user_id}"}

    def _write_payload(self, payload: dict[str, object]) -> dict[str, object]:
        return {
            key: value
            for key, value in payload.items()
            if value is not None and key not in PROTECTED_WRITE_FIELDS
        }

    def _strip_protected_write_fields(
        self,
        payload: dict[str, object],
    ) -> dict[str, object]:
        return {
            key: value
            for key, value in payload.items()
            if key not in PROTECTED_WRITE_FIELDS
        }

    def _first_row(self, rows: list[dict]) -> dict:
        if not rows:
            raise MemoryServiceError("Supabase memory returned no rows.")

        return rows[0]
