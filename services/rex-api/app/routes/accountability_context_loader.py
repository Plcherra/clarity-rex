import asyncio
from dataclasses import dataclass
from typing import Any, Optional

from app.config import get_settings
from app.services.memory_service import SupabaseMemoryService
from app.services.time_context_service import TimeContextService


ACCOUNTABILITY_CONTEXT_LIMIT = 50


@dataclass(frozen=True)
class OptionalLoadResult:
    rows: list[dict]
    diagnostic: Optional[dict[str, Any]] = None


async def load_accountability_context(
    memory_service: SupabaseMemoryService,
    message: str,
) -> dict[str, Any]:
    list_open_threads = getattr(memory_service, "list_open_threads", None)
    open_threads_task = (
        list_open_threads(status="active", limit=ACCOUNTABILITY_CONTEXT_LIMIT)
        if list_open_threads is not None
        else _empty_list()
    )
    (
        personal_rules,
        plans,
        plan_milestones,
        entities_result,
        entity_events,
        relevant_memories,
        open_threads,
    ) = await asyncio.gather(
        memory_service.list_personal_rules(
            active=True,
            status="active",
            limit=ACCOUNTABILITY_CONTEXT_LIMIT,
        ),
        memory_service.list_plans(
            active=True,
            status="active",
            limit=ACCOUNTABILITY_CONTEXT_LIMIT,
        ),
        memory_service.list_plan_milestones(
            active=True,
            limit=ACCOUNTABILITY_CONTEXT_LIMIT,
        ),
        list_entities(memory_service),
        memory_service.list_entity_events(
            active=True,
            limit=ACCOUNTABILITY_CONTEXT_LIMIT,
        ),
        memory_service.get_relevant_memories(
            query=message,
            limit=ACCOUNTABILITY_CONTEXT_LIMIT,
        ),
        open_threads_task,
    )

    diagnostics = [
        diagnostic
        for diagnostic in (entities_result.diagnostic,)
        if diagnostic is not None
    ]

    return {
        "personal_rules": personal_rules,
        "plans": plans,
        "plan_milestones": plan_milestones,
        "entities": entities_result.rows,
        "entity_events": entity_events,
        "relevant_memories": relevant_memories,
        "open_threads": open_threads if isinstance(open_threads, list) else [],
        "loader_diagnostics": diagnostics,
        "time_context": TimeContextService(
            timezone_name=get_settings().app_timezone,
        ).current_context(),
    }


async def list_entities(
    memory_service: SupabaseMemoryService,
) -> OptionalLoadResult:
    list_method = getattr(memory_service, "list_entities", None)
    if list_method is None:
        return OptionalLoadResult(
            rows=[],
            diagnostic={
                "source": "entities",
                "status": "missing_method",
                "detail": "Memory service does not expose list_entities.",
            },
        )
    try:
        return OptionalLoadResult(
            rows=await list_method(active=True, limit=ACCOUNTABILITY_CONTEXT_LIMIT)
        )
    except Exception as error:
        return OptionalLoadResult(
            rows=[],
            diagnostic=_load_error_diagnostic("entities", error),
        )


def _load_error_diagnostic(source: str, error: Exception) -> dict[str, str]:
    return {
        "source": source,
        "status": "load_failed",
        "error_class": error.__class__.__name__,
        "detail": str(error),
    }


async def _empty_list() -> list:
    return []
