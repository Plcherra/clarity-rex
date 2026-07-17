"""Load active open thread titles for thin base-turn prompts."""

from __future__ import annotations

from typing import Any

from app.services.open_thread_service import OpenThreadService
from app.services.prompt_open_threads_context import format_open_threads_context


async def load_open_threads_context(
    memory_service: Any,
    message: str,
    *,
    open_thread_service: OpenThreadService | None = None,
) -> dict[str, Any]:
    _ = message
    service = open_thread_service or OpenThreadService(memory_service)
    try:
        threads = await service.list_active_threads()
    except Exception:
        return {"open_threads_status": "degraded"}

    formatted = format_open_threads_context(threads)
    if not formatted:
        return {"open_threads": [], "open_threads_status": "empty"}

    return {
        "open_threads": threads,
        "open_threads_context": formatted,
        "open_threads_status": "loaded",
    }
