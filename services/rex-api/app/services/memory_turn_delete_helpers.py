import re
from typing import Optional

from app.services.memory_correction_types import CorrectionIntentType


class MemoryTurnDeleteHelpers:
    async def _ask_delete_confirmation(
        self,
        target: str,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        matches = await self.memory_correction_service.preview_remove_obsolete(target)
        if not matches:
            response = (
                "I couldn't find an active saved memory matching that, so I "
                "didn't delete anything."
            )
            return await self._delete_turn_result(
                response,
                conversation_id=conversation_id,
                user_message=user_message,
                memory_changes=self._delete_not_found_summary(target),
            )
        if len(matches) > 1:
            response = (
                "I found multiple active saved items that could match. I didn't "
                "delete anything. Tell me the exact saved item to delete."
            )
            return await self._delete_turn_result(
                response,
                conversation_id=conversation_id,
                user_message=user_message,
                memory_changes=self._delete_ambiguous_summary(target, matches),
            )

        title = matches[0].title or target
        response = (
            f"Got it--you want to delete this saved memory: {title}\n\n"
            "Just to confirm before I do that: yes or no?"
        )
        return await self._delete_turn_result(
            response,
            conversation_id=conversation_id,
            user_message=user_message,
            memory_changes=self._delete_confirmation_summary(target, matches[0]),
        )

    async def _apply_confirmed_delete(
        self,
        target: str,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        report = await self.memory_correction_service.apply_confirmed_remove_obsolete(
            target,
            source_conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )
        if not report.applied or not report.affected_records:
            response = (
                "I couldn't confirm that delete in saved memory, so I didn't "
                "claim it was deleted."
            )
            return await self._delete_turn_result(
                response,
                conversation_id=conversation_id,
                user_message=user_message,
                memory_changes=self._delete_failed_summary(target, report.as_dict()),
            )

        title = report.affected_records[0].title or target
        response = (
            "Done--that saved memory has been removed from active saved memory: "
            f"{title}"
        )
        return await self._delete_turn_result(
            response,
            conversation_id=conversation_id,
            user_message=user_message,
            memory_changes=self._delete_archived_summary(report.affected_records),
        )

    async def _reject_confirmed_delete(
        self,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        response = "No problem. I won't delete anything."
        return await self._delete_turn_result(
            response,
            conversation_id=conversation_id,
            user_message=user_message,
            memory_changes=self._delete_rejected_summary(),
        )

    async def _delete_turn_result(
        self,
        response: str,
        *,
        conversation_id: str,
        user_message: dict,
        memory_changes: dict,
    ) -> dict:
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            response,
        )
        return {
            "conversation_id": conversation_id,
            "response": response,
            "user_message": user_message,
            "assistant_message": self.public_message(assistant_message),
            "memory_correction": None,
            "memory_changes": memory_changes,
            "messages": await self.recent_public_messages(conversation_id),
        }

    def _pending_delete_request_for_confirmation(
        self,
        message: str,
        conversation_history: list[dict],
    ) -> Optional[str]:
        if not (
            self._is_delete_confirmation(message)
            or self._is_delete_rejection(message)
        ):
            return None

        saw_delete_confirmation = False
        for past_message in reversed(conversation_history[-8:]):
            role = past_message.get("role")
            content = str(past_message.get("content") or "")
            if role == "assistant" and self._looks_like_delete_confirmation(content):
                saw_delete_confirmation = True
                continue
            if saw_delete_confirmation and role == "user":
                intent = self.memory_correction_service.detect_correction_intent(
                    content,
                )
                if (
                    intent.intent_type == CorrectionIntentType.REMOVE_OBSOLETE
                    and intent.old_value
                ):
                    return intent.old_value
        return None

    def _looks_like_delete_confirmation(self, message: str) -> bool:
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
