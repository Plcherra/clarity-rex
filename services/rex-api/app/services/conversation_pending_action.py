"""Explicit pending actions for confirmation follow-ups."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Optional, Protocol

from app.services.memory_correction_types import CorrectionAffectedRecord
from app.services.memory_delete_reference import (
    is_delete_confirmation_reply,
    is_delete_rejection_reply,
    pending_delete_target_from_history,
)


@dataclass(frozen=True)
class PendingAction:
    action_type: str
    target_type: str
    target_id: str
    target_label: str
    resolver_target: str
    scope_tables: tuple[str, ...] = ()

    def to_dict(self) -> dict[str, str | list[str]]:
        payload: dict[str, str | list[str]] = {
            "action_type": self.action_type,
            "target_type": self.target_type,
            "target_id": self.target_id,
            "target_label": self.target_label,
            "resolver_target": self.resolver_target,
        }
        if self.scope_tables:
            payload["scope_tables"] = list(self.scope_tables)
        return payload

    @classmethod
    def from_dict(cls, payload: Any) -> Optional[PendingAction]:
        if not isinstance(payload, dict):
            return None
        action_type = str(payload.get("action_type") or "").strip()
        target_type = str(payload.get("target_type") or "").strip()
        target_id = str(payload.get("target_id") or "").strip()
        target_label = str(payload.get("target_label") or "").strip()
        resolver_target = str(
            payload.get("resolver_target") or payload.get("delete_target") or ""
        ).strip()
        raw_scope = payload.get("scope_tables") or ()
        scope_tables = tuple(str(item) for item in raw_scope if str(item).strip())
        if not action_type or not resolver_target:
            return None
        return cls(
            action_type=action_type,
            target_type=target_type or "unspecified",
            target_id=target_id,
            target_label=target_label or resolver_target,
            resolver_target=resolver_target,
            scope_tables=scope_tables,
        )


def pending_action_for_delete(
    *,
    target: str,
    match: CorrectionAffectedRecord,
    scope_tables: tuple[str, ...] = (),
) -> PendingAction:
    label = str(match.title or target).strip() or target
    table = str(match.table or "unspecified")
    resolved_scope = scope_tables or (table,)
    return PendingAction(
        action_type="delete",
        target_type=table,
        target_id=str(match.id or ""),
        target_label=label,
        resolver_target=target,
        scope_tables=resolved_scope,
    )


class PendingActionStore(Protocol):
    async def get_conversation_pending_action(
        self,
        conversation_id: str,
    ) -> Optional[dict]:
        pass

    async def set_conversation_pending_action(
        self,
        conversation_id: str,
        pending_action: Optional[dict],
    ) -> None:
        pass


class ConversationPendingActionService:
    def __init__(self, memory_service: PendingActionStore) -> None:
        self.memory_service = memory_service

    async def get(self, conversation_id: str) -> Optional[PendingAction]:
        if not conversation_id:
            return None
        getter = getattr(self.memory_service, "get_conversation_pending_action", None)
        if getter is None:
            return None
        raw = await getter(conversation_id)
        return PendingAction.from_dict(raw)

    async def set(self, conversation_id: str, action: PendingAction) -> None:
        if not conversation_id:
            return
        setter = getattr(self.memory_service, "set_conversation_pending_action", None)
        if setter is None:
            return
        await setter(conversation_id, action.to_dict())

    async def clear(self, conversation_id: str) -> None:
        if not conversation_id:
            return
        setter = getattr(self.memory_service, "set_conversation_pending_action", None)
        if setter is None:
            return
        await setter(conversation_id, None)


def is_delete_confirmation_message(message: str) -> bool:
    if is_delete_confirmation_reply(message):
        return True
    normalized = re.sub(r"[^a-z0-9']+", " ", str(message or "").lower())
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized in {
        "yes",
        "yes please",
        "yep",
        "yeah",
        "confirm",
        "confirmed",
        "do it",
        "go ahead",
        "go ahead delete it",
        "delete it",
        "yes delete it",
    }


def is_delete_rejection_message(message: str) -> bool:
    return is_delete_rejection_reply(message)


def should_defer_to_pending_delete(
    message: str,
    *,
    pending_action: Optional[PendingAction],
    conversation_history: list[dict] | None = None,
) -> bool:
    if not is_delete_confirmation_message(message):
        return False
    if pending_action is not None and pending_action.action_type == "delete":
        return True
    if conversation_history:
        return pending_delete_target_from_history(conversation_history) is not None
    return False


def pending_delete_resolver_target(
    *,
    pending_action: Optional[PendingAction],
    conversation_history: list[dict] | None = None,
) -> Optional[str]:
    if pending_action is not None and pending_action.action_type == "delete":
        return pending_action.resolver_target
    if conversation_history:
        return pending_delete_target_from_history(conversation_history)
    return None
