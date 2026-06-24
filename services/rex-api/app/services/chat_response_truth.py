from __future__ import annotations

from app.services.action_truth_policy import (
    safe_chat_search_capability_response,
    safe_degraded_memory_search_response,
    safe_empty_recall_search_response,
    safe_old_chat_search_response,
    safe_pending_action_response,
    safe_unexecuted_delete_response,
    safe_unexecuted_memory_response,
    safe_unsupported_action_response,
)
from app.services.rex_intent_router import RexIntent


class ChatResponseTruthService:
    def truthful_generated_response(
        self,
        assistant_response: str,
        clarity_action_proposals: list[dict],
        *,
        unsupported_actions: list[str],
        intent_decision,
        user_message: str,
        memory_status: object = None,
        chat_search_results_loaded: bool = False,
    ) -> str:
        response = safe_pending_action_response(
            assistant_response,
            clarity_action_proposals,
        )
        if clarity_action_proposals:
            return response
        response = safe_unsupported_action_response(response, unsupported_actions)
        if unsupported_actions:
            return response
        response = safe_degraded_memory_search_response(
            response,
            memory_status=memory_status,
        )
        response = safe_old_chat_search_response(
            response,
            chat_search_results_loaded=chat_search_results_loaded,
            memory_status=memory_status,
        )
        response = safe_empty_recall_search_response(
            response,
            memory_status=memory_status,
        )
        response = safe_chat_search_capability_response(response)
        response = safe_unexecuted_delete_response(
            response,
            user_message=user_message,
        )
        if intent_decision.intent in {RexIntent.MEMORY_SAVE, RexIntent.MEMORY_UPDATE}:
            return safe_unexecuted_memory_response(response)
        return response

    def has_chat_search_results(self, messages: list[dict]) -> bool:
        for message in messages:
            content = message.get("content")
            if isinstance(content, str) and "Chat history, not saved memory:" in content:
                return True
        return False
