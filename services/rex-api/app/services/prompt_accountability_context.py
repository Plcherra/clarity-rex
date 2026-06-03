from typing import Any, Optional

from app.services.prompt_constants import (
    ACCOUNTABILITY_CONTEXT_PREFIX,
    CONVERSATION_CONTEXT_PREFIX,
    MAX_ACCOUNTABILITY_CONTEXT_CHARACTERS,
    TIME_CONTEXT_PREFIX,
)


class PromptAccountabilityContextMixin:
    def _accountability_section(
        self,
        accountability_signals: list[Any],
    ) -> Optional[str]:
        if not accountability_signals:
            return None

        lines = [
            "Use this as private coaching context. Mention it naturally only when it helps."
        ]
        used_characters = len(lines[0]) + 1
        for signal in accountability_signals:
            line = self._accountability_line(signal)
            if not line:
                continue
            remaining_characters = (
                MAX_ACCOUNTABILITY_CONTEXT_CHARACTERS - used_characters
            )
            if remaining_characters <= 0:
                break
            if len(line) > remaining_characters:
                if remaining_characters < 40:
                    break
                line = f"{line[: remaining_characters - 22].rstrip()} [truncated]"

            lines.append(line)
            used_characters += len(line) + 1

        if len(lines) == 1:
            return None
        return f"{ACCOUNTABILITY_CONTEXT_PREFIX}{chr(10).join(lines)}"

    def _accountability_line(self, signal: Any) -> Optional[str]:
        signal_type = self._signal_value(signal, "signal_type")
        title = self._signal_value(signal, "title")
        reason = self._signal_value(signal, "reason")
        if not signal_type or not title or not reason:
            return None

        severity = self._signal_value(signal, "severity") or "medium"
        confidence = self._signal_value(signal, "confidence")
        suggested_prompt = self._signal_value(signal, "suggested_prompt")
        recommended_action = self._signal_value(signal, "recommended_action")
        source_refs = self._signal_value(signal, "source_refs") or []

        line = f"- {signal_type}/{severity}: {title} - {reason}"
        if confidence is not None:
            line = f"{line} (confidence: {confidence})"
        source_summary = self._accountability_source_summary(source_refs)
        if source_summary:
            line = f"{line} (sources: {source_summary})"
        if suggested_prompt:
            line = f"{line} Suggested framing: {suggested_prompt}"
        if recommended_action:
            line = f"{line} Action: {recommended_action}"
        return line

    def _accountability_source_summary(self, source_refs: list[Any]) -> Optional[str]:
        summaries = []
        for source in source_refs[:3]:
            source_type = self._signal_value(source, "source_type")
            title = self._signal_value(source, "title")
            excerpt = self._signal_value(source, "excerpt")
            label = str(source_type or "source")
            if title:
                label = f"{label}:{title}"
            if excerpt:
                label = f"{label} - {str(excerpt)[:80]}"
            summaries.append(label)
        return "; ".join(summaries) if summaries else None

    def _signal_value(self, value: Any, field: str) -> Any:
        if isinstance(value, dict):
            return value.get(field)
        return getattr(value, field, None)

    def _time_context_section(self, time_context: Optional[dict]) -> Optional[str]:
        if not time_context:
            return None

        lines = []
        fields = [
            ("clock_context", "Clock"),
            ("iso_timestamp", "ISO timestamp"),
            ("date", "Date"),
            ("weekday", "Weekday"),
            ("time", "Time"),
            ("timezone", "Timezone"),
            ("previous_timestamp_delta", "Previous message delta"),
        ]
        for key, label in fields:
            value = time_context.get(key)
            if value:
                lines.append(f"- {label}: {value}")

        if not lines:
            return None
        return f"{TIME_CONTEXT_PREFIX}{chr(10).join(lines)}"

    def _conversation_context_section(
        self,
        conversation_metadata: Optional[dict],
    ) -> Optional[str]:
        if not conversation_metadata:
            return None

        lines = []
        fields = [
            ("id", "Conversation ID"),
            ("title", "Title"),
            ("timestamp", "Conversation timestamp"),
            ("last_message_timestamp", "Last message timestamp"),
        ]
        for key, label in fields:
            value = conversation_metadata.get(key)
            if value:
                lines.append(f"- {label}: {value}")

        if not lines:
            return None
        return f"{CONVERSATION_CONTEXT_PREFIX}{chr(10).join(lines)}"

