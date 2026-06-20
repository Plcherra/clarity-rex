from typing import Optional

from app.services.prompt_constants import (
    CHAT_SEARCH_RESULTS_PREFIX,
    FILE_CONTEXT_PREFIX,
    LONG_TERM_MEMORY_PREFIX,
    MAX_CONTEXT_CHARACTERS,
    MAX_MEMORY_CONTEXT_CHARACTERS,
)


class PromptMemoryContextMixin:
    def _long_term_memory_section(
        self,
        relevant_memories: list[dict],
        time_context: Optional[dict],
    ) -> Optional[str]:
        memory_lines = self._memory_lines_with_budget(relevant_memories, time_context)
        if not memory_lines:
            return None
        return f"{LONG_TERM_MEMORY_PREFIX}{chr(10).join(memory_lines)}"

    def _memory_lines_with_budget(
        self,
        relevant_memories: list[dict],
        time_context: Optional[dict],
    ) -> list[str]:
        memory_lines = []
        used_characters = 0

        for memory in relevant_memories:
            memory_type = memory.get("memory_type")
            content = memory.get("content")
            if not memory_type or not content:
                continue

            line = f"- {memory_type}: {content}"

            age_label = self._memory_age_label(
                memory,
                time_context,
                memory_type=memory_type,
            )
            if age_label:
                line = f"{line} ({age_label})"
            relevance_reason = memory.get("relevance_reason")
            if relevance_reason:
                line = f"{line} (why recalled: {relevance_reason})"

            remaining_characters = MAX_MEMORY_CONTEXT_CHARACTERS - used_characters
            if remaining_characters <= 0:
                break
            if len(line) > remaining_characters:
                if remaining_characters < 40:
                    break
                line = f"{line[: remaining_characters - 22].rstrip()} [truncated]"

            memory_lines.append(line)
            used_characters += len(line) + 1

        return memory_lines

    def _memory_age_label(
        self,
        memory: dict,
        time_context: Optional[dict],
        *,
        memory_type: Optional[str] = None,
    ) -> Optional[str]:
        timestamp = memory.get("updated_at") or memory.get("created_at")
        if not timestamp:
            return None

        now = None
        if time_context:
            now = self.time_context_service.parse_timestamp(
                time_context.get("iso_timestamp"),
            )
        delta = self.time_context_service.delta_from(timestamp, now=now)
        if not delta:
            return None

        return f"saved {delta}"

    def _chat_search_results_section(
        self,
        chat_search_results: list[dict],
        time_context: Optional[dict],
    ) -> Optional[str]:
        lines = self._chat_search_result_lines_with_budget(
            chat_search_results,
            time_context,
        )
        if not lines:
            return None
        return f"{CHAT_SEARCH_RESULTS_PREFIX}{chr(10).join(lines)}"

    def _chat_search_result_lines_with_budget(
        self,
        chat_search_results: list[dict],
        time_context: Optional[dict],
    ) -> list[str]:
        lines = []
        used_characters = 0

        for result in chat_search_results:
            content = str(result.get("content") or "").strip()
            if not content:
                continue

            line = f"- Chat history, not saved memory: {content}"
            age_label = self._chat_search_age_label(result, time_context)
            if age_label:
                line = f"{line} ({age_label})"
            relevance_reason = result.get("relevance_reason")
            if relevance_reason:
                line = f"{line} (why recalled: {relevance_reason})"

            remaining_characters = MAX_MEMORY_CONTEXT_CHARACTERS - used_characters
            if remaining_characters <= 0:
                break
            if len(line) > remaining_characters:
                if remaining_characters < 40:
                    break
                line = f"{line[: remaining_characters - 22].rstrip()} [truncated]"

            lines.append(line)
            used_characters += len(line) + 1

        return lines

    def _chat_search_age_label(
        self,
        result: dict,
        time_context: Optional[dict],
    ) -> Optional[str]:
        timestamp = result.get("timestamp") or result.get("created_at")
        if not timestamp:
            return None
        now = None
        if time_context:
            now = self.time_context_service.parse_timestamp(
                time_context.get("iso_timestamp"),
            )
        delta = self.time_context_service.delta_from(timestamp, now=now)
        if not delta:
            return None
        return f"from {delta}"

    def _messages_with_file_context(
        self,
        messages: list[dict],
        file_context: Optional[str],
    ) -> list[dict]:
        if not file_context:
            return messages

        file_message = {
            "role": "user",
            "content": f"{FILE_CONTEXT_PREFIX}{file_context}",
        }
        if not messages:
            return [file_message]

        return [
            *messages[:-1],
            file_message,
            messages[-1],
        ]

    def _trim_context(
        self,
        messages: list[dict],
        *,
        max_context_characters: Optional[int] = None,
    ) -> list[dict]:
        context_limit = max_context_characters or MAX_CONTEXT_CHARACTERS
        trimmed_messages = list(messages)
        while (
            len(trimmed_messages) > 1
            and self._context_length(trimmed_messages) > context_limit
        ):
            remove_index = 1 if trimmed_messages[0].get("role") == "system" else 0
            if self._has_file_context(trimmed_messages[remove_index]):
                break

            trimmed_messages.pop(remove_index)

        trimmed_messages = self._trim_file_context(
            trimmed_messages,
            max_context_characters=context_limit,
        )
        if self._context_length(trimmed_messages) > context_limit:
            last_message = trimmed_messages[-1]
            return [
                {
                    **last_message,
                    "content": last_message["content"][-context_limit:],
                }
            ]

        return trimmed_messages

    def _context_length(self, messages: list[dict]) -> int:
        return sum(len(message["content"]) for message in messages)

    def _trim_file_context(
        self,
        messages: list[dict],
        *,
        max_context_characters: int,
    ) -> list[dict]:
        file_index = self._file_context_index(messages)
        if file_index is None or len(messages) < 2:
            return messages

        latest_message = messages[-1]
        truncation_note = "\n\n[File truncated]"
        available_file_characters = (
            max_context_characters
            - len(latest_message["content"])
            - len(FILE_CONTEXT_PREFIX)
            - len(truncation_note)
            - self._context_length(messages[:file_index])
        )
        if available_file_characters <= 0:
            return [*messages[:file_index], latest_message]

        file_message = messages[file_index]
        file_text = file_message["content"][len(FILE_CONTEXT_PREFIX) :]
        if len(file_text) <= available_file_characters:
            return messages

        return [
            *messages[:file_index],
            {
                **file_message,
                "content": (
                    f"{FILE_CONTEXT_PREFIX}"
                    f"{file_text[:available_file_characters]}{truncation_note}"
                ),
            },
            *messages[file_index + 1 :],
        ]

    def _has_file_context(self, message: dict) -> bool:
        return message["content"].startswith(FILE_CONTEXT_PREFIX)

    def _file_context_index(self, messages: list[dict]) -> Optional[int]:
        for index, message in enumerate(messages):
            if self._has_file_context(message):
                return index
        return None
