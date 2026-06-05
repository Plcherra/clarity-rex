from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Optional, Protocol

from app.models.commitment import CommitmentCreateRequest
from app.models.plan import PlanCreateRequest
from app.services.commitment_service import CommitmentService
from app.services.memory_date_normalizer import MemoryDateNormalizer
from app.services.plan_service import PlanService


class GoalCommandStore(Protocol):
    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        pass

    async def get_recent_messages(
        self,
        conversation_id: str,
        limit: int = 20,
    ) -> list[dict]:
        pass


@dataclass(frozen=True)
class GoalCommand:
    kind: str
    title: str
    body: str
    record_type: str
    due_text: Optional[str] = None
    target_text: Optional[str] = None


class GoalCommandService:
    """Handles explicit goal and commitment commands without an LLM call."""

    _contextual_goal_pattern = re.compile(
        r"\b(?:track|save|add)\s+this\s+as\s+(?:a\s+)?goal\b",
        re.IGNORECASE,
    )
    _inline_goal_patterns = (
        re.compile(
            r"\b(?:track|save|add)\s+(?P<goal>.+?)\s+as\s+(?:a\s+)?goal\b",
            re.IGNORECASE,
        ),
        re.compile(
            r"\bmy\s+goal\s+is\s+(?P<goal>.+)",
            re.IGNORECASE,
        ),
    )
    _commitment_patterns = (
        re.compile(
            r"\b(?:remind|remember)\s+me\s+to\s+(?P<commitment>.+)",
            re.IGNORECASE,
        ),
        re.compile(
            r"\b(?:set|create|add)\s+(?:a\s+)?reminder\s+to\s+(?P<commitment>.+)",
            re.IGNORECASE,
        ),
        re.compile(
            r"\bi\s+(?:need|have)\s+to\s+(?P<commitment>.+?\b(?:on|by)\b.+)",
            re.IGNORECASE,
        ),
        re.compile(
            r"\bi\s+gotta\s+(?P<commitment>.+?\b(?:on|by)\b.+)",
            re.IGNORECASE,
        ),
        re.compile(
            r"\b(?:track|save|add)\s+(?P<commitment>.+?)\s+as\s+(?:a\s+)?commitment\b",
            re.IGNORECASE,
        ),
    )
    _due_pattern = re.compile(
        r"\b(?:on|by)\s+(?:the\s+)?(?P<date>[A-Za-z]+(?:\s+\d{1,2}(?:st|nd|rd|th)?)?|\d{1,2}(?:st|nd|rd|th)?)\b",
        re.IGNORECASE,
    )
    _date_normalizer = MemoryDateNormalizer()

    def __init__(
        self,
        memory_service: Any,
        *,
        plan_service: Optional[PlanService] = None,
        commitment_service: Optional[CommitmentService] = None,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)
        self.commitment_service = commitment_service or CommitmentService(
            memory_service
        )

    async def handle_turn(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[dict]:
        command = self.detect_command(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if command is None:
            return None

        if command.kind == "goal":
            return await self._save_goal(
                command,
                conversation_id=conversation_id,
                user_message=user_message,
            )
        return await self._save_commitment(
            command,
            conversation_id=conversation_id,
            user_message=user_message,
        )

    def detect_command(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[GoalCommand]:
        commitment = self._detect_commitment(message, time_context=time_context)
        if commitment is not None:
            return commitment
        return self._detect_goal(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )

    def _detect_goal(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[GoalCommand]:
        goal_text = None
        if self._contextual_goal_pattern.search(message):
            goal_text = self._recent_user_content(conversation_history)
        else:
            for pattern in self._inline_goal_patterns:
                match = pattern.search(message)
                if match:
                    goal_text = match.group("goal")
                    break
        goal_text = self._clean(goal_text)
        if not goal_text:
            return None

        target_text = self._date_from_text(goal_text, time_context=time_context)
        return GoalCommand(
            kind="goal",
            title=self._title(goal_text),
            body=goal_text,
            record_type=self._plan_type(goal_text),
            target_text=target_text,
        )

    def _detect_commitment(
        self,
        message: str,
        *,
        time_context: dict,
    ) -> Optional[GoalCommand]:
        commitment_text = None
        for pattern in self._commitment_patterns:
            match = pattern.search(message)
            if match:
                commitment_text = match.group("commitment")
                break
        commitment_text = self._clean(commitment_text)
        if not commitment_text:
            return None

        due_text = self._date_from_text(commitment_text, time_context=time_context)
        return GoalCommand(
            kind="commitment",
            title=self._title(commitment_text),
            body=commitment_text,
            record_type=self._commitment_type(commitment_text),
            due_text=due_text,
        )

    async def _save_goal(
        self,
        command: GoalCommand,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        try:
            record = await self.plan_service.create_plan(
                PlanCreateRequest(
                    plan_type=command.record_type,
                    title=command.title,
                    description=command.body,
                    desired_outcome=command.body,
                    source_conversation_id=conversation_id,
                    source_message_id=str(user_message.get("id") or "") or None,
                    target_date=command.target_text,
                    priority=4,
                    metadata={"source": "explicit_goal_command"},
                )
            )
        except Exception:
            return await self._failed_command_result(
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I understood that goal, but I couldn't save it just now. "
                    "Please try again in a moment."
                ),
                kind="plan",
                record_type=command.record_type,
                title=command.title,
            )
        response = f"Got it, I added this as a goal: {command.title}."
        return await self._command_result(
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            kind="plan",
            record_type=command.record_type,
            record=record,
            title=command.title,
        )

    async def _save_commitment(
        self,
        command: GoalCommand,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict:
        try:
            record = await self.commitment_service.create_commitment(
                CommitmentCreateRequest(
                    commitment_type=command.record_type,
                    title=command.title,
                    commitment_text=command.body,
                    source_conversation_id=conversation_id,
                    source_message_id=str(user_message.get("id") or "") or None,
                    due_at=command.due_text,
                    priority=4,
                    metadata={"source": "explicit_commitment_command"},
                )
            )
        except Exception:
            return await self._failed_command_result(
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I understood that commitment, but I couldn't save it just now. "
                    "Please try again in a moment."
                ),
                kind="commitment",
                record_type=command.record_type,
                title=command.title,
            )
        response = f"Got it, I saved that commitment: {command.title}."
        return await self._command_result(
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            kind="commitment",
            record_type=command.record_type,
            record=record,
            title=command.title,
        )

    async def _command_result(
        self,
        *,
        conversation_id: str,
        user_message: dict,
        response: str,
        kind: str,
        record_type: str,
        record: dict,
        title: str,
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
            "assistant_message": assistant_message,
            "memory_correction": None,
            "memory_changes": self._summary(
                kind=kind,
                record_type=record_type,
                record=record,
                title=title,
            ),
            "messages": await self.memory_service.get_recent_messages(
                conversation_id,
                limit=20,
            ),
        }

    async def _failed_command_result(
        self,
        *,
        conversation_id: str,
        user_message: dict,
        response: str,
        kind: str,
        record_type: str,
        title: str,
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
            "assistant_message": assistant_message,
            "memory_correction": None,
            "memory_changes": self._failed_summary(
                kind=kind,
                record_type=record_type,
                title=title,
            ),
            "messages": await self.memory_service.get_recent_messages(
                conversation_id,
                limit=20,
            ),
        }

    def _summary(
        self,
        *,
        kind: str,
        record_type: str,
        record: dict,
        title: str,
    ) -> dict:
        source = (
            "explicit_goal_command"
            if kind == "plan"
            else "explicit_commitment_command"
        )
        return {
            "created": 1,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": kind,
                    "type": record_type,
                    "action": "direct_saved",
                    "id": record.get("id"),
                    "title": title,
                    "metadata": {"source": source},
                }
            ],
        }

    def _failed_summary(
        self,
        *,
        kind: str,
        record_type: str,
        title: str,
    ) -> dict:
        return {
            "created": 0,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 1,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": kind,
                    "type": record_type,
                    "action": "save_failed",
                    "title": title,
                    "metadata": {"source": "explicit_command", "degraded": True},
                }
            ],
        }

    def _recent_user_content(self, conversation_history: list[dict]) -> Optional[str]:
        for message in reversed(conversation_history):
            if message.get("role") == "user":
                return str(message.get("content") or "")
        return None

    def _date_from_text(self, text: str, *, time_context: dict) -> Optional[str]:
        match = self._due_pattern.search(text)
        if not match:
            return None
        return self._date_normalizer.normalize(
            match.group("date"),
            time_context=time_context,
        )

    def _plan_type(self, text: str) -> str:
        lowered = text.casefold()
        if any(term in lowered for term in ("save", "$", "money", "budget")):
            return "finance"
        if any(term in lowered for term in ("work", "job", "career")):
            return "career"
        if any(term in lowered for term in ("health", "gym", "work out")):
            return "health"
        return "personal"

    def _commitment_type(self, text: str) -> str:
        lowered = text.casefold()
        if any(term in lowered for term in ("$", "send money", "pay", "money", "rent")):
            return "money"
        if any(term in lowered for term in ("work", "job", "email")):
            return "work"
        if any(term in lowered for term in ("gym", "work out", "doctor")):
            return "health"
        if any(term in lowered for term in ("mom", "dad", "friend", "call")):
            return "relationship"
        return "task"

    def _title(self, text: str) -> str:
        cleaned = self._clean(text) or "Untitled"
        return cleaned[:1].upper() + cleaned[1:]

    def _clean(self, value: Any) -> str:
        cleaned = re.sub(r"\s+", " ", str(value or "")).strip(" .")
        return cleaned
