"""Tests for birthday Event → person card backfill."""

from __future__ import annotations

import pytest

from app.services.person_birthday_backfill import PersonBirthdayBackfillService
from app.services.person_card_builder import PersonCardBuilder
from chat_service_fakes import FakeMemoryService


@pytest.mark.asyncio
async def test_birthday_backfill_dry_run_does_not_write():
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "mem-mom-bday",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "active": True,
            "metadata": {
                "fact_kind": "birthday",
                "memory_category": "Events",
                "entity_label": "mom",
                "normalized_date": "June 18",
            },
        }
    )
    report = await PersonBirthdayBackfillService().run(memory_service, apply=False)
    assert report.dry_run is True
    assert report.eligible == 1
    assert report.materialized == 0
    assert memory_service.entities == []
    assert len(memory_service.long_term_memory) == 1


@pytest.mark.asyncio
async def test_birthday_backfill_apply_materializes_and_deletes_flat():
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "mem-mom-bday",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "active": True,
            "metadata": {
                "fact_kind": "birthday",
                "memory_category": "Events",
                "entity_label": "mom",
                "normalized_date": "June 18",
            },
        }
    )
    report = await PersonBirthdayBackfillService().run(memory_service, apply=True)
    assert report.materialized == 1
    assert len(memory_service.entities) == 1
    person = memory_service.entities[0]
    assert person["entity_type"] == "person"
    assert person["relationship"] == "mother"
    attrs = (person.get("metadata") or {}).get("attributes") or {}
    assert attrs.get("birthday") == "June 18"
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_birthday_backfill_accepts_relationship_only_metadata():
    """Older flats may store relationship without entity_label."""
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "mem-legacy-bday",
            "memory_type": "fact",
            "content": "User's mother birthday is June 18.",
            "importance": 5,
            "active": True,
            "metadata": {
                "fact_kind": "birthday",
                "memory_category": "Events",
                "relationship": "mother",
                "normalized_date": "June 18",
            },
        }
    )
    card = PersonCardBuilder().person_card_from_memory(
        memory_service.long_term_memory[0]
    )
    assert card is not None
    assert card["relationship"] == "mother"

    report = await PersonBirthdayBackfillService().run(memory_service, apply=True)
    assert report.materialized == 1
    assert len(memory_service.entities) == 1
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_birthday_backfill_skips_non_birthday_flats():
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "mem-pref",
            "memory_type": "fact",
            "content": "User likes tea.",
            "importance": 5,
            "active": True,
            "metadata": {"fact_kind": "preference", "memory_category": "Preferences"},
        }
    )
    report = await PersonBirthdayBackfillService().run(memory_service, apply=True)
    assert report.eligible == 0
    assert report.materialized == 0
    assert memory_service.entities == []
