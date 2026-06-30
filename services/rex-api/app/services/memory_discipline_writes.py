from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import Any

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineCandidate,
    MemoryRecordKind,
)
from app.services.memory_discipline_service import (
    DUPLICATE_SCORE_THRESHOLD,
    MemoryDisciplineService,
    _create_action_for_kind,
)


class MemoryWriteError(Exception):
    def __init__(
        self,
        detail: str,
        status_code: int = 400,
        *,
        requires_confirmation: bool = False,
        related_records: list[dict[str, Any]] | None = None,
    ) -> None:
        self.detail = detail
        self.status_code = status_code
        self.requires_confirmation = requires_confirmation
        self.related_records = related_records or []
        super().__init__(detail)


async def execute_disciplined_create(
    discipline: MemoryDisciplineService,
    *,
    kind: MemoryRecordKind,
    payload: dict[str, Any],
    create_fn: Callable[[dict[str, Any]], Awaitable[dict[str, Any]]],
) -> dict[str, Any]:
    candidate = MemoryDisciplineCandidate(kind=kind, payload=payload)
    decision = await discipline.decide(candidate)

    if decision.action == MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE:
        raise MemoryWriteError(decision.reason, 422)

    if kind == MemoryRecordKind.LONG_TERM_MEMORY:
        return await _execute_long_term_memory_write(
            discipline,
            candidate,
            payload,
            create_fn,
        )

    if decision.requires_confirmation:
        raise MemoryWriteError(
            decision.reason,
            409,
            requires_confirmation=True,
            related_records=[
                record.model_dump() for record in decision.related_records
            ],
        )

    create_action = _create_action_for_kind(kind)
    if create_action is not None and decision.action == create_action:
        record = await create_fn(payload)
        return _require_confirmed_record(record)

    result = await discipline.apply_decision(decision)
    if not result.get("applied"):
        raise MemoryWriteError(
            str(result.get("reason") or "Memory write was not applied."),
            409,
            related_records=result.get("related_records") or [],
        )
    return _require_confirmed_record(result.get("record"))


async def _execute_long_term_memory_write(
    discipline: MemoryDisciplineService,
    candidate: MemoryDisciplineCandidate,
    payload: dict[str, Any],
    create_fn: Callable[[dict[str, Any]], Awaitable[dict[str, Any]]],
) -> dict[str, Any]:
    context = await discipline.gather_context(candidate)
    duplicate = context.related_long_term_memories[0] if context.related_long_term_memories else None
    update_memory = getattr(discipline.memory_service, "update_long_term_memory", None)

    if (
        duplicate is not None
        and duplicate.score >= DUPLICATE_SCORE_THRESHOLD
        and update_memory is not None
    ):
        metadata = {
            **(duplicate.record.get("metadata") or {}),
            **(payload.get("metadata") or {}),
            "discipline_updated": True,
        }
        updated = await update_memory(
            duplicate.id,
            memory_type=payload.get("memory_type"),
            content=payload.get("content"),
            importance=payload.get("importance"),
            metadata=metadata,
        )
        return _require_confirmed_record(updated)

    return _require_confirmed_record(await create_fn(payload))


def _require_confirmed_record(record: Any) -> dict[str, Any]:
    if not isinstance(record, dict) or not record.get("id"):
        raise MemoryWriteError("Backend did not confirm the memory write.", 500)
    return record
