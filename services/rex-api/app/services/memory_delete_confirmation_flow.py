import re
from typing import Optional

from app.services.conversation_pending_action import (
    ConversationPendingActionService,
    is_delete_confirmation_message,
    is_delete_rejection_message,
    pending_action_for_delete,
    pending_delete_resolver_target,
)
from app.services.memory_correction_types import CorrectionIntentType


class MemoryDeleteConfirmationFlow:
    def _pending_action_service(self) -> ConversationPendingActionService:
        return ConversationPendingActionService(self.memory_service)

    async def _persist_pending_delete(
        self,
        conversation_id: str,
        *,
        target: str,
        match,
        scope_tables: tuple[str, ...] = (),
    ) -> Optional[str]:
        return await self._pending_action_service().set_superseding(
            conversation_id,
            pending_action_for_delete(
                target=target,
                match=match,
                scope_tables=scope_tables,
            ),
        )

    async def _clear_pending_delete(self, conversation_id: str) -> None:
        await self._pending_action_service().clear(conversation_id)

    def _pending_delete_request_for_confirmation(
        self,
        message: str,
        conversation_history: list[dict],
        pending_action=None,
    ) -> Optional[str]:
        from app.services.conversation_pending_action import PendingAction
        from app.services.memory_delete_reference import (
            extract_delete_target_from_assistant_prompt,
            pending_delete_target_from_history,
        )

        if not (
            is_delete_confirmation_message(message)
            or is_delete_rejection_message(message)
        ):
            return None

        resolved = (
            pending_action
            if isinstance(pending_action, PendingAction)
            else PendingAction.from_dict(pending_action)
        )
        resolver_target = pending_delete_resolver_target(
            pending_action=resolved,
            conversation_history=conversation_history,
        )
        if resolver_target and is_delete_confirmation_message(message):
            return resolver_target

        pending_target = pending_delete_target_from_history(conversation_history)
        if pending_target and is_delete_confirmation_message(message):
            return pending_target

        saw_delete_confirmation = False
        confirmation_target: Optional[str] = None
        for past_message in reversed(conversation_history[-8:]):
            role = past_message.get("role")
            content = str(past_message.get("content") or "")
            if role == "assistant" and (
                self._looks_like_delete_confirmation(content)
                or extract_delete_target_from_assistant_prompt(content)
            ):
                saw_delete_confirmation = True
                confirmation_target = (
                    self._delete_confirmation_target(content)
                    or extract_delete_target_from_assistant_prompt(content)
                )
                continue
            if saw_delete_confirmation and role == "user":
                intent = self.memory_correction_service.detect_correction_intent(
                    content,
                )
                if (
                    intent.intent_type == CorrectionIntentType.REMOVE_OBSOLETE
                    and intent.old_value
                ):
                    return confirmation_target or intent.old_value
        if resolved and is_delete_rejection_message(message):
            return resolved.resolver_target
        return None

    def _looks_like_delete_confirmation(self, message: str) -> bool:
        from app.services.memory_delete_reference import assistant_prompts_delete

        if assistant_prompts_delete(message):
            return True
        normalized = self._normalize_delete_text(message)
        return (
            "confirm" in normalized
            and ("delete" in normalized or "remove" in normalized)
            and "saved" in normalized
        )

    def _is_delete_confirmation(self, message: str) -> bool:
        normalized = self._normalize_delete_text(message)
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

    def _is_delete_rejection(self, message: str) -> bool:
        normalized = self._normalize_delete_text(message)
        return normalized in {"no", "nope", "cancel", "do not", "dont", "don't"}

    def _normalize_delete_text(self, message: str) -> str:
        normalized = re.sub(r"[^a-z0-9']+", " ", str(message or "").lower())
        return re.sub(r"\s+", " ", normalized).strip()

    def _delete_confirmation_target(self, message: str) -> Optional[str]:
        from app.services.memory_delete_reference import (
            extract_delete_target_from_assistant_prompt,
        )

        target = extract_delete_target_from_assistant_prompt(message)
        if target:
            return target
        match = re.search(
            r"delete this saved memory:\s*(.+?)(?:\n|$)",
            message,
            flags=re.IGNORECASE,
        )
        if match is None:
            return None
        target = match.group(1).strip()
        return target or None
