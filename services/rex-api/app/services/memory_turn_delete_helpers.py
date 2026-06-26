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
        conversation_history: Optional[list[dict]] = None,
    ) -> dict:
        target = await self._resolved_delete_target(
            target,
            conversation_history=conversation_history or [],
        )
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

    async def _ask_delete_specifics(
        self,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        response = (
            "Tell me the exact saved item to delete—for example, its title or "
            "the words it starts with."
        )
        return await self._delete_turn_result(
            response,
            conversation_id=conversation_id,
            user_message=user_message,
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
        from app.services.memory_delete_reference import (
            extract_delete_target_from_assistant_prompt,
            is_delete_confirmation_reply,
            pending_delete_target_from_history,
        )

        if not (
            self._is_delete_confirmation(message)
            or self._is_delete_rejection(message)
            or is_delete_confirmation_reply(message)
        ):
            return None

        pending_target = pending_delete_target_from_history(conversation_history)
        if pending_target and self._is_delete_confirmation(message):
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

    async def _resolved_delete_target(
        self,
        target: str,
        *,
        conversation_history: list[dict],
    ) -> str:
        if not self._is_contextual_delete_target(target):
            return target

        candidates = self._recent_quoted_saved_items(conversation_history)
        confirmed_targets: list[str] = []
        for candidate in candidates:
            matches = await self.memory_correction_service.preview_remove_obsolete(
                candidate,
            )
            if len(matches) == 1:
                confirmed_targets.append(candidate)

        if not confirmed_targets:
            for candidate in self._recent_delete_reference_candidates(
                conversation_history,
            ):
                matches = await self.memory_correction_service.preview_remove_obsolete(
                    candidate,
                )
                if len(matches) == 1:
                    confirmed_targets.append(candidate)

        unique_targets = []
        for candidate in confirmed_targets:
            if candidate not in unique_targets:
                unique_targets.append(candidate)
        return unique_targets[0] if len(unique_targets) == 1 else target

    def _is_contextual_delete_target(self, target: str) -> bool:
        normalized = self._normalize_delete_text(target)
        return normalized in {
            "it",
            "that",
            "this",
            "that memory",
            "this memory",
            "that saved memory",
            "this saved memory",
            "that event",
            "this event",
            "that event memory",
            "this event memory",
            "that note",
            "this note",
            "that saved note",
            "this saved note",
            "the old one",
            "old one",
            "the old goal",
            "old goal",
        }

    def _recent_quoted_saved_items(self, conversation_history: list[dict]) -> list[str]:
        candidates = []
        for past_message in reversed(conversation_history[-8:]):
            if past_message.get("role") != "assistant":
                continue
            content = str(past_message.get("content") or "")
            lowered = content.lower()
            if "saved" not in lowered and "clarity knows" not in lowered:
                continue
            for match in re.finditer(r'"([^"\n]{3,240})"', content):
                candidate = match.group(1).strip()
                if candidate and candidate not in candidates:
                    candidates.append(candidate)
        return candidates

    def _recent_delete_reference_candidates(
        self,
        conversation_history: list[dict],
    ) -> list[str]:
        candidates: list[str] = []
        for past_message in reversed(conversation_history[-8:]):
            content = str(past_message.get("content") or "")
            lowered = content.lower()
            if "delete" not in lowered and "remove" not in lowered:
                continue
            for match in re.finditer(r"['\"]([^'\n\"]{3,240})['\"]", content):
                candidate = match.group(1).strip()
                if candidate and candidate not in candidates:
                    candidates.append(candidate)
            for match in re.finditer(
                r"\b(?:starting as|old one|be a goal)\s+['\"]?([^'\n\"]{3,240})['\"]?",
                content,
                flags=re.IGNORECASE,
            ):
                candidate = match.group(1).strip(" .")
                if candidate and candidate not in candidates:
                    candidates.append(candidate)
        return candidates

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
