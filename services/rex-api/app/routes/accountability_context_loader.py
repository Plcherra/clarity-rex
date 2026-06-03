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
    (
        personal_rules,
        commitments,
        plans,
        plan_milestones,
        entities_result,
        entity_events,
        relevant_memories,
        pending_candidates_result,
    ) = await asyncio.gather(
        memory_service.list_personal_rules(
            active=True,
            status="active",
            limit=ACCOUNTABILITY_CONTEXT_LIMIT,
        ),
        memory_service.list_commitments(
            active=True,
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
        list_pending_memory_candidates(memory_service),
    )

    diagnostics = [
        diagnostic
        for diagnostic in (
            entities_result.diagnostic,
            pending_candidates_result.diagnostic,
        )
        if diagnostic is not None
    ]

    return {
        "personal_rules": personal_rules,
        "commitments": commitments,
        "plans": plans,
        "plan_milestones": plan_milestones,
        "entities": entities_result.rows,
        "entity_events": entity_events,
        "relevant_memories": relevant_memories,
        "pending_memory_candidates": pending_candidates_result.rows,
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


async def list_pending_memory_candidates(
    memory_service: SupabaseMemoryService,
) -> OptionalLoadResult:
    list_method = getattr(memory_service, "list_memory_candidates", None)
    if list_method is None:
        return OptionalLoadResult(
            rows=[],
            diagnostic={
                "source": "memory_candidates",
                "status": "missing_method",
                "detail": "Memory service does not expose list_memory_candidates.",
            },
        )
    try:
        rows = await list_method(status="pending", limit=ACCOUNTABILITY_CONTEXT_LIMIT)
        return OptionalLoadResult(rows=[with_candidate_preview(row) for row in rows])
    except TypeError:
        return await _list_candidates_without_status(list_method)
    except Exception as error:
        return OptionalLoadResult(
            rows=[],
            diagnostic=_load_error_diagnostic("memory_candidates", error),
        )


async def _list_candidates_without_status(list_method) -> OptionalLoadResult:
    try:
        rows = await list_method(limit=ACCOUNTABILITY_CONTEXT_LIMIT)
    except Exception as error:
        return OptionalLoadResult(
            rows=[],
            diagnostic=_load_error_diagnostic("memory_candidates", error),
        )
    return OptionalLoadResult(
        rows=[with_candidate_preview(row) for row in rows],
        diagnostic={
            "source": "memory_candidates",
            "status": "fallback_without_status",
            "detail": "Loaded candidates without status filter.",
        },
    )


def with_candidate_preview(row: dict) -> dict:
    if row.get("preview"):
        return row
    payload = row.get("payload") if isinstance(row.get("payload"), dict) else {}
    candidate_type = str(row.get("candidate_type") or "memory_update")
    title = ""
    for key in (
        "title",
        "display_name",
        "content",
        "rule_text",
        "commitment_text",
        "new_value",
    ):
        value = payload.get(key)
        if value:
            title = " ".join(str(value).split())
            break
    preview = f"{candidate_type}: {title}" if title else f"{candidate_type}: pending"
    return {**row, "preview": preview}


def _load_error_diagnostic(source: str, error: Exception) -> dict[str, str]:
    return {
        "source": source,
        "status": "load_failed",
        "error_class": error.__class__.__name__,
        "detail": str(error),
    }
