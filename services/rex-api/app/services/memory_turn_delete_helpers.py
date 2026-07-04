import re
from typing import Optional

from app.services.clarity_knowledge_labels import (
    GOAL_SINGULAR,
    SAVED_MEMORY_SINGULAR,
)
from app.services.memory_delete_confirmation_flow import MemoryDeleteConfirmationFlow
from app.services.memory_delete_resolver import (
    ACCOUNTABILITY_DELETE_SCOPE,
    GOAL_DELETE_SCOPE,
)

_ACCOUNTABILITY_SCOPE = frozenset(ACCOUNTABILITY_DELETE_SCOPE)
_GOAL_SCOPE = frozenset(GOAL_DELETE_SCOPE)


class MemoryTurnDeleteHelpers(MemoryDeleteConfirmationFlow):
    async def _ask_delete_confirmation(
        self,
        target: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: Optional[list[dict]] = None,
        scope_tables: tuple[str, ...] = (),
        is_vague: bool = False,
    ) -> dict:
        target = await self._resolved_delete_target(
            target,
            conversation_history=conversation_history or [],
        )
        resolved_scope = scope_tables or self._infer_delete_scope_from_history(
            conversation_history or [],
            target=target,
        )
        matches = await self.memory_correction_service.preview_remove_obsolete(
            target,
            scope_tables=resolved_scope,
            is_vague=is_vague,
        )
        if not matches:
            response = self._delete_not_found_message(resolved_scope)
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
        supersede_note = await self._persist_pending_delete(
            conversation_id,
            target=target,
            match=matches[0],
            scope_tables=resolved_scope,
        )
        response = (
            f"Got it--you want to delete this {self._delete_item_label(matches[0].table)}: "
            f"{title}\n\nJust to confirm before I do that: yes or no?"
        )
        if supersede_note:
            response = f"{supersede_note}\n\n{response}"
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
        scope_tables: tuple[str, ...] = (),
        is_vague: bool = False,
    ) -> dict:
        report = await self.memory_correction_service.apply_confirmed_remove_obsolete(
            target,
            source_conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
            scope_tables=scope_tables,
            is_vague=is_vague,
        )
        await self._clear_pending_delete(conversation_id)
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
        await self._clear_pending_delete(conversation_id)
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

    async def _resolved_delete_target(
        self,
        target: str,
        *,
        conversation_history: list[dict],
    ) -> str:
        if not self._is_contextual_delete_target(target):
            return target

        candidates = self._recent_quoted_saved_items(conversation_history)
        candidates.extend(
            self._recent_accountability_titles_from_history(conversation_history)
        )
        confirmed_targets: list[str] = []
        for candidate in candidates:
            matches = await self.memory_correction_service.preview_remove_obsolete(
                candidate,
                scope_tables=ACCOUNTABILITY_DELETE_SCOPE,
            )
            if len(matches) == 1:
                confirmed_targets.append(candidate)
                continue
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
                    scope_tables=ACCOUNTABILITY_DELETE_SCOPE,
                )
                if len(matches) == 1:
                    confirmed_targets.append(candidate)
                    continue
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

    def _delete_item_label(self, table: str) -> str:
        if table in {"plans", "plan_milestones"}:
            return GOAL_SINGULAR
        return SAVED_MEMORY_SINGULAR

    def _delete_not_found_message(self, scope_tables: tuple[str, ...]) -> str:
        scope = frozenset(scope_tables)
        if scope and scope <= _GOAL_SCOPE:
            label = f"active {GOAL_SINGULAR}"
        elif scope and scope <= _ACCOUNTABILITY_SCOPE:
            label = f"active {GOAL_SINGULAR}"
        else:
            label = f"active {SAVED_MEMORY_SINGULAR}"
        return (
            f"I couldn't find an {label} matching that, so I didn't delete anything."
        )

    def _infer_delete_scope_from_history(
        self,
        conversation_history: list[dict],
        *,
        target: str,
    ) -> tuple[str, ...]:
        if not self._is_contextual_delete_target(target):
            return ()
        for past_message in reversed(conversation_history[-8:]):
            if past_message.get("role") != "assistant":
                continue
            content = str(past_message.get("content") or "").lower()
            if re.search(r"\bgoals?\b", content) and "goals tab" in content:
                return ACCOUNTABILITY_DELETE_SCOPE
        return ()

    def _is_contextual_delete_target(self, target: str) -> bool:
        normalized = self._normalize_delete_text(target)
        if normalized in {
            "it",
            "that",
            "this",
            "that please",
            "this please",
            "it please",
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
        }:
            return True
        return bool(
            re.fullmatch(
                r"(?:that|this|it)(?:\s+please)?",
                normalized,
            )
        )

    def _recent_quoted_saved_items(self, conversation_history: list[dict]) -> list[str]:
        candidates = []
        for past_message in reversed(conversation_history[-8:]):
            if past_message.get("role") != "assistant":
                continue
            content = str(past_message.get("content") or "")
            lowered = content.lower()
            if (
                "saved" not in lowered
                and "clarity knows" not in lowered
                and "goals tab" not in lowered
                and "goal" not in lowered
            ):
                continue
            for match in re.finditer(r"['\"]([^'\"\n]{3,240})['\"]", content):
                candidate = match.group(1).strip()
                if candidate and candidate not in candidates:
                    candidates.append(candidate)
        return candidates

    def _recent_accountability_titles_from_history(
        self,
        conversation_history: list[dict],
    ) -> list[str]:
        candidates: list[str] = []
        for past_message in reversed(conversation_history[-8:]):
            if past_message.get("role") != "assistant":
                continue
            content = str(past_message.get("content") or "")
            lowered = content.lower()
            if not any(
                marker in lowered
                for marker in (
                    "goals tab",
                    "active goals",
                )
            ):
                continue
            for match in re.finditer(
                r"\b(?:called|titled|named)\s+['\"]([^'\"\n]{3,240})['\"]",
                content,
                flags=re.IGNORECASE,
            ):
                candidate = match.group(1).strip()
                if candidate and candidate not in candidates:
                    candidates.append(candidate)
            for match in re.finditer(r"['\"]([^'\"\n]{3,240})['\"]", content):
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
