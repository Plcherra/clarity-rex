"""Format SavedKnowledgeOverview for inventory prompts."""

from __future__ import annotations

from typing import Any


def format_inventory_context(overview: dict[str, Any]) -> str:
    counts = overview.get("counts") or {}
    lines = [
        "Clarity saved-knowledge inventory (same snapshot as Knows tab):",
        (
            f"items={counts.get('total', 0)} "
            f"(people={counts.get('people', 0)}, "
            f"places={counts.get('places', 0)}, "
            f"organizations={counts.get('other_entities', 0)}, "
            f"facts={counts.get('facts', 0)}, "
            f"rules={counts.get('rules', 0)}, "
            f"plans={counts.get('plans', 0)}, "
            f"commitments={counts.get('commitments', 0)})"
        ),
        "List every item below. Person cards may include multiple attributes—",
        "do not collapse them to a single fact count.",
        "",
    ]

    for person in overview.get("people") or []:
        lines.append(_format_person(person))
    for place in overview.get("places") or []:
        lines.append(_format_entity(place, label="Place"))
    for entity in overview.get("other_entities") or []:
        lines.append(_format_entity(entity, label="Organization"))
    for fact in overview.get("facts") or []:
        lines.append(f"- Fact: {_content(fact)}")
    for rule in overview.get("rules") or []:
        lines.append(f"- Rule: {_title(rule)} — {_content(rule, key='rule_text')}")
    for plan in overview.get("plans") or []:
        lines.append(f"- Plan: {_title(plan)}")
    for commitment in overview.get("commitments") or []:
        lines.append(f"- Commitment: {_title(commitment)}")

    if len(lines) <= 6:
        lines.append("- (no saved knowledge yet)")
    return "\n".join(lines)


def _format_person(person: dict[str, Any]) -> str:
    name = _title(person, key="display_name")
    metadata = person.get("metadata") if isinstance(person.get("metadata"), dict) else {}
    attributes: list[str] = []
    for key in (
        "relationship",
        "birthday",
        "workplace",
        "job",
        "location",
        "notes",
    ):
        value = metadata.get(key) or person.get(key)
        if value:
            attributes.append(f"{key}={value}")
    attrs = "; ".join(attributes) if attributes else "no structured attributes"
    return f"- Person: {name} ({attrs})"


def _format_entity(entity: dict[str, Any], *, label: str) -> str:
    name = _title(entity, key="display_name")
    return f"- {label}: {name}"


def _title(record: dict[str, Any], *, key: str = "title") -> str:
    return str(record.get(key) or record.get("display_name") or "Untitled").strip()


def _content(record: dict[str, Any], *, key: str = "content") -> str:
    return str(record.get(key) or record.get("description") or "").strip()
