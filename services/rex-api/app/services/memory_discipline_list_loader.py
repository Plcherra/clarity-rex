"""Shared repository list helpers for memory discipline (fail-closed)."""

from __future__ import annotations

from typing import Any

from app.services.memory_failure_reporting import log_memory_failure


class DisciplineContextLoadError(Exception):
    """Raised when an active-record list required for duplicate checks fails."""

    def __init__(self, operation: str, cause: BaseException) -> None:
        self.operation = operation
        self.cause = cause
        super().__init__(f"discipline_context_unavailable:{operation}")


async def safe_discipline_list(
    memory_service: Any,
    method_name: str,
    *,
    scan_limit: int = 100,
    fail_closed: bool = True,
    **kwargs: Any,
) -> list[dict]:
    """Load an active-record list for discipline.

    Missing methods return []. TypeError falls back to a narrow signature for
    test fakes. Real exceptions fail closed (raise) when fail_closed=True so
    callers never treat a load failure as "no related records".
    """
    method = getattr(memory_service, method_name, None)
    if method is None:
        return []
    try:
        return await method(**kwargs)
    except TypeError:
        return await method(limit=kwargs.get("limit", scan_limit))
    except Exception as exc:
        log_memory_failure(
            "discipline_list_failed",
            operation=method_name,
            error=exc,
        )
        if fail_closed:
            raise DisciplineContextLoadError(method_name, exc) from exc
        return []
