"""Structured metadata logging for chat turn routing and truth guards."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from typing import Any, Optional
from uuid import uuid4


SETTINGS_LOAD_OK = "ok"
SETTINGS_LOAD_FAIL_CLOSED = "fail_closed"
SETTINGS_LOAD_MISSING_AUTH = "missing_auth"
SETTINGS_LOAD_EMPTY_PROFILE = "empty_profile"

DURABLE_APPLY_NONE = "none"
DURABLE_APPLY_PENDING = "pending"
DURABLE_APPLY_APPLIED = "applied"
DURABLE_APPLY_REJECTED = "rejected"
DURABLE_APPLY_SKIPPED = "skipped"


@dataclass
class ChatTurnTrace:
    conversation_id: str
    intent: str
    handler: str = "pending"
    pending_action_type: Optional[str] = None
    resolver_target_type: Optional[str] = None
    resolver_target: Optional[str] = None
    truth_guard_rewrites: list[str] = field(default_factory=list)
    duration_ms: Optional[int] = None
    profile_mode: Optional[str] = None
    env_mode: Optional[str] = None
    effective_mode: Optional[str] = None
    settings_load_status: Optional[str] = None
    enabled_proposal_kinds: list[str] = field(default_factory=list)
    proposal_kind: Optional[str] = None
    write_proposals_count: int = 0
    durable_apply_status: str = DURABLE_APPLY_NONE

    def record_handler(self, handler: str) -> None:
        self.handler = handler

    def record_pending_action(self, action_type: Optional[str]) -> None:
        self.pending_action_type = action_type

    def record_resolver_target(
        self,
        target_type: Optional[str],
        resolver_target: Optional[str],
    ) -> None:
        self.resolver_target_type = target_type
        self.resolver_target = resolver_target

    def record_truth_rewrite(self, guard_name: str) -> None:
        if guard_name not in self.truth_guard_rewrites:
            self.truth_guard_rewrites.append(guard_name)

    def record_proposal_settings(
        self,
        *,
        profile_mode: Optional[str],
        env_mode: Optional[str],
        effective_mode: str,
        settings_load_status: str,
        enabled_proposal_kinds: list[str],
    ) -> None:
        self.profile_mode = profile_mode
        self.env_mode = env_mode
        self.effective_mode = effective_mode
        self.settings_load_status = settings_load_status
        self.enabled_proposal_kinds = list(enabled_proposal_kinds)

    def record_proposal_outcome(
        self,
        *,
        proposal_kind: Optional[str] = None,
        write_proposals_count: int = 0,
        durable_apply_status: str = DURABLE_APPLY_NONE,
    ) -> None:
        if proposal_kind:
            self.proposal_kind = proposal_kind
        self.write_proposals_count = max(0, int(write_proposals_count))
        self.durable_apply_status = durable_apply_status

    def metadata(self) -> dict:
        payload: dict[str, Any] = {
            "conversation_id": self.conversation_id,
            "intent": self.intent,
            "handler": self.handler,
            "write_proposals_count": self.write_proposals_count,
            "durable_apply_status": self.durable_apply_status,
        }
        if self.pending_action_type:
            payload["pending_action_type"] = self.pending_action_type
        if self.resolver_target_type:
            payload["resolver_target_type"] = self.resolver_target_type
        if self.resolver_target:
            payload["resolver_target"] = self.resolver_target
        if self.truth_guard_rewrites:
            payload["truth_guard_rewrites"] = list(self.truth_guard_rewrites)
        if self.duration_ms is not None:
            payload["duration_ms"] = self.duration_ms
        if self.profile_mode is not None:
            payload["profile_mode"] = self.profile_mode
        if self.env_mode is not None:
            payload["env_mode"] = self.env_mode
        if self.effective_mode is not None:
            payload["effective_mode"] = self.effective_mode
        if self.settings_load_status is not None:
            payload["settings_load_status"] = self.settings_load_status
        if self.enabled_proposal_kinds:
            payload["enabled_proposal_kinds"] = list(self.enabled_proposal_kinds)
        if self.proposal_kind:
            payload["proposal_kind"] = self.proposal_kind
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
