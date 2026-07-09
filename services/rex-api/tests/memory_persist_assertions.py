"""Helpers for Finish Memory System assertions in chat memory flow tests."""

from __future__ import annotations


def assert_person_card_covers(
    memory_service,
    *,
    relationship: str | None = None,
    display_name_contains: str | None = None,
    attribute_contains: dict[str, str] | None = None,
    flat_content_gone: str | None = None,
) -> dict:
    """Assert a person card exists and optional covered flat content is gone."""
    entities = [
        entity
        for entity in memory_service.entities
        if entity.get("entity_type") == "person" and entity.get("active", True)
    ]
    assert entities, "expected at least one active person card"

    matched = None
    for entity in entities:
        if relationship and str(entity.get("relationship") or "").casefold() != relationship.casefold():
            continue
        if display_name_contains and display_name_contains.casefold() not in str(
            entity.get("display_name") or ""
        ).casefold():
            continue
        if attribute_contains:
            metadata = entity.get("metadata") if isinstance(entity.get("metadata"), dict) else {}
            attrs = metadata.get("attributes") if isinstance(metadata.get("attributes"), dict) else {}
            if any(
                value.casefold() not in str(attrs.get(key) or "").casefold()
                for key, value in attribute_contains.items()
            ):
                continue
        matched = entity
        break

    assert matched is not None, (
        f"no matching person card for relationship={relationship!r} "
        f"display_name_contains={display_name_contains!r} "
        f"attribute_contains={attribute_contains!r}; entities={entities}"
    )

    if flat_content_gone:
        assert all(
            flat_content_gone.casefold() not in str(memory.get("content") or "").casefold()
            for memory in memory_service.long_term_memory
        ), memory_service.long_term_memory

    return matched
