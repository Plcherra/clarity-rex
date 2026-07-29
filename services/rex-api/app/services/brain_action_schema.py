"""Structured actions Grok may return (plan 05). Parse only — no understanding heuristics."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from typing import Any, Optional

from app.services.assistant_proposal_settings import (
    PROPOSAL_KIND_GOALS,
    PROPOSAL_KIND_MEMORY,
    PROPOSAL_KIND_THREADS,
)

REX_ACTION_BLOCK_PATTERN = re.compile(
    r"```rex_action\s*(.*?)```",
    re.IGNORECASE | re.DOTALL,
)

ACTION_JUST_CHAT = "just_chat"
ACTION_UNSUPPORTED = "unsupported"

# Soft mutate families gated by Auto Suggestions kinds (Phase B plumbing).
_SOFT_ACTION_KINDS: dict[str, str] = {
    "create_open_thread": PROPOSAL_KIND_THREADS,
    "update_open_thread": PROPOSAL_KIND_THREADS,
    "create_goal": PROPOSAL_KIND_GOALS,
    "update_goal": PROPOSAL_KIND_GOALS,
    "delete_goal": PROPOSAL_KIND_GOALS,
    "create_milestone": PROPOSAL_KIND_GOALS,
    "update_milestone": PROPOSAL_KIND_GOALS,
    "delete_milestone": PROPOSAL_KIND_GOALS,
    "save_memory": PROPOSAL_KIND_MEMORY,
    "update_memory": PROPOSAL_KIND_MEMORY,
    "delete_knows_item": PROPOSAL_KIND_MEMORY,
    "save_person": PROPOSAL_KIND_MEMORY,
    "update_person_state": PROPOSAL_KIND_MEMORY,
    "add_person_note": PROPOSAL_KIND_MEMORY,
    "save_connection": PROPOSAL_KIND_MEMORY,
    "save_shared_history": PROPOSAL_KIND_MEMORY,
    "save_social_group": PROPOSAL_KIND_MEMORY,
}

SOFT_MUTATE_ACTIONS = frozenset(_SOFT_ACTION_KINDS)

_ACTION_ALIASES: dict[str, str] = {
    "create_thread": "create_open_thread",
    "update_thread": "update_open_thread",
}
_TOP_LEVEL_PAYLOAD_ALIASES: dict[str, str] = {
    "threadId": "thread_id",
    "thread_id": "thread_id",
    "title": "title",
    "newTitle": "new_title",
    "new_title": "new_title",
    "targetTitle": "target_title",
    "target_title": "target_title",
    "reason": "summary",
    "why": "summary",
    "summary": "summary",
    "details": "summary",
    "description": "summary",
    "body": "summary",
    "content": "content",
    "text": "content",
    "memory": "content",
    "memoryType": "memory_type",
    "memory_type": "memory_type",
    "memoryId": "memory_id",
    "memory_id": "memory_id",
    "recordId": "record_id",
    "record_id": "record_id",
    "displayName": "display_name",
    "display_name": "display_name",
    "personName": "person_name",
    "person_name": "person_name",
    "name": "name",
    "relationship": "relationship",
    "personId": "person_id",
    "person_id": "person_id",
    "entityId": "entity_id",
    "entity_id": "entity_id",
    "state": "state",
    "note": "note",
    "notes": "notes",
    "table": "table",
    "reference": "reference",
}


@dataclass(frozen=True)
class BrainAction:
    name: str
    payload: dict[str, Any] = field(default_factory=dict)
    capability_hint: str = ""
    explicit: bool = False
    auto: bool = True

    @property
    def kind(self) -> Optional[str]:
        return _SOFT_ACTION_KINDS.get(self.name)

    @property
    def is_unsupported(self) -> bool:
        return self.name == ACTION_UNSUPPORTED

    @property
    def is_soft_mutate(self) -> bool:
        return self.name in SOFT_MUTATE_ACTIONS


@dataclass(frozen=True)
class ParsedBrainTurn:
    reply_text: str
    actions: list[BrainAction]


def proposal_kind_for_action(action_name: str) -> Optional[str]:
    return _SOFT_ACTION_KINDS.get(str(action_name or "").strip())


def parse_brain_actions(response: str) -> ParsedBrainTurn:
    """Strip ```rex_action``` fences and return typed actions + visible reply."""
    actions: list[BrainAction] = []

    def replace_block(match: re.Match[str]) -> str:
        raw_json = match.group(1).strip()
        try:
            decoded = json.loads(raw_json)
        except json.JSONDecodeError:
            return ""
        items = decoded if isinstance(decoded, list) else [decoded]
        for item in items:
            if not isinstance(item, dict):
                continue
            action = _normalize_action(item)
            if action is not None:
                actions.append(action)
        return ""

    cleaned = REX_ACTION_BLOCK_PATTERN.sub(replace_block, response or "")
    return ParsedBrainTurn(reply_text=cleaned.strip(), actions=actions)


def _normalize_action(item: dict[str, Any]) -> Optional[BrainAction]:
    raw_name = str(item.get("action") or "").strip()
    name = _ACTION_ALIASES.get(raw_name, raw_name)
    if not name:
        return None
    if name == ACTION_JUST_CHAT:
        return BrainAction(name=ACTION_JUST_CHAT)
    payload = item.get("payload")
    if not isinstance(payload, dict):
        payload = {}
    else:
        payload = dict(payload)
    for source_key, target_key in _TOP_LEVEL_PAYLOAD_ALIASES.items():
        if target_key in payload or source_key not in item:
            continue
        payload[target_key] = item.get(source_key)
    hint = str(
        item.get("capability_hint")
        or payload.get("capability_hint")
        or ""
    ).strip()
    if name == ACTION_UNSUPPORTED:
        if not hint:
            hint = "unsupported"
        return BrainAction(
            name=ACTION_UNSUPPORTED,
            payload=payload,
            capability_hint=hint,
        )
    # explicit:true always wins — Grok often emits both auto and explicit.
    marked_explicit = item.get("explicit") is True or payload.get("explicit") is True
    if marked_explicit:
        explicit = True
        auto = False
    elif "auto" in item:
        auto = bool(item.get("auto"))
        explicit = not auto
    else:
        explicit = False
        auto = True
    return BrainAction(
        name=name,
        payload=payload,
        capability_hint=hint,
        explicit=explicit,
        auto=auto,
    )
