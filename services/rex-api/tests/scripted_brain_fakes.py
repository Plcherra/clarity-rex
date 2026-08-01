"""Fakes that let end-to-end chat and voice tests speak the brain's actions.

Grok alone decides that a turn writes something, so an end-to-end test scripts
the reply the brain would give for a message instead of relying on the backend
to infer intent from the user's words.
"""

from __future__ import annotations

import json
from datetime import datetime
from typing import Any, Optional, Sequence
from zoneinfo import ZoneInfo

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.grok_usage import GrokChatResult, GrokUsage
from app.services.time_context_service import TimeContextService

DEFAULT_NOW = datetime(2026, 6, 1, 12, 0, tzinfo=ZoneInfo("America/New_York"))


def rex_action(
    name: str,
    payload: Optional[dict[str, Any]] = None,
    *,
    explicit: bool = False,
    auto: Optional[bool] = None,
) -> str:
    """Render one ```rex_action``` fence the way Grok emits it."""
    body: dict[str, Any] = {"action": name, "payload": payload or {}}
    if explicit:
        body["explicit"] = True
    if auto is not None:
        body["auto"] = auto
    return "```rex_action\n" + json.dumps(body) + "\n```"


def reply_with_action(
    reply: str,
    name: str,
    payload: Optional[dict[str, Any]] = None,
    **kwargs: Any,
) -> str:
    """A spoken reply plus the action the body should execute."""
    return f"{reply}\n{rex_action(name, payload, **kwargs)}"


class ScriptedAIService:
    """Reply per turn, chosen by a phrase from the user's message.

    API-compatible with `FakeAIService` so a test can swap in a script without
    changing how it builds `ChatService`.
    """

    def __init__(
        self,
        script: Optional[dict[str, str]] = None,
        *,
        default: str = "Rex response",
        reply_chunks: Optional[Sequence[str]] = None,
        usage: Optional[GrokUsage] = None,
    ) -> None:
        self.script = dict(script or {})
        self.default = default
        self.reply_chunks = list(reply_chunks) if reply_chunks else None
        self.usage = usage or GrokUsage(prompt_tokens=100, completion_tokens=40)
        self.messages: list = []
        self.kwargs: dict = {}
        self.prompts: list[str] = []
        self.user_messages: list[str] = []
        self.generate_calls = 0
        # Turns where Grok could act carry the capability tool; the grounded
        # second pass does not. Counting them apart keeps "the brain ran once"
        # separate from "we paid for a fetch pass".
        self.decide_calls = 0
        self.fetch_calls = 0

    def reply_for(self, messages: Sequence[dict]) -> str:
        user_text = latest_user_text(messages).casefold()
        for phrase, reply in self.script.items():
            if phrase.casefold() in user_text:
                return reply
        if self.reply_chunks:
            return "".join(self.reply_chunks)
        return self.default

    async def generate_response(self, messages, **kwargs):
        self.generate_calls += 1
        if kwargs.get("tools"):
            self.decide_calls += 1
        else:
            self.fetch_calls += 1
        self._record(messages, kwargs)
        return GrokChatResult(text=self.reply_for(messages), usage=self.usage)

    def _record(self, messages, kwargs: dict) -> None:
        self.messages = messages
        self.kwargs = kwargs
        self.prompts.append(system_prompt(messages))
        self.user_messages.append(latest_user_text(messages))


def fixed_time_context_service(now: datetime = DEFAULT_NOW) -> TimeContextService:
    """A clock the prompt assertions can pin to."""
    return TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: now,
    )


def scripted_chat_service(
    script: dict[str, str],
    memory_service,
    *,
    default: str = "Rex response",
    now: datetime = DEFAULT_NOW,
) -> ChatService:
    return ChatService(
        ScriptedAIService(script, default=default),
        FileService(),
        memory_service,
        time_context_service=fixed_time_context_service(now),
    )


def latest_user_text(messages: Sequence[dict]) -> str:
    for message in reversed(list(messages)):
        if message.get("role") != "user":
            continue
        return message_text(message.get("content"))
    return ""


def system_prompt(messages: Sequence[dict]) -> str:
    for message in messages:
        if message.get("role") == "system":
            return message_text(message.get("content"))
    return ""


def message_text(content: Any) -> str:
    """Flatten content that may be plain text or multimodal parts."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [
            str(part.get("text") or "")
            for part in content
            if isinstance(part, dict) and part.get("type") == "text"
        ]
        return " ".join(part for part in parts if part)
    return str(content or "")
