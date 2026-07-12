"""Resolve bare 'save/remember that' against the latest topic only."""

from __future__ import annotations

import re
from typing import Optional

from app.services.memory_intent_models import SimpleMemoryIntent


class MemoryIntentContextualSaveMixin:
    def _detect_contextual_save_proposal_memory(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: Optional[dict] = None,
    ) -> Optional[SimpleMemoryIntent]:
        if not self.is_contextual_memory_save_request(message):
            return None

        normalized = self._normalize_reply(message)
        if re.search(
            r"\b(?:save|remember|keep)\b",
            normalized,
        ) and re.search(r"\b(?:pc|computer|laptop|device|model)\b", normalized):
            intent = self._intent_from_conversation_history(
                conversation_history,
                time_context=time_context,
            )
            if intent is not None:
                return intent

        for item in reversed(conversation_history[-8:]):
            if item.get("role") != "assistant":
                continue
            content = str(item.get("content") or "")
            if not self._assistant_offered_save(content):
                continue
            intent = self._intent_from_conversation_history(
                [item],
                time_context=time_context,
            )
            if intent is not None:
                return intent

        # "Remember/save that" refers to the latest topic exchange only.
        # Never re-latch onto older explicit saves once the conversation moved on.
        referent = self._referent_turns_for_contextual_save(conversation_history)
        if not referent:
            return None
        return self._intent_from_conversation_history(
            referent,
            time_context=time_context,
        )

    def _referent_turns_for_contextual_save(
        self,
        conversation_history: list[dict],
    ) -> list[dict]:
        recent = [
            item
            for item in list(conversation_history or [])[-8:]
            if str(item.get("content") or "").strip()
        ]
        while recent and recent[-1].get("role") == "user":
            content = str(recent[-1].get("content") or "")
            if self._is_bare_contextual_save_request(content):
                recent.pop()
                continue
            break

        last_user_index = None
        for index in range(len(recent) - 1, -1, -1):
            if recent[index].get("role") == "user":
                last_user_index = index
                break
        if last_user_index is None:
            return []

        window = [recent[last_user_index]]
        for item in recent[last_user_index + 1 :]:
            if item.get("role") == "user":
                break
            window.append(item)
        return window

    def _is_bare_contextual_save_request(self, message: str) -> bool:
        if not self.is_contextual_memory_save_request(message):
            return False
        # A message that already states a durable fact is the topic, not a pointer.
        return self.detect_simple_memory(message) is None
