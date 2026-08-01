import json
import logging
from typing import Optional
from urllib.parse import quote, urlencode

import httpx

from app.services.http_client import request_with_retries
from app.services.memory_errors import MemoryServiceError

logger = logging.getLogger(__name__)

PROTECTED_WRITE_FIELDS = {"id", "user_id", "created_at", "updated_at"}

# Fields that must be writable as JSON null (e.g. clearing completed_at on reopen).
NULLABLE_CLEAR_FIELDS = frozenset({"completed_at"})


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
        offset: int = 0,
    ) -> list[dict]:
        query = {
            "select": select,
            "limit": str(limit),
            "offset": str(max(offset, 0)),
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

    async def _delete_record(self, table: str, record_id: str) -> bool:
        await self._request(
            "DELETE",
            table,
            query={"id": f"eq.{record_id}"},
        )
        return True

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
            raise self._http_status_error(error, context="rpc") from error
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

        scoped_query = self._scoped_query(method, query, table=table)
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
            raise self._http_status_error(error, context=table) from error
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

    def _http_status_error(
        self,
        error: httpx.HTTPStatusError,
        *,
        context: str,
    ) -> MemoryServiceError:
        status_code = error.response.status_code
        body = error.response.text
        logger.warning(
            "Supabase REST error context=%s status=%s body=%s",
            context,
            status_code,
            body[:500],
        )
        if context == "user_insights" and status_code in {404, 406}:
            return MemoryServiceError(
                "Insights storage is not available yet.",
                status_code=503,
                error_code="insights_storage_unavailable",
            )
        if "user_insights" in body or "PGRST205" in body:
            return MemoryServiceError(
                "Insights storage is not available yet.",
                status_code=503,
                error_code="insights_storage_unavailable",
            )
        if status_code in {401, 403}:
            return MemoryServiceError(
                "Could not access stored data for this account.",
                status_code=status_code,
                error_code="storage_auth_failed",
            )
        return MemoryServiceError(
            "Stored data is temporarily unavailable.",
            status_code=503,
        )

    def _supabase_api_key(self) -> Optional[str]:
        if getattr(self, "use_service_role", False):
            return self.settings.supabase_service_role_key
        if self.access_token and self.settings.supabase_anon_key:
            return self.settings.supabase_anon_key
        return None

    def _supabase_auth_token(self) -> Optional[str]:
        if getattr(self, "use_service_role", False):
            return self.settings.supabase_service_role_key
        if self.access_token and self.settings.supabase_anon_key:
            return self.access_token
        return None

    def _scoped_body(self, method: str, body: dict) -> dict:
        body = self._strip_protected_write_fields(body)
        if method.upper() != "POST" or self.user_id is None:
            return body
        return {**body, "user_id": self.user_id}

    def _scoped_query(
        self,
        method: str,
        query: Optional[dict[str, str]],
        *,
        table: str = "",
    ) -> Optional[dict[str, str]]:
        """Scope reads/updates to the authenticated user.

        Most tables use ``user_id``. ``profiles`` is keyed by ``id`` (auth uid)
        and has no ``user_id`` column — injecting ``user_id`` fails the query
        and fail-closes assistant settings to Off.
        """
        if self.user_id is None or method.upper() == "POST":
            return query
        scoped = dict(query or {})
        if table == "profiles":
            scoped["id"] = f"eq.{self.user_id}"
            scoped.pop("user_id", None)
            return scoped
        scoped["user_id"] = f"eq.{self.user_id}"
        return scoped

    def _write_payload(self, payload: dict[str, object]) -> dict[str, object]:
        return {
            key: value
            for key, value in payload.items()
            if key not in PROTECTED_WRITE_FIELDS
            and (value is not None or key in NULLABLE_CLEAR_FIELDS)
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
