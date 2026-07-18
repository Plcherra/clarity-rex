"""Route gated Grok actions to body handlers (plan 05 Phase C)."""

from __future__ import annotations

from typing import Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import AutoSuggestionsGateResult
from app.services.capabilities.open_thread_capability import (
    handle_open_thread_action,
    is_open_thread_action,
)


async def dispatch_allowed_actions(
    *,
    gate: AutoSuggestionsGateResult,
    settings: AssistantProposalSettings,
    durable_write_service,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]] = None,
) -> Optional[dict]:
    """Run the first allowed open-thread action. Returns a full turn dict or None."""
    for action in gate.allowed_soft_actions:
        if not is_open_thread_action(action):
            continue
        result = await handle_open_thread_action(
            action,
            durable_write_service=durable_write_service,
            settings=settings,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_messages,
        )
        if result is not None:
            return result
    return None
