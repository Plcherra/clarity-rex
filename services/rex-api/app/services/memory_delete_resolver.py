"""Unified delete parsing and resolution via TABLE_SPECS + Knows reference matching."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Optional

from app.services.memory_correction_text import clean_text, trim_removal_target, trim_text
from app.services.memory_correction_record_rules import (
    dedupe_affected,
    record_contains,
    record_contains_all_terms,
    record_title,
    removal_match_terms,
    spec_for_table,
)
from app.services.memory_correction_types import (
    TABLE_SPECS,
    CorrectionAffectedRecord,
    TableSpec,
)
from app.services.memory_delete_reference import extract_reference_delete_target
from app.services.memory_reference_resolver import (
    KnowsReferenceMatch,
    MemoryReferenceResolver,
)

GOAL_DELETE_SCOPE = ("plans", "plan_milestones")
ACCOUNTABILITY_DELETE_SCOPE = ("plans", "plan_milestones")
OPEN_THREAD_DELETE_SCOPE = ("open_threads",)
MEMORY_DELETE_SCOPE = (
    "long_term_memory",
    "entities",
    "entity_events",
    "personal_rules",
)

_VAGUE_KIND_ONLY = frozenset(
    {
        "goal",
        "goals",
        "memory",
        "memories",
        "plan",
        "plans",
        "task",
        "tasks",
    }
)


@dataclass(frozen=True)
class ParsedDeleteRequest:
    reference: str
    scope_tables: tuple[str, ...] = ()
    is_vague: bool = False


def is_vague_delete_reference(reference: str) -> bool:
    normalized = re.sub(r"[^a-z0-9]+", " ", str(reference or "").lower()).strip()
    if not normalized:
        return True
    if normalized in _VAGUE_KIND_ONLY:
        return True
    tokens = normalized.split()
    return len(tokens) <= 3 and "memory" in tokens


def parse_delete_request(text: str) -> Optional[ParsedDeleteRequest]:
    cleaned = clean_text(text)
    if not cleaned:
        return None

    goal_delete = re.search(
        r"\b(?:delete|remove|archive)\s+(?:the\s+)?(?P<kind>goal)s?\b"
        r"(?:\s+(?:we\s+have(?:\s+saved)?|(?:that\s+)?(?:i\s+)?saved))?"
        r"(?:\s+['\"](?P<quoted>.+?)['\"])?"
        r"(?:\s+(?P<title>.+))?$",
        cleaned,
        flags=re.IGNORECASE,
    )
    if goal_delete:
        quoted = goal_delete.group("quoted")
        title = goal_delete.group("title")
        kind = str(goal_delete.group("kind") or "goal").strip().lower()
        scope = GOAL_DELETE_SCOPE
        if quoted:
            reference = trim_removal_target(quoted)
            return ParsedDeleteRequest(
                reference=reference,
                scope_tables=scope,
                is_vague=is_vague_delete_reference(reference),
            )
        if title:
            reference = trim_removal_target(title)
            return ParsedDeleteRequest(
                reference=reference,
                scope_tables=scope,
                is_vague=is_vague_delete_reference(reference),
            )
        return ParsedDeleteRequest(
            reference=kind,
            scope_tables=scope,
            is_vague=True,
        )

    thread_delete = re.search(
        r"\b(?:delete|remove|close)\s+(?:the\s+)?(?P<kind>open\s+thread)s?\b"
        r"(?:\s+['\"](?P<quoted>.+?)['\"])?",
        cleaned,
        flags=re.IGNORECASE,
    )
    if thread_delete:
        quoted = thread_delete.group("quoted")
        if quoted:
            reference = trim_removal_target(quoted)
            return ParsedDeleteRequest(
                reference=reference,
                scope_tables=OPEN_THREAD_DELETE_SCOPE,
                is_vague=is_vague_delete_reference(reference),
            )
        return ParsedDeleteRequest(
            reference="open thread",
            scope_tables=OPEN_THREAD_DELETE_SCOPE,
            is_vague=True,
        )

    removal = re.search(
        (
            r"\b(?:delete|remove|archive|drop|forget|erase|clear)\s+"
            r"(?:any\s+)?"
            r"(?:mention|mentions|memory|memories|record|records)\s*"
            r"(?:of|about|for)?\s+(.+)$"
        ),
        cleaned,
        flags=re.IGNORECASE,
    )
    if removal is None:
        removal = re.search(
            r"\b(?:delete|remove|archive|drop|forget|erase|clear)\s+(.+)$",
            cleaned,
            flags=re.IGNORECASE,
        )
    if removal is None:
        removal = re.search(
            r"\bget\s+rid\s+of\s+(.+)$",
            cleaned,
            flags=re.IGNORECASE,
        )
    if removal:
        reference = trim_removal_target(removal.group(1))
        return ParsedDeleteRequest(
            reference=reference,
            scope_tables=(),
            is_vague=is_vague_delete_reference(reference),
        )

    reference_target = extract_reference_delete_target(cleaned)
    if reference_target:
        reference = trim_removal_target(reference_target)
        return ParsedDeleteRequest(
            reference=reference,
            scope_tables=(),
            is_vague=is_vague_delete_reference(reference),
        )

    return None


class MemoryDeleteResolver:
    def __init__(
        self,
        memory_service: Any,
        *,
        reference_resolver: Optional[MemoryReferenceResolver] = None,
        scan_limit: int = 250,
    ) -> None:
        self.memory_service = memory_service
        self.reference_resolver = reference_resolver or MemoryReferenceResolver(
            memory_service
        )
        self.scan_limit = scan_limit

    async def resolve(
        self,
        request: ParsedDeleteRequest | str,
        *,
        scope_tables: tuple[str, ...] = (),
        is_vague: bool = False,
    ) -> list[CorrectionAffectedRecord]:
        parsed = (
            request
            if isinstance(request, ParsedDeleteRequest)
            else ParsedDeleteRequest(
                reference=str(request),
                scope_tables=scope_tables,
                is_vague=is_vague,
            )
        )
        if parsed.is_vague or is_vague_delete_reference(parsed.reference):
            return []

        specs = self._scoped_specs(parsed.scope_tables)
        exact_matches: list[CorrectionAffectedRecord] = []
        fuzzy_matches: list[CorrectionAffectedRecord] = []
        terms = removal_match_terms(parsed.reference)
        for spec in specs:
            records = await self._safe_list(spec)
            for record in records:
                if record_contains(record, spec, parsed.reference):
                    exact_matches.append(self._affected_preview(spec, record))
                elif terms and record_contains_all_terms(record, spec, terms):
                    fuzzy_matches.append(self._affected_preview(spec, record))

        if exact_matches or fuzzy_matches:
            return dedupe_affected(exact_matches or fuzzy_matches)

        knows_matches = await self.reference_resolver.resolve_knows_delete_reference(
            parsed.reference,
            limit=self.scan_limit,
        )
        if parsed.scope_tables:
            allowed = set(parsed.scope_tables)
            knows_matches = [
                match for match in knows_matches if match.table in allowed
            ]
        return dedupe_affected(
            [
                self._affected_preview_for_knows_match(match)
                for match in knows_matches
            ]
        )

    def _scoped_specs(self, scope_tables: tuple[str, ...]) -> list[TableSpec]:
        if not scope_tables:
            return list(TABLE_SPECS)
        return [spec_for_table(table) for table in scope_tables]

    async def _safe_list(self, spec: TableSpec) -> list[dict]:
        method = getattr(self.memory_service, spec.list_method, None)
        if method is None:
            return []
        try:
            rows = await method(active=True, limit=self.scan_limit)
        except TypeError:
            try:
                rows = await method(limit=self.scan_limit)
            except Exception:
                return []
        except Exception:
            return []
        return rows if isinstance(rows, list) else []

    def _affected_preview(
        self,
        spec: TableSpec,
        record: dict[str, Any],
    ) -> CorrectionAffectedRecord:
        return CorrectionAffectedRecord(
            table=spec.table,
            id=str(record["id"]),
            action="would_archive",
            title=record_title(record),
            previous=record,
        )

    def _affected_preview_for_knows_match(
        self,
        match: KnowsReferenceMatch,
    ) -> CorrectionAffectedRecord:
        previous = dict(match.record)
        if match.attribute_key:
            previous["__delete_resolution"] = {
                "action": match.action,
                "attribute_key": match.attribute_key,
                "attribute_value": match.attribute_value,
                "source_memory_ids": list(match.source_memory_ids),
            }
        return CorrectionAffectedRecord(
            table=match.table,
            id=match.id,
            action=match.action,
            title=match.title,
            previous=previous,
        )
