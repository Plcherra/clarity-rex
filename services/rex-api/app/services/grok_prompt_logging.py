"""Optional logging of the exact message list sent to Grok (local debugging)."""

from __future__ import annotations

import json
import logging
from typing import Any

from app.config import get_settings

LOGGER = logging.getLogger("rex.grok_prompt")


def log_grok_prompt_messages(
    messages: list[dict[str, Any]],
    *,
    channel: str,
    conversation_id: str | None = None,
    max_chars: int = 12000,
) -> None:
    if not get_settings().rex_log_grok_prompt:
        return
    payload = {
        "channel": channel,
        "conversation_id": conversation_id,
        "message_count": len(messages),
        "messages": _summarize_messages(messages, max_chars=max_chars),
    }
    LOGGER.info("grok_prompt %s", json.dumps(payload, ensure_ascii=False, sort_keys=True))


def _summarize_messages(
    messages: list[dict[str, Any]],
    *,
    max_chars: int,
) -> list[dict[str, str]]:
    summarized: list[dict[str, str]] = []
    remaining = max_chars
    for index, message in enumerate(messages):
        role = str(message.get("role") or "unknown")
        content = _stringify_content(message.get("content"))
        if remaining <= 0:
            summarized.append(
                {
                    "role": role,
                    "content": f"[truncated; omitted message {index + 1}+]",
                }
            )
            break
        if len(content) > remaining:
            content = content[:remaining] + "…[truncated]"
        remaining -= len(content)
        summarized.append({"role": role, "content": content})
    return summarized


def _stringify_content(content: Any) -> str:
    if isinstance(content, list):
        parts = []
        for part in content:
            if isinstance(part, dict) and part.get("type") == "text":
                parts.append(str(part.get("text") or ""))
            else:
                parts.append(str(part))
        return "\n".join(part for part in parts if part)
    return str(content or "")
