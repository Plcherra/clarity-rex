"""Shared setup for the chat Knows-write flows that script the Grok brain.

Grok is the only understanding layer, so these tests script the reply (and the
```rex_action``` fence) the brain would return and then assert what the body
does with it.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from app.services.chat_service import ChatService
from chat_service_fakes import FakeMemoryService
from scripted_brain_fakes import (
    ScriptedAIService,
    fixed_time_context_service,
    scripted_chat_service,
)


@dataclass(frozen=True)
class ScriptedTurns:
    """One chat service plus the brain script and store behind it."""

    brain: ScriptedAIService
    chat: ChatService
    store: FakeMemoryService


def scripted_turns(
    script: dict[str, str],
    *,
    store: Optional[FakeMemoryService] = None,
) -> ScriptedTurns:
    resolved_store = store if store is not None else FakeMemoryService()
    chat = scripted_chat_service(script, resolved_store)
    return ScriptedTurns(brain=chat.ai_service, chat=chat, store=resolved_store)


def seed_flat_memory(
    store: FakeMemoryService,
    *,
    memory_id: str,
    content: str,
    memory_type: str = "fact",
    importance: int = 4,
    metadata: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    record = {
        "id": memory_id,
        "memory_type": memory_type,
        "content": content,
        "importance": importance,
        "metadata": dict(metadata or {}),
        "active": True,
    }
    store.long_term_memory.append(record)
    return record


def active_person_cards(store: FakeMemoryService) -> list[dict[str, Any]]:
    return [
        entity
        for entity in store.entities
        if entity.get("entity_type") == "person" and entity.get("active", True)
    ]
