from typing import Any, Optional

from app.services.prompt_accountability_context import PromptAccountabilityContextMixin
from app.services.prompt_constants import (
    ACCOUNTABILITY_CONTEXT_PREFIX,
    CONVERSATION_CONTEXT_PREFIX,
    FILE_CONTEXT_PREFIX,
    FINANCIAL_CONTEXT_PREFIX,
    LONG_TERM_MEMORY_PREFIX,
    MAX_DEFAULT_REX_PROMPT_CHARACTERS,
    MEMORY_DISCIPLINE_PROMPT,
    PERSONALITY_CONTEXT_PREFIX,
    REX_PERSONALITY_PROMPT,
    STRUCTURED_MEMORY_PREFIX,
    TIME_CONTEXT_PREFIX,
)
from app.services.prompt_financial_context import PromptFinancialContextMixin
from app.services.prompt_memory_context import PromptMemoryContextMixin
from app.services.prompt_structured_context import PromptStructuredContextMixin
from app.services.action_truth_policy import ACTION_TRUTH_POLICY_PROMPT
from app.services.brain_prompt_policy import (
    include_action_truth_prompt,
    include_memory_discipline_prompt,
    include_personality_prompt,
)
from app.services.locale_utils import locale_response_rule
from app.services.time_context_service import TimeContextService


class PromptService(
    PromptAccountabilityContextMixin,
    PromptFinancialContextMixin,
    PromptMemoryContextMixin,
    PromptStructuredContextMixin,
):
    def __init__(
        self,
        time_context_service: Optional[TimeContextService] = None,
    ) -> None:
        self.time_context_service = time_context_service or TimeContextService()

    def build_messages(
        self,
        user_message: str,
        recent_messages: Optional[list[dict]] = None,
        relevant_memories: Optional[list[dict]] = None,
        structured_context: Optional[dict] = None,
        accountability_signals: Optional[list[Any]] = None,
        file_context: Optional[str] = None,
        conversation_metadata: Optional[dict] = None,
        time_context: Optional[dict] = None,
        financial_context: Optional[dict] = None,
        max_context_characters: Optional[int] = None,
        locale: Optional[str] = None,
    ) -> list[dict]:
        messages = [
            *self._message_history(recent_messages or []),
            {"role": "user", "content": user_message},
        ]
        messages = self._messages_with_file_context(messages, file_context)

        system_sections = self._system_sections(
            relevant_memories=relevant_memories or [],
            structured_context=structured_context or {},
            accountability_signals=accountability_signals or [],
            conversation_metadata=conversation_metadata,
            time_context=time_context,
            financial_context=financial_context,
            locale=locale,
        )
        if not system_sections:
            return messages

        messages = [
            {"role": "system", "content": "\n\n".join(system_sections)},
            *messages,
        ]

        return self._trim_context(
            messages,
            max_context_characters=max_context_characters,
        )

    def _message_history(self, recent_messages: list[dict]) -> list[dict]:
        messages = []
        for message in recent_messages:
            role = message.get("role")
            content = message.get("content")
            if role not in {"user", "assistant", "system"} or not content:
                continue
            messages.append({"role": role, "content": str(content)})
        return messages

    def _system_sections(
        self,
        relevant_memories: list[dict],
        structured_context: dict,
        accountability_signals: list[Any],
        conversation_metadata: Optional[dict],
        time_context: Optional[dict],
        financial_context: Optional[dict],
        locale: Optional[str] = None,
    ) -> list[str]:
        sections: list[str] = []
        if include_personality_prompt():
            sections.append(f"{PERSONALITY_CONTEXT_PREFIX}{REX_PERSONALITY_PROMPT}")
        if include_action_truth_prompt():
            sections.append(ACTION_TRUTH_POLICY_PROMPT)

        locale_rule = locale_response_rule(locale)
        if locale_rule:
            sections.append(locale_rule)

        if include_memory_discipline_prompt() and (
            relevant_memories
            or structured_context
            or accountability_signals
            or financial_context
        ):
            sections.append(MEMORY_DISCIPLINE_PROMPT)

        time_section = self._time_context_section(time_context)
        if time_section:
            sections.append(time_section)

        conversation_section = self._conversation_context_section(
            conversation_metadata,
        )
        if conversation_section:
            sections.append(conversation_section)

        structured_section = self._structured_memory_section(
            structured_context,
            saved_memory_count=len(relevant_memories),
        )
        if structured_section:
            sections.append(structured_section)

        accountability_section = self._accountability_section(accountability_signals)
        if accountability_section:
            sections.append(accountability_section)

        financial_section = self._financial_context_section(financial_context)
        if financial_section:
            sections.append(financial_section)

        memory_section = self._long_term_memory_section(
            relevant_memories,
            time_context,
        )
        if memory_section:
            sections.append(memory_section)

        chat_search_section = self._chat_search_results_section(
            structured_context.get("chat_search_results") or [],
            time_context,
        )
        if chat_search_section:
            sections.append(chat_search_section)

        open_threads_section = structured_context.get("open_threads_context")
        if isinstance(open_threads_section, str) and open_threads_section.strip():
            sections.append(open_threads_section.strip())

        return sections
