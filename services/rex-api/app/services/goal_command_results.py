"""Turn result builders for direct goal commands."""

from __future__ import annotations

from typing import Any, Optional

from app.services.goal_command_types import GoalCommand


def memory_change_summary(
    *,
    kind: str,
    record_type: str,
    record: dict,
    title: str,
    extra_records: Optional[list[dict]] = None,
) -> dict:
    source = "explicit_goal_command"
    records = [
        {
            "kind": kind,
            "type": record_type,
            "action": "direct_saved",
            "id": record.get("id"),
            "title": title,
            "metadata": {"source": source},
        }
    ]
    if extra_records:
        records.extend(extra_records)
    archived_count = sum(
        1 for item in records if item.get("action") == "archived"
    )
    return {
        "created": 1,
        "updated": 0,
        "archived": archived_count,
        "merged": 0,
        "skipped": 0,
        "confirmation_required": 0,
        "records": records,
    }


def failed_memory_change_summary(
    *,
    kind: str,
    record_type: str,
    title: str,
) -> dict:
    return {
        "created": 0,
        "updated": 0,
        "archived": 0,
        "merged": 0,
        "skipped": 1,
        "confirmation_required": 0,
        "records": [
            {
                "kind": kind,
                "type": record_type,
                "action": "save_failed",
                "title": title,
                "metadata": {"source": "explicit_command", "degraded": True},
            }
        ],
    }


async def read_only_turn_result(
    memory_service: Any,
    *,
    conversation_id: str,
    user_message: dict,
    response: str,
) -> dict:
    assistant_message = await memory_service.save_message(
        conversation_id,
        "assistant",
        response,
    )
    return {
        "conversation_id": conversation_id,
        "response": response,
        "user_message": user_message,
        "assistant_message": assistant_message,
        "memory_correction": None,
        "memory_changes": {},
        "messages": await memory_service.get_recent_messages(
            conversation_id,
            limit=20,
        ),
    }


async def clarification_turn_result(
    memory_service: Any,
    *,
    conversation_id: str,
    user_message: dict,
    response: str,
    memory_changes: Optional[dict] = None,
) -> dict:
    assistant_message = await memory_service.save_message(
        conversation_id,
        "assistant",
        response,
    )
    resolved_memory_changes = memory_changes or {
        "created": 0,
        "updated": 0,
        "archived": 0,
        "merged": 0,
        "skipped": 0,
        "confirmation_required": 0,
        "records": [],
    }
    return {
        "conversation_id": conversation_id,
        "response": response,
        "user_message": user_message,
        "assistant_message": assistant_message,
        "memory_correction": None,
        "memory_changes": resolved_memory_changes,
        "messages": await memory_service.get_recent_messages(
            conversation_id,
            limit=20,
        ),
    }


async def command_turn_result(
    memory_service: Any,
    *,
    conversation_id: str,
    user_message: dict,
    response: str,
    kind: str,
    record_type: str,
    record: dict,
    title: str,
    extra_records: Optional[list[dict]] = None,
) -> dict:
    assistant_message = await memory_service.save_message(
        conversation_id,
        "assistant",
        response,
    )
    memory_changes = memory_change_summary(
        kind=kind,
        record_type=record_type,
        record=record,
        title=title,
        extra_records=extra_records,
    )
    return {
        "conversation_id": conversation_id,
        "response": response,
        "user_message": user_message,
        "assistant_message": assistant_message,
        "memory_correction": None,
        "memory_changes": memory_changes,
        "messages": await memory_service.get_recent_messages(
            conversation_id,
            limit=20,
        ),
    }


async def failed_command_turn_result(
    memory_service: Any,
    *,
    conversation_id: str,
    user_message: dict,
    response: str,
    kind: str,
    record_type: str,
    title: str,
) -> dict:
    assistant_message = await memory_service.save_message(
        conversation_id,
        "assistant",
        response,
    )
    return {
        "conversation_id": conversation_id,
        "response": response,
        "user_message": user_message,
        "assistant_message": assistant_message,
        "memory_correction": None,
        "memory_changes": failed_memory_change_summary(
            kind=kind,
            record_type=record_type,
            title=title,
        ),
        "messages": await memory_service.get_recent_messages(
            conversation_id,
            limit=20,
        ),
    }


async def multi_goal_turn_result(
    memory_service: Any,
    *,
    conversation_id: str,
    user_message: dict,
    response: str,
    commands: list[GoalCommand],
    records: list[dict],
    extra_records: Optional[list[dict]] = None,
) -> dict:
    assistant_message = await memory_service.save_message(
        conversation_id,
        "assistant",
        response,
    )
    record_summaries = [
        {
            "kind": "plan",
            "type": command.record_type,
            "action": "direct_saved",
            "id": record.get("id"),
            "title": command.title,
            "metadata": {"source": "explicit_goal_command"},
        }
        for command, record in zip(commands, records, strict=True)
    ]
    if extra_records:
        record_summaries.extend(extra_records)
    archived_count = sum(
        1 for item in record_summaries if item.get("action") == "archived"
    )
    return {
        "conversation_id": conversation_id,
        "response": response,
        "user_message": user_message,
        "assistant_message": assistant_message,
        "memory_correction": None,
        "memory_changes": {
            "created": len(records),
            "updated": 0,
            "archived": archived_count,
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 0,
            "records": record_summaries,
        },
        "messages": await memory_service.get_recent_messages(
            conversation_id,
            limit=20,
        ),
    }
