"""Propose durable delete confirmation cards for saved memory, goals, and threads."""

from __future__ import annotations

from typing import Any, Optional

from app.services.conversation_pending_action import PendingAction
from app.services.durable_write_builders import proposal_from_record_delete
from app.services.goal_command_results import clarification_turn_result
from app.services.memory_correction_types import CorrectionIntentType
from app.services.memory_delete_reference import is_vague_delete_target
from app.services.memory_delete_resolver import (
    ParsedDeleteRequest,
    parse_delete_request,
)
from app.services.memory_turn_delete_helpers import MemoryTurnDeleteHelpers


class MemoryDeleteTurnService:
    def __init__(
        self,
        memory_service: Any,
        *,
        memory_correction_service=None,
        durable_write_service=None,
    ) -> None:
        self.memory_service = memory_service
        self.memory_correction_service = memory_correction_service
        self.durable_write_service = durable_write_service

    async def handle_turn(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        pending_action=None,
    ) -> Optional[dict]:
        if self.memory_correction_service is None or self.durable_write_service is None:
            return None
        if self._has_non_durable_pending(pending_action):
            return None

        parsed = self._parse_delete_request(message)
        if parsed is None:
            return None

        if parsed.is_vague or is_vague_delete_target(parsed.reference):
            return await self._ask_delete_specifics(
                conversation_id=conversation_id,
                user_message=user_message,
            )

        reference, scope_tables = await self._resolve_delete_target(
            parsed,
            conversation_history=conversation_history or [],
        )
        if is_vague_delete_target(reference):
            return await self._ask_delete_specifics(
                conversation_id=conversation_id,
                user_message=user_message,
            )

        matches = await self.memory_correction_service.preview_remove_obsolete(
            reference,
            scope_tables=scope_tables,
            is_vague=False,
        )
        if not matches:
            return await self._delete_not_found(
                parsed,
                conversation_id=conversation_id,
                user_message=user_message,
            )
        if len(matches) > 1:
            return await self._delete_ambiguous(
                conversation_id=conversation_id,
                user_message=user_message,
            )

        proposal = proposal_from_record_delete(
            matches[0],
            resolver_target=reference,
            scope_tables=scope_tables,
        )
        return await self.durable_write_service._propose(
            proposal,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_messages=conversation_history,
        )

    def _parse_delete_request(self, message: str) -> Optional[ParsedDeleteRequest]:
        parsed = parse_delete_request(message)
        if parsed is not None:
            return parsed
        intent = self.memory_correction_service.detect_correction_intent(message)
        if (
            intent.intent_type != CorrectionIntentType.REMOVE_OBSOLETE
            or not intent.old_value
        ):
            return None
        return ParsedDeleteRequest(
            reference=intent.old_value,
            scope_tables=intent.delete_scope_tables,
            is_vague=intent.is_vague_delete_reference,
        )

    def _has_non_durable_pending(self, pending_action) -> bool:
        pending = (
            pending_action
            if isinstance(pending_action, PendingAction)
            else PendingAction.from_dict(pending_action)
        )
        if pending is None:
            return False
        return pending.action_type != "durable_write"

    async def _ask_delete_specifics(
        self,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=(
                "Tell me the exact saved item to delete—for example, its title or "
                "the words it starts with."
            ),
            memory_changes={
                "created": 0,
                "updated": 0,
                "archived": 0,
                "merged": 0,
                "skipped": 0,
                "confirmation_required": 0,
                "records": [],
            },
        )

    async def _delete_not_found(
        self,
        parsed: ParsedDeleteRequest,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        label = "active saved item"
        if parsed.scope_tables == ("plans", "plan_milestones"):
            label = "active goal"
        elif parsed.scope_tables == ("open_threads",):
            label = "open thread"
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=(
                f"I couldn't find an {label} matching that, so I didn't delete anything."
            ),
            memory_changes={
                "created": 0,
                "updated": 0,
                "archived": 0,
                "merged": 0,
                "skipped": 1,
                "confirmation_required": 0,
                "records": [],
            },
        )

    async def _resolve_delete_target(
        self,
        parsed: ParsedDeleteRequest,
        *,
        conversation_history: list[dict],
    ) -> tuple[str, tuple[str, ...]]:
        resolver = _DeleteReferenceResolver(
            self.memory_service,
            self.memory_correction_service,
        )
        reference = await resolver._resolved_delete_target(
            parsed.reference,
            conversation_history=conversation_history,
        )
        scope_tables = parsed.scope_tables
        if not scope_tables:
            scope_tables = resolver._infer_delete_scope_from_history(
                conversation_history,
                target=reference,
            )
        return reference, scope_tables

    async def _delete_ambiguous(
        self,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=(
                "I found multiple active saved items that could match. I didn't "
                "delete anything. Tell me the exact saved item to delete."
            ),
            memory_changes={
                "created": 0,
                "updated": 0,
                "archived": 0,
                "merged": 0,
                "skipped": 1,
                "confirmation_required": 0,
                "records": [],
            },
        )


class _DeleteReferenceResolver(MemoryTurnDeleteHelpers):
    def __init__(self, memory_service, memory_correction_service) -> None:
        self.memory_service = memory_service
        self.memory_correction_service = memory_correction_service
