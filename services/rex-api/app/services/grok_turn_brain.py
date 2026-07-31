"""Grok LLM brain: tiny system + thin state → generate/stream reply."""

from __future__ import annotations

from typing import Any, AsyncIterator, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.file_service import AttachmentContext
from app.services.locale_utils import locale_response_rule
from app.services.prompt_constants import TIME_CONTEXT_PREFIX
from app.services.tiny_system_prompt import build_tiny_system_prompt

# A pasted document must not crowd out the conversation.
_MAX_ATTACHMENT_PROMPT_CHARS = 12_000


class GrokTurnBrain:
    def __init__(self, *, ai_service) -> None:
        self.ai_service = ai_service

    def build_messages(
        self,
        *,
        user_message: str,
        recent_messages: list[dict],
        proposal_settings: AssistantProposalSettings,
        open_thread_titles_block: Optional[str] = None,
        locale: Optional[str] = None,
        time_context: Optional[dict] = None,
        attachment_context: Optional[AttachmentContext] = None,
    ) -> list[dict]:
        system = build_tiny_system_prompt(
            proposal_settings,
            open_thread_titles_block=open_thread_titles_block,
        )
        locale_rule = locale_response_rule(locale)
        if locale_rule:
            system = f"{locale_rule}\n\n{system}"
        clock = time_context_line(time_context)
        if clock:
            system = f"{system}\n\n{clock}"
        messages: list[dict] = [{"role": "system", "content": system}]
        for message in recent_messages:
            role = str(message.get("role") or "")
            content = str(message.get("content") or "").strip()
            if role not in {"user", "assistant"} or not content:
                continue
            messages.append({"role": role, "content": content})
        messages.extend(attachment_messages(attachment_context))
        messages.append({"role": "user", "content": user_message})
        return messages_with_image(messages, attachment_context)

    async def generate(
        self,
        messages: list[dict[str, str]],
        *,
        max_tokens: Optional[int] = None,
    ) -> Any:
        if max_tokens is None:
            return await self.ai_service.generate_response(messages)
        return await self.ai_service.generate_response(
            messages,
            max_tokens=max_tokens,
        )

    def stream(
        self,
        messages: list[dict[str, str]],
        *,
        max_tokens: Optional[int] = None,
        usage_holder=None,
    ) -> AsyncIterator[str]:
        stream_kwargs: dict[str, Any] = {}
        if max_tokens is not None:
            stream_kwargs["max_tokens"] = max_tokens
        if usage_holder is not None:
            stream_kwargs["usage_holder"] = usage_holder
        return self.ai_service.stream_response(messages, **stream_kwargs)


def time_context_line(time_context: Optional[dict]) -> Optional[str]:
    """Thin clock state — the date and the gap Grok cannot know on its own."""
    if not isinstance(time_context, dict) or not time_context:
        return None
    lines = [
        f"- {label}: {time_context.get(key)}"
        for key, label in (
            ("clock_context", "Clock"),
            ("date", "Date"),
            ("previous_timestamp_delta", "Previous message delta"),
        )
        if time_context.get(key)
    ]
    if not lines:
        return None
    return TIME_CONTEXT_PREFIX + "\n".join(lines)


def attachment_messages(attachment: Optional[AttachmentContext]) -> list[dict]:
    """Text and PDF attachments ride as their own turn message, capped in size."""
    if attachment is None or attachment.kind == "image":
        return []
    text = str(attachment.prompt_context or "").strip()
    if not text:
        return []
    if len(text) > _MAX_ATTACHMENT_PROMPT_CHARS:
        text = (
            text[:_MAX_ATTACHMENT_PROMPT_CHARS].rstrip()
            + "\n\n[Attachment truncated for this turn.]"
        )
    return [
        {
            "role": "user",
            "content": f"Attached file {attachment.filename}:\n{text}",
        }
    ]


def messages_with_image(
    messages: list[dict],
    attachment: Optional[AttachmentContext],
) -> list[dict]:
    """Send an image attachment as multimodal content on the user's own message."""
    if attachment is None or attachment.kind != "image" or not attachment.data_url:
        return messages

    updated = [dict(message) for message in messages]
    for index in range(len(updated) - 1, -1, -1):
        if updated[index].get("role") != "user":
            continue
        content = updated[index].get("content", "")
        text = content if isinstance(content, str) else str(content)
        if not text.strip():
            text = "Please look at this image."
        updated[index]["content"] = [
            {"type": "text", "text": text},
            {
                "type": "image_url",
                "image_url": {"url": attachment.data_url, "detail": "auto"},
            },
        ]
        return updated
    return updated
