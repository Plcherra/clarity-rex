"""Structured metadata logging for chat turn routing and truth guards."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from typing import Optional
from uuid import uuid4


@dataclass
class ChatTurnTrace:
    conversation_id: str
    intent: str
    handler: str = "pending"
    pending_action_type: Optional[str] = None
    truth_guard_rewrites: list[str] = field(default_factory=list)
    duration_ms: Optional[int] = None

    def record_handler(self, handler: str) -> None:
        self.handler = handler

    def record_pending_action(self, action_type: Optional[str]) -> None:
        self.pending_action_type = action_type

    def record_truth_rewrite(self, guard_name: str) -> None:
        if guard_name not in self.truth_guard_rewrites:
            self.truth_guard_rewrites.append(guard_name)

    def metadata(self) -> dict:
        payload = {
            "conversation_id": self.conversation_id,
            "intent": self.intent,
            "handler": self.handler,
        }
        if self.pending_action_type:
            payload["pending_action_type"] = self.pending_action_type
        if self.truth_guard_rewrites:
            payload["truth_guard_rewrites"] = list(self.truth_guard_rewrites)
        if self.duration_ms is not None:
            payload["duration_ms"] = self.duration_ms
        return payload


class ChatTurnObserver:
    """Logs turn routing metadata without user message bodies or memory content."""

    def __init__(self, logger: Optional[logging.Logger] = None) -> None:
        self.logger = logger or logging.getLogger("rex.chat_turn")

    def new_trace(self, *, conversation_id: str, intent: str) -> ChatTurnTrace:
        return ChatTurnTrace(conversation_id=conversation_id, intent=intent)

    def new_request_id(self, prefix: str = "chatturn") -> str:
        return f"{prefix}-{uuid4().hex[:12]}"

    def log_turn(self, trace: ChatTurnTrace) -> dict:
        payload = trace.metadata()
        self.logger.info("chat_turn %s", json.dumps(payload, sort_keys=True))
        return payload
