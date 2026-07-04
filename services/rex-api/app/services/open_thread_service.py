from __future__ import annotations

import re
from typing import Any, Optional

from app.models.open_thread import (
    MAX_ACTIVE_OPEN_THREADS,
    OpenThreadCreateRequest,
    OpenThreadUpdateRequest,
)
from app.services.open_thread_repository import OpenThreadRepository


class OpenThreadServiceError(Exception):
    def __init__(self, detail: str, status_code: int = 400) -> None:
        self.detail = detail
        self.status_code = status_code
        super().__init__(detail)


class OpenThreadService:
    def __init__(self, memory_service: Any) -> None:
        self.memory_service = memory_service
        self.repository = OpenThreadRepository(memory_service)

    async def create_thread(self, request: OpenThreadCreateRequest) -> dict[str, Any]:
        active_count = len(await self.list_active_threads())
        if request.status == "active" and active_count >= MAX_ACTIVE_OPEN_THREADS:
            raise OpenThreadServiceError(
                f"You can have at most {MAX_ACTIVE_OPEN_THREADS} active open threads. "
                "Close or pause one before adding another.",
                409,
            )

        payload = _payload(request)
        payload["title"] = _clean_required(payload.get("title"), "title")
        payload.setdefault("user_id", getattr(self.memory_service, "user_id", None))
        if not payload.get("user_id"):
            raise OpenThreadServiceError("User context is required.", 401)

        try:
            return await self.repository.create_thread(payload)
        except Exception as error:
            raise OpenThreadServiceError(str(error), 500) from error

    async def list_threads(
        self,
        *,
        status: str | None = None,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        try:
            return await self.repository.list_threads(status=status, limit=limit)
        except Exception as error:
            raise OpenThreadServiceError(str(error), 500) from error

    async def list_active_threads(self, limit: int = MAX_ACTIVE_OPEN_THREADS) -> list[dict]:
        return await self.list_threads(status="active", limit=limit)

    async def update_thread(
        self,
        thread_id: str,
        request: OpenThreadUpdateRequest,
    ) -> dict[str, Any]:
        payload = _payload(request)
        if "title" in payload:
            payload["title"] = _clean_required(payload["title"], "title")

        if payload.get("status") == "active":
            active = await self.list_active_threads(limit=MAX_ACTIVE_OPEN_THREADS + 1)
            existing = await self.repository.get_thread(thread_id)
            already_active = existing and existing.get("status") == "active"
            active_count = len(active)
            if not already_active and active_count >= MAX_ACTIVE_OPEN_THREADS:
                raise OpenThreadServiceError(
                    f"You can have at most {MAX_ACTIVE_OPEN_THREADS} active open threads.",
                    409,
                )

        try:
            updated = await self.repository.update_thread(thread_id, **payload)
        except Exception as error:
            raise OpenThreadServiceError(str(error), 500) from error
        if updated is None:
            raise OpenThreadServiceError("Open thread not found.", 404)
        return updated

    async def close_thread(self, thread_id: str) -> dict[str, Any]:
        return await self.update_thread(
            thread_id,
            OpenThreadUpdateRequest(status="closed"),
        )

    async def pause_thread(self, thread_id: str) -> dict[str, Any]:
        return await self.update_thread(
            thread_id,
            OpenThreadUpdateRequest(status="paused"),
        )

    async def least_recently_used_active(self) -> Optional[dict[str, Any]]:
        active = await self.list_active_threads(limit=MAX_ACTIVE_OPEN_THREADS)
        if not active:
            return None
        return min(
            active,
            key=lambda row: str(row.get("last_mentioned_at") or row.get("updated_at") or ""),
        )


def is_active_open_thread(thread: dict[str, Any]) -> bool:
    return str(thread.get("status") or "") == "active"


def active_open_threads_for(threads: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [thread for thread in threads if is_active_open_thread(thread)]


def _payload(request: Any) -> dict[str, Any]:
    if hasattr(request, "model_dump"):
        return request.model_dump(exclude_none=True)
    return {key: value for key, value in dict(request).items() if value is not None}


def _clean_required(value: Any, field_name: str) -> str:
    cleaned = re.sub(r"\s+", " ", str(value or "")).strip()
    if not cleaned:
        raise OpenThreadServiceError(f"{field_name} is required.", 422)
    return cleaned
