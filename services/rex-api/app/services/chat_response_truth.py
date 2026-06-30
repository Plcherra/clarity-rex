from __future__ import annotations

import re

from app.services.action_truth_policy import (
    safe_chat_search_capability_response,
    safe_degraded_memory_search_response,
    safe_empty_recall_search_response,
    safe_old_chat_search_response,
    safe_pending_action_response,
    safe_unexecuted_delete_response,
    safe_unexecuted_goal_response,
    safe_unexecuted_memory_response,
    safe_unsupported_action_response,
)
from app.services.chat_turn_observability import ChatTurnTrace
from app.services.rex_intent_router import RexIntent


def _apply_truth_guard(
    guard_name: str,
    before: str,
    after: str,
    turn_trace: ChatTurnTrace | None,
) -> str:
    if turn_trace is not None and before.strip() != after.strip():
        turn_trace.record_truth_rewrite(guard_name)
    return after


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
        conversation_history: list[dict] | None = None,
        turn_trace: ChatTurnTrace | None = None,
    ) -> str:
        response = assistant_response
        updated = safe_pending_action_response(
            response,
            clarity_action_proposals,
        )
        response = _apply_truth_guard(
            "pending_action",
            response,
            updated,
            turn_trace,
        )
        if clarity_action_proposals:
            return response
        updated = safe_unsupported_action_response(response, unsupported_actions)
        response = _apply_truth_guard(
            "unsupported_action",
            response,
            updated,
            turn_trace,
        )
        if unsupported_actions:
            return response
        updated = safe_degraded_memory_search_response(
            response,
            memory_status=memory_status,
        )
        response = _apply_truth_guard(
            "degraded_memory_search",
            response,
            updated,
            turn_trace,
        )
        updated = safe_old_chat_search_response(
            response,
            chat_search_results_loaded=chat_search_results_loaded,
            memory_status=memory_status,
        )
        response = _apply_truth_guard(
            "old_chat_search",
            response,
            updated,
            turn_trace,
        )
        updated = safe_empty_recall_search_response(
            response,
            memory_status=memory_status,
        )
        response = _apply_truth_guard(
            "empty_recall_search",
            response,
            updated,
            turn_trace,
        )
        updated = safe_chat_search_capability_response(response)
        response = _apply_truth_guard(
            "chat_search_capability",
            response,
            updated,
            turn_trace,
        )
        updated = safe_unexecuted_delete_response(
            response,
            user_message=user_message,
            conversation_history=conversation_history,
            intent=intent_decision.intent.value,
        )
        response = _apply_truth_guard(
            "unexecuted_delete",
            response,
            updated,
            turn_trace,
        )
        if intent_decision.intent in {
            RexIntent.GOAL_OR_COMMITMENT,
            RexIntent.UNKNOWN,
        }:
            updated = safe_unexecuted_goal_response(
                response,
                user_message=user_message,
                intent=intent_decision.intent.value,
            )
            response = _apply_truth_guard(
                "unexecuted_goal",
                response,
                updated,
                turn_trace,
            )
        if intent_decision.intent in {RexIntent.MEMORY_SAVE, RexIntent.MEMORY_UPDATE}:
            updated = safe_unexecuted_memory_response(response)
            return _apply_truth_guard(
                "unexecuted_memory",
                response,
                updated,
                turn_trace,
            )
        if intent_decision.intent in {RexIntent.CASUAL, RexIntent.UNKNOWN} and (
            self._message_confirms_save(user_message)
        ):
            updated = safe_unexecuted_memory_response(response)
            return _apply_truth_guard(
                "unexecuted_memory_confirmation",
                response,
                updated,
                turn_trace,
            )
        if self._user_requested_memory_save(user_message):
            updated = safe_unexecuted_memory_response(response)
            response = _apply_truth_guard(
                "unexecuted_memory_request",
                response,
                updated,
                turn_trace,
            )
        return response

    def _message_confirms_save(self, user_message: str) -> bool:
        from app.services.conversation_pending_action import is_delete_confirmation_message

        return is_delete_confirmation_message(user_message)

    def _user_requested_memory_save(self, user_message: str) -> bool:
        from app.services.memory_intent_service import MemoryIntentService

        service = MemoryIntentService()
        if service.is_contextual_memory_save_request(user_message):
            return True
        normalized = service._normalize_reply(user_message)
        return bool(
            re.search(
                r"\b(?:save|remember|keep)\b.*\b(?:memory|knows|pc|computer|laptop|device|model|birthday)\b",
                normalized,
            )
        )

    def has_chat_search_results(self, messages: list[dict]) -> bool:
        for message in messages:
            content = message.get("content")
            if isinstance(content, str) and "Chat history, not saved memory:" in content:
                return True
        return False
