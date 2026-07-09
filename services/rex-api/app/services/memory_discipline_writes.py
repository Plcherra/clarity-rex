from __future__ import annotations

from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any, Optional

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineCandidate,
    MemoryRelatedRecord,
    MemoryRecordKind,
)
from app.services.memory_discipline_decision_factory import create_action_for_kind
from app.services.memory_discipline_list_loader import DisciplineContextLoadError
from app.services.memory_discipline_service import (
    DUPLICATE_SCORE_THRESHOLD,
    MemoryDisciplineService,
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


@dataclass(frozen=True)
class LongTermMemoryDuplicateMatch:
    record_id: str
    score: float
    previous_content: str | None
    record: dict[str, Any]


async def find_long_term_memory_duplicate(
    discipline: MemoryDisciplineService,
    *,
    payload: dict[str, Any],
) -> LongTermMemoryDuplicateMatch | None:
    """Return the top LTM duplicate at/above threshold, or None if clear to create.

    Do not attach conversation/message provenance to the similarity candidate —
    same_source would otherwise treat every prior fact in the chat as a duplicate.
    """
    candidate_payload = {
        "memory_type": payload.get("memory_type") or "fact",
        "content": str(payload.get("content") or payload.get("body") or ""),
        "importance": int(payload.get("importance") or 3),
        "metadata": dict(payload.get("metadata") or {}),
    }
    # Confirmed-channel metadata must not bypass duplicate detection.
    candidate_payload["metadata"].pop("discipline_write_channel", None)
    candidate = MemoryDisciplineCandidate(
        kind=MemoryRecordKind.LONG_TERM_MEMORY,
        payload=candidate_payload,
    )
    try:
        context = await discipline.gather_context(candidate)
    except DisciplineContextLoadError as exc:
        raise MemoryWriteError(
            "Could not check for related saved items just now. Please try again.",
            503,
        ) from exc

    duplicate = _top_ltm_duplicate(context.related_long_term_memories)
    if duplicate is None:
        return None
    previous = str(
        duplicate.record.get("content") or duplicate.title or ""
    ).strip() or None
    return LongTermMemoryDuplicateMatch(
        record_id=duplicate.id,
        score=duplicate.score,
        previous_content=previous,
        record=dict(duplicate.record),
    )


async def execute_disciplined_create(
    discipline: MemoryDisciplineService,
    *,
    kind: MemoryRecordKind,
    payload: dict[str, Any],
    create_fn: Callable[[dict[str, Any]], Awaitable[dict[str, Any]]],
) -> dict[str, Any]:
    candidate = MemoryDisciplineCandidate(kind=kind, payload=payload)
    try:
        decision = await discipline.decide(candidate)
    except DisciplineContextLoadError as exc:
        raise MemoryWriteError(
            "Could not check for related saved items just now. Please try again.",
            503,
        ) from exc

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

    create_action = create_action_for_kind(kind)
    if create_action is not None and decision.action == create_action:
        record = await create_fn(payload)
        return _require_confirmed_record(record)

    try:
        result = await discipline.apply_decision(decision)
    except DisciplineContextLoadError as exc:
        raise MemoryWriteError(
            "Could not check for related saved items just now. Please try again.",
            503,
        ) from exc
    if not result.get("applied"):
        raise MemoryWriteError(
            str(result.get("reason") or "Memory write was not applied."),
            409,
            related_records=result.get("related_records") or [],
        )
    return _require_confirmed_record(result.get("record"))


async def apply_disciplined_long_term_memory(
    discipline: MemoryDisciplineService,
    *,
    payload: dict[str, Any],
    conversation_id: str,
    source_message_id: str | None,
    create_fn: Callable[[dict[str, Any]], Awaitable[dict[str, Any]]],
) -> dict[str, Any]:
    """Apply-time LTM write with duplicate merge; returns applied/merged shape."""
    duplicate = await find_long_term_memory_duplicate(
        discipline,
        payload=payload,
    )
    update_memory = getattr(discipline.memory_service, "update_long_term_memory", None)
    content = str(payload.get("content") or payload.get("body") or "")
    memory_type = payload.get("memory_type") or "fact"
    importance = int(payload.get("importance") or 3)
    base_metadata = dict(payload.get("metadata") or {})
    base_metadata.pop("discipline_write_channel", None)

    if duplicate is not None and update_memory is not None:
        metadata = {
            **(duplicate.record.get("metadata") or {}),
            **base_metadata,
            "discipline_updated": True,
            "source": "durable_write_confirmed",
        }
        updated = await update_memory(
            duplicate.record_id,
            memory_type=memory_type,
            content=content,
            importance=importance,
            active=True,
            metadata=metadata,
        )
        return {
            "applied": True,
            "record": _require_confirmed_record(updated),
            "merged": True,
        }

    write_metadata = dict(base_metadata)
    write_metadata.setdefault("source", "durable_write_confirmed")
    record = await create_fn(
        {
            "memory_type": memory_type,
            "content": content,
            "importance": importance,
            "metadata": write_metadata,
            "source_conversation_id": conversation_id,
            "source_message_id": source_message_id,
        }
    )
    return {
        "applied": True,
        "record": _require_confirmed_record(record),
        "merged": False,
    }


async def _execute_long_term_memory_write(
    discipline: MemoryDisciplineService,
    candidate: MemoryDisciplineCandidate,
    payload: dict[str, Any],
    create_fn: Callable[[dict[str, Any]], Awaitable[dict[str, Any]]],
) -> dict[str, Any]:
    try:
        context = await discipline.gather_context(candidate)
    except DisciplineContextLoadError as exc:
        raise MemoryWriteError(
            "Could not check for related saved items just now. Please try again.",
            503,
        ) from exc
    duplicate = _top_ltm_duplicate(context.related_long_term_memories)
    update_memory = getattr(discipline.memory_service, "update_long_term_memory", None)

    if duplicate is not None and update_memory is not None:
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


def _top_ltm_duplicate(
    related: list[MemoryRelatedRecord],
) -> MemoryRelatedRecord | None:
    if not related:
        return None
    top = related[0]
    if top.score < DUPLICATE_SCORE_THRESHOLD:
        return None
    return top


def _require_confirmed_record(record: Any) -> dict[str, Any]:
    if not isinstance(record, dict) or not record.get("id"):
        raise MemoryWriteError("Backend did not confirm the memory write.", 500)
    return record
