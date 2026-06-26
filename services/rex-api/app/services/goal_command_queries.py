"""Read-only inventory turns for goals and commitments."""

from __future__ import annotations

from typing import Any, Optional

from app.services.goal_command_parsing import (
    goals_inventory_scope,
    is_goals_inventory_query,
)
from app.services.goal_command_results import read_only_turn_result


async def try_list_goals_and_commitments(
    message: str,
    *,
    conversation_id: str,
    user_message: dict,
    accountability_query_service: Any,
    memory_service: Any,
) -> Optional[dict]:
    if not is_goals_inventory_query(message):
        return None

    scope = goals_inventory_scope(message)
    inventory = await accountability_query_service.load_inventory(
        scope=scope,
    )
    response = accountability_query_service.format_inventory_response(
        plans=inventory.active_plans,
        commitments=inventory.open_commitments,
        scope=scope,
    )
    return await read_only_turn_result(
        memory_service,
        conversation_id=conversation_id,
        user_message=user_message,
        response=response,
    )
