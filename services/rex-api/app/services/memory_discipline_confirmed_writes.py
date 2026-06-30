from __future__ import annotations

from typing import Any

CONFIRMED_PLAN_SERVICE_CHANNEL = "confirmed_plan_service"
CHAT_CONFIRMED_PLAN_CHANNEL = "chat_confirmed_plan"
CONFIRMED_ENTITY_SERVICE_CHANNEL = "confirmed_entity_service"
CONFIRMED_RULE_SERVICE_CHANNEL = "confirmed_rule_service"
CONFIRMED_COMMITMENT_SERVICE_CHANNEL = "confirmed_commitment_service"

CONFIRMED_SERVICE_CHANNELS = frozenset(
    {
        CONFIRMED_PLAN_SERVICE_CHANNEL,
        CONFIRMED_ENTITY_SERVICE_CHANNEL,
        CONFIRMED_RULE_SERVICE_CHANNEL,
        CONFIRMED_COMMITMENT_SERVICE_CHANNEL,
    }
)

CONFIRMED_EXPLICIT_PLAN_SOURCES = frozenset(
    {
        "explicit_goal_command",
        "memory_to_goal_reclassification",
        "goals_tab",
        "knows_manual_create",
        "conversational_plan_confirmed",
    }
)


def payload_metadata(payload: dict[str, Any]) -> dict[str, Any]:
    metadata = payload.get("metadata")
    return dict(metadata) if isinstance(metadata, dict) else {}


def is_confirmed_explicit_plan_write(payload: dict[str, Any]) -> bool:
    return payload_metadata(payload).get("source") in CONFIRMED_EXPLICIT_PLAN_SOURCES


def is_confirmed_plan_service_write(payload: dict[str, Any]) -> bool:
    return (
        payload_metadata(payload).get("discipline_write_channel")
        == CONFIRMED_PLAN_SERVICE_CHANNEL
    )


def is_confirmed_service_write(payload: dict[str, Any]) -> bool:
    return (
        payload_metadata(payload).get("discipline_write_channel")
        in CONFIRMED_SERVICE_CHANNELS
    )


INTERNAL_DISCIPLINE_METADATA_KEYS = frozenset({"discipline_write_channel"})


def strip_internal_discipline_metadata(value: dict[str, Any]) -> dict[str, Any]:
    metadata = payload_metadata(value)
    for key in INTERNAL_DISCIPLINE_METADATA_KEYS:
        metadata.pop(key, None)
    if not metadata:
        cleaned = dict(value)
        cleaned.pop("metadata", None)
        return cleaned
    return {**value, "metadata": metadata}


def strip_internal_plan_metadata(payload: dict[str, Any]) -> dict[str, Any]:
    return strip_internal_discipline_metadata(payload)
