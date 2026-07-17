"""Grok LLM brain: tiny system + thin state → generate/stream reply."""

from __future__ import annotations

from typing import Any, AsyncIterator, Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.locale_utils import locale_response_rule
from app.services.tiny_system_prompt import build_tiny_system_prompt


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
    ) -> list[dict[str, str]]:
        system = build_tiny_system_prompt(
            proposal_settings,
            open_thread_titles_block=open_thread_titles_block,
        )
        locale_rule = locale_response_rule(locale)
        if locale_rule:
            system = f"{locale_rule}\n\n{system}"
        messages: list[dict[str, str]] = [{"role": "system", "content": system}]
        for message in recent_messages:
            role = str(message.get("role") or "")
            content = str(message.get("content") or "").strip()
            if role not in {"user", "assistant"} or not content:
                continue
            messages.append({"role": role, "content": content})
        messages.append({"role": "user", "content": user_message})
        return messages

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
