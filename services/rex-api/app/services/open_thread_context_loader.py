"""Load active open threads for Rex prompt context on substantive turns."""

from __future__ import annotations

from typing import Any


async def load_open_threads_context(
    memory_service: Any,
    message: str,
    *,
    open_thread_service=None,
) -> dict[str, Any]:
    _ = (memory_service, message, open_thread_service)
    return {}
