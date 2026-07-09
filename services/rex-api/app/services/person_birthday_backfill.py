"""Backfill orphan birthday Event flats into person cards (no new chat write)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

from app.services.person_card_builder import PersonCardBuilder
from app.services.person_memory_materializer import PersonMemoryMaterializer


@dataclass
class PersonBirthdayBackfillReport:
    dry_run: bool
    scanned: int = 0
    eligible: int = 0
    materialized: int = 0
    skipped: int = 0
    candidates: list[dict[str, Any]] = field(default_factory=list)
    errors: list[dict[str, str]] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "dry_run": self.dry_run,
            "scanned": self.scanned,
            "eligible": self.eligible,
            "materialized": self.materialized,
            "skipped": self.skipped,
            "candidates": self.candidates,
            "errors": self.errors,
        }


class PersonBirthdayBackfillService:
    """Promote active birthday flats into Knows person cards.

    Reuses PersonMemoryMaterializer + consolidator — no second write pipeline.
    """

    def __init__(
        self,
        *,
        materializer: Optional[PersonMemoryMaterializer] = None,
        builder: Optional[PersonCardBuilder] = None,
    ) -> None:
        self._builder = builder or PersonCardBuilder()
        self._materializer = materializer or PersonMemoryMaterializer()

    async def run(
        self,
        memory_service: Any,
        *,
        apply: bool = False,
        limit: int = 250,
    ) -> PersonBirthdayBackfillReport:
        report = PersonBirthdayBackfillReport(dry_run=not apply)
        list_memory = getattr(memory_service, "list_long_term_memory", None)
        if list_memory is None:
            report.errors.append(
                {"error": "memory_service_missing_list_long_term_memory"}
            )
            return report

        try:
            memories = await list_memory(limit=limit, memory_type="fact", active=True)
        except TypeError:
            try:
                memories = await list_memory(limit=limit, active=True)
            except Exception as exc:
                report.errors.append({"error": type(exc).__name__, "detail": str(exc)[:200]})
                return report
        except Exception as exc:
            report.errors.append({"error": type(exc).__name__, "detail": str(exc)[:200]})
            return report

        for memory in memories:
            if not isinstance(memory, dict):
                continue
            report.scanned += 1
            if not self._is_birthday_flat(memory):
                report.skipped += 1
                continue
            card = self._builder.person_card_from_memory(memory)
            if card is None:
                report.skipped += 1
                continue
            report.eligible += 1
            candidate = {
                "memory_id": memory.get("id"),
                "content": str(memory.get("content") or "")[:120],
                "display_name": card.get("display_name"),
                "relationship": card.get("relationship"),
                "birthday": (card.get("metadata") or {})
                .get("attributes", {})
                .get("birthday"),
            }
            report.candidates.append(candidate)
            if not apply:
                continue
            try:
                await self._materializer.materialize_from_memory(memory_service, memory)
                report.materialized += 1
            except Exception as exc:
                report.errors.append(
                    {
                        "memory_id": str(memory.get("id") or ""),
                        "error": type(exc).__name__,
                        "detail": str(exc)[:200],
                    }
                )
        return report

    def _is_birthday_flat(self, memory: dict[str, Any]) -> bool:
        metadata = memory.get("metadata")
        if not isinstance(metadata, dict):
            metadata = {}
        fact_kind = str(metadata.get("fact_kind") or "").casefold()
        if fact_kind == "birthday":
            return True
        category = str(metadata.get("memory_category") or "").casefold()
        content = str(memory.get("content") or "").casefold()
        return category == "events" and "birthday" in content
