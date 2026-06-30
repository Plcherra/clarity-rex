#!/usr/bin/env python3
"""One-time cleanup for duplicate org/person saved knowledge rows.

Usage:
  python scripts/cleanup_user_memory_duplicates.py --user-id USER_ID [--dry-run]

Default is dry-run. Pass --apply to deactivate duplicate rows.
Does not delete chat history.
"""

from __future__ import annotations

import argparse
import asyncio
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

_ORG_SUFFIX = re.compile(
    r"\b(?:llc|inc|corp|corporation|company|co)\b",
    re.IGNORECASE,
)


def normalize_org_label(value: str) -> str:
    text = _ORG_SUFFIX.sub("", value.casefold())
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


async def run_cleanup(*, user_id: str, dry_run: bool) -> None:
    from app.services.memory_service import SupabaseMemoryService

    memory_service = SupabaseMemoryService(user_id=user_id, access_token="service")
    list_entities = getattr(memory_service, "list_entities", None)
    list_memories = getattr(memory_service, "list_long_term_memory", None)
    deactivate_entity = getattr(memory_service, "deactivate_entity", None)
    deactivate_memory = getattr(memory_service, "deactivate_long_term_memory", None)
    if not list_entities or not list_memories:
        print("Memory service missing required list/deactivate methods.")
        return

    entities = await list_entities(active=True, limit=200)
    org_entities = [
        entity
        for entity in entities
        if str(entity.get("entity_type") or "").casefold() not in {"person", "place"}
    ]
    people = [
        entity
        for entity in entities
        if str(entity.get("entity_type") or "").casefold() == "person"
    ]

    best_org_by_label: dict[str, dict] = {}
    for entity in org_entities:
        label = normalize_org_label(str(entity.get("display_name") or ""))
        if not label:
            continue
        existing = best_org_by_label.get(label)
        importance = int(entity.get("importance") or 0)
        if existing is None or importance > int(existing.get("importance") or 0):
            best_org_by_label[label] = entity

    duplicate_orgs = [
        entity
        for entity in org_entities
        if normalize_org_label(str(entity.get("display_name") or ""))
        and best_org_by_label.get(
            normalize_org_label(str(entity.get("display_name") or ""))
        )
        is not entity
    ]

    workplace_labels = set()
    for person in people:
        metadata = person.get("metadata") or {}
        if isinstance(metadata, dict):
            for key in ("workplace", "job", "employer", "company"):
                value = metadata.get(key)
                if value:
                    normalized = normalize_org_label(str(value))
                    if normalized:
                        workplace_labels.add(normalized)

    covered_org_dupes = [
        entity
        for entity in duplicate_orgs
        if normalize_org_label(str(entity.get("display_name") or ""))
        in workplace_labels
    ]

    memories = await list_memories(active=True, limit=200)
    covered_source_ids: set[str] = set()
    for entity in entities:
        metadata = entity.get("metadata") or {}
        if isinstance(metadata, dict):
            for item in metadata.get("source_memory_ids") or []:
                covered_source_ids.add(str(item))

    superseded_facts = [
        memory
        for memory in memories
        if str(memory.get("id") or "") in covered_source_ids
    ]

    print(f"Duplicate org entities to deactivate: {len(duplicate_orgs)}")
    print(f"Org entities hidden by person workplace: {len(covered_org_dupes)}")
    print(f"Flat facts covered by entity cards: {len(superseded_facts)}")

    if dry_run:
        print("Dry run only. Re-run with --apply to deactivate rows.")
        return

    for entity in duplicate_orgs:
        entity_id = str(entity.get("id") or "")
        if entity_id and deactivate_entity:
            await deactivate_entity(entity_id)
            print(f"Deactivated org entity {entity_id}")

    for memory in superseded_facts:
        memory_id = str(memory.get("id") or "")
        if memory_id and deactivate_memory:
            await deactivate_memory(memory_id)
            print(f"Deactivated flat memory {memory_id}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--user-id", required=True)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply deactivations (default is dry-run)",
    )
    args = parser.parse_args()
    asyncio.run(run_cleanup(user_id=args.user_id, dry_run=not args.apply))


if __name__ == "__main__":
    main()
