from typing import Optional

from app.services.chat_context_service import ChatContextService
from app.services.rex_channel import RexBrainChannel


class SimpleRexBrain:
    """Thin prompt assembly surface until plan 05 restores Grok-brain wiring."""

    def __init__(
        self,
        *,
        chat_context_service: ChatContextService,
    ) -> None:
        self.chat_context_service = chat_context_service

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
        response_style: Optional[str] = None,
    ) -> list[dict]:
        _ = channel
        _ = user_enabled_proactive_insights
        _ = response_style
        return self.chat_context_service.build_prompt_messages(
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
