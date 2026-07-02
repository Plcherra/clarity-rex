from typing import Optional

from app.services.chat_context_service import ChatContextService
from app.services.rex_channel import RexBrainChannel
from app.services.rex_intent_router import RexIntentDecision, RexIntentRouter
from app.services.proactive_insight_guard import (
    proactive_monitoring_guard_text,
    requires_proactive_monitoring_opt_in,
)


class SimpleRexBrain:
    """Launch brain: one deterministic orchestration path for Rex.

    The advanced thinking-router modules can remain experimental, but production
    chat should flow through this single brain surface so Clarity does not have
    two competing assistant paths.
    """

    def __init__(
        self,
        *,
        intent_router: Optional[RexIntentRouter] = None,
        chat_context_service: ChatContextService,
    ) -> None:
        self.intent_router = intent_router or RexIntentRouter()
        self.chat_context_service = chat_context_service

    def classify(
        self,
        message: str,
        *,
        has_file: bool,
        has_financial_context: bool,
        user_requested_deep_thinking: bool,
    ) -> RexIntentDecision:
        return self.intent_router.classify(
            message,
            has_file=has_file,
            has_financial_context=has_financial_context,
            user_requested_deep_thinking=user_requested_deep_thinking,
        )

    def build_prompt_messages(
        self,
        *,
        message: str,
        conversation_id: str,
        conversation_history: list[dict],
        long_term_memory: list[dict],
        structured_context: dict,
        accountability_signals: list,
        file_text: Optional[str],
        time_context: dict,
        financial_context: Optional[dict],
        channel: RexBrainChannel,
        locale: Optional[str] = None,
        user_enabled_proactive_insights: bool = False,
    ) -> list[dict]:
        # Channel is intentionally accepted at the brain boundary. The launch
        # brain uses the same prompt path for chat and voice, while leaving room
        # for channel-specific context policy later without adding a second brain.
        _ = channel
        messages = self.chat_context_service.build_prompt_messages(
            message=message,
            conversation_id=conversation_id,
            conversation_history=conversation_history,
            long_term_memory=long_term_memory,
            structured_context=structured_context,
            accountability_signals=accountability_signals,
            file_text=file_text,
            time_context=time_context,
            financial_context=financial_context,
            locale=locale,
        )
        requires_opt_in = requires_proactive_monitoring_opt_in(
            message,
            user_enabled_proactive_insights=user_enabled_proactive_insights,
        )
        guard = proactive_monitoring_guard_text(requires_opt_in=requires_opt_in)
        if guard:
            messages.append({"role": "system", "content": guard})
        return messages
