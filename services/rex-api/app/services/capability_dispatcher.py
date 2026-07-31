"""Route gated Grok actions to body handlers (plan 05)."""

from __future__ import annotations

from typing import Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import AutoSuggestionsGateResult
from app.services.capabilities.finance_capability import (
    collect_finance_proposals,
)
from app.services.capabilities.finance_mutate_outcome import FinanceMutateOutcome
from app.services.capabilities.goal_capability import (
    handle_goal_action,
    is_goal_action,
)
from app.services.capabilities.memory_capability import (
    handle_memory_action,
    is_memory_action,
)
from app.services.capabilities.milestone_capability import (
    handle_milestone_action,
    is_milestone_action,
)
from app.services.capabilities.open_thread_capability import (
    handle_delete_open_thread_action,
    handle_open_thread_action,
    is_delete_open_thread_action,
    is_open_thread_action,
)


def dispatch_finance_proposals(
    *,
    gate: AutoSuggestionsGateResult,
    settings: AssistantProposalSettings,
    clarity_action_parser,
    financial_context: Optional[dict] = None,
) -> FinanceMutateOutcome:
    """Finance changes ride the clarity-actions confirm path, not durable write."""
    return collect_finance_proposals(
        (*gate.allowed_soft_actions, *gate.passthrough_actions),
        settings=settings,
        clarity_action_parser=clarity_action_parser,
        financial_context=financial_context,
    )


async def dispatch_allowed_actions(
    *,
    gate: AutoSuggestionsGateResult,
    settings: AssistantProposalSettings,
    durable_write_service,
    conversation_id: str,
    user_message: dict,
    conversation_messages: Optional[list[dict]] = None,
    assistant_reply: str = "",
) -> Optional[dict]:
    """Run the first allowed body action. Returns a full turn dict or None."""
    # Catalog no longer lists delete_open_thread; if Grok still emits it, speak
    # honestly instead of silently dropping.
    for action in (*gate.allowed_soft_actions, *gate.passthrough_actions):
        if is_delete_open_thread_action(action):
            return await handle_delete_open_thread_action(
                durable_write_service=durable_write_service,
                conversation_id=conversation_id,
                user_message=user_message,
            )

    candidates = (*gate.allowed_soft_actions, *gate.passthrough_actions)
    for action in candidates:
        if is_open_thread_action(action):
            result = await handle_open_thread_action(
                action,
                durable_write_service=durable_write_service,
                settings=settings,
                conversation_id=conversation_id,
                user_message=user_message,
                conversation_messages=conversation_messages,
                assistant_reply=assistant_reply,
            )
            if result is not None:
                return result
        if is_memory_action(action):
            result = await handle_memory_action(
                action,
                durable_write_service=durable_write_service,
                settings=settings,
                conversation_id=conversation_id,
                user_message=user_message,
                conversation_messages=conversation_messages,
                assistant_reply=assistant_reply,
            )
            if result is not None:
                return result
        if is_goal_action(action):
            result = await handle_goal_action(
                action,
                durable_write_service=durable_write_service,
                settings=settings,
                conversation_id=conversation_id,
                user_message=user_message,
                conversation_messages=conversation_messages,
                assistant_reply=assistant_reply,
            )
            if result is not None:
                return result
        if is_milestone_action(action):
            result = await handle_milestone_action(
                action,
                durable_write_service=durable_write_service,
                settings=settings,
                conversation_id=conversation_id,
                user_message=user_message,
                conversation_messages=conversation_messages,
                assistant_reply=assistant_reply,
            )
            if result is not None:
                return result
    return None
