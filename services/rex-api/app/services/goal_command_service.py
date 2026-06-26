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
            r"\bhold\s+me\s+accountable\s+to\s+(?P<commitment>.+)",
            re.IGNORECASE,
        ),
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
    _plan_timeline_pattern = re.compile(
        r"\b(?:"
        r"(?:my\s+)?(?:next\s+)?checklist\b|"
        r"next\s+month(?:'?s)?\s+(?:purchase|checklist|shopping)\b|"
        r"(?:purchase|shopping)\s+(?:plan|list|checklist)\b|"
        r"plan(?:ned|ning)?\s+(?:for|to)\s+(?:next|this)\s+(?:month|week)"
        r")\b",
        re.IGNORECASE,
    )
    _obligation_action_pattern = re.compile(
        r"\bi\s+(?:need|have)\s+to\s+"
        r"(?P<action>(?:upgrade|install|buy|get|replace|purchase|add|pick\s+up)\b.+)",
        re.IGNORECASE,
    )
    _due_pattern = re.compile(
        r"\b(?:on|by)\s+(?:the\s+)?(?P<date>[A-Za-z]+(?:\s+\d{1,2}(?:st|nd|rd|th)?)?|\d{1,2}(?:st|nd|rd|th)?)\b",
        re.IGNORECASE,
    )
    _relative_time_pattern = re.compile(
        r"\b(?P<relative>(?:next|this)\s+(?:month|week|quarter|year))\b",
        re.IGNORECASE,
    )
    _reclassify_request_pattern = re.compile(
        r"\b(?:"
        r"move\s+(?:it|this|that)\s+(?:from\s+)?memory|"
        r"move\s+from\s+memory|"
        r"remove\s+(?:it|this|that)\s+from\s+(?:saved\s+)?memory|"
        r"(?:this|that)\s+is\s+(?:actually\s+)?(?:a\s+)?(?:goal|commitment)|"
        r"(?:actually|really)\s+(?:a\s+)?(?:goal|commitment)|"
        r"(?:goal|commitment)\s+(?:not|instead\s+of)\s+(?:saved\s+)?memory|"
        r"(?:you|that)\s+saved|"
        r"this\s+that\s+you\s+saved"
        r")\b",
        re.IGNORECASE,
    )
    _clarified_goal_body_pattern = re.compile(
        r"\b(?:meant|meant\s+to|should)\s+(?:be|to)\s+(?P<body>.+)$",
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
        reclassified = await self._try_move_memory_to_goal(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if reclassified is not None:
            return reclassified

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
        future_plan = self._detect_future_plan_goal(
            message,
            time_context=time_context,
        )
        if future_plan is not None:
            return future_plan
        obligation = self._detect_obligation_commitment(
            message,
            time_context=time_context,
        )
        if obligation is not None:
            return obligation
        clarified = self._detect_clarified_misclassified_goal(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if clarified is not None:
            return clarified
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

    def _detect_future_plan_goal(
        self,
        message: str,
        *,
        time_context: dict,
    ) -> Optional[GoalCommand]:
        if self._plan_timeline_pattern.search(message) is None:
            return None

        body = self._extract_obligation_action(message) or self._clean(message)
        if not body or len(body) < 8:
            return None

        target_text = self._relative_date_from_text(
            message
        ) or self._date_from_text(message, time_context=time_context)
        return GoalCommand(
            kind="goal",
            title=self._title(body),
            body=body,
            record_type=self._plan_type(body),
            target_text=target_text,
        )

    def _detect_obligation_commitment(
        self,
        message: str,
        *,
        time_context: dict,
    ) -> Optional[GoalCommand]:
        if self._plan_timeline_pattern.search(message):
            return None

        body = self._extract_obligation_action(message)
        if not body:
            return None

        due_text = self._date_from_text(
            message,
            time_context=time_context,
        ) or self._relative_date_from_text(message)
        return GoalCommand(
            kind="commitment",
            title=self._title(body),
            body=body,
            record_type=self._commitment_type(body),
            due_text=due_text,
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
        response: Optional[str] = None,
        extra_records: Optional[list[dict]] = None,
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
        resolved_response = response or f"Got it, I added this as a goal: {command.title}."
        return await self._command_result(
            conversation_id=conversation_id,
            user_message=user_message,
            response=resolved_response,
            kind="plan",
            record_type=command.record_type,
            record=record,
            title=command.title,
            extra_records=extra_records,
        )

    async def _save_commitment(
        self,
        command: GoalCommand,
        *,
        conversation_id: str,
        user_message: dict,
        response: Optional[str] = None,
        extra_records: Optional[list[dict]] = None,
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
                    priority=5 if command.record_type == "habit" else 4,
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
        resolved_response = (
            response or f"Got it, I saved that commitment: {command.title}."
        )
        return await self._command_result(
            conversation_id=conversation_id,
            user_message=user_message,
            response=resolved_response,
            kind="commitment",
            record_type=command.record_type,
            record=record,
            title=command.title,
            extra_records=extra_records,
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
        extra_records: Optional[list[dict]] = None,
    ) -> dict:
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            response,
        )
        memory_changes = self._summary(
            kind=kind,
            record_type=record_type,
            record=record,
            title=title,
            extra_records=extra_records,
        )
        return {
            "conversation_id": conversation_id,
            "response": response,
            "user_message": user_message,
            "assistant_message": assistant_message,
            "memory_correction": None,
            "memory_changes": memory_changes,
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
        extra_records: Optional[list[dict]] = None,
    ) -> dict:
        source = (
            "explicit_goal_command"
            if kind == "plan"
            else "explicit_commitment_command"
        )
        records = [
            {
                "kind": kind,
                "type": record_type,
                "action": "direct_saved",
                "id": record.get("id"),
                "title": title,
                "metadata": {"source": source},
            }
        ]
        if extra_records:
            records.extend(extra_records)
        archived_count = sum(
            1 for item in records if item.get("action") == "archived"
        )
        return {
            "created": 1,
            "updated": 0,
            "archived": archived_count,
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 0,
            "records": records,
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

    async def _try_move_memory_to_goal(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[dict]:
        if not self._is_memory_reclassification_request(
            message,
            conversation_history=conversation_history,
        ):
            return None

        body = self._reclassified_goal_body(
            message,
            conversation_history=conversation_history,
        )
        if not body:
            return None

        command = self._reclassified_goal_command(
            body,
            message=message,
            time_context=time_context,
        )
        memory = await self._find_memory_to_archive(
            message,
            conversation_history=conversation_history,
        )
        archived_record = None
        if memory is not None:
            archived_record = await self._archive_memory(memory)

        if command.kind == "goal":
            result = await self._save_goal(
                command,
                conversation_id=conversation_id,
                user_message=user_message,
                response=self._reclassification_response(
                    command,
                    archived_record=archived_record,
                ),
                extra_records=self._archived_memory_record(archived_record),
            )
        else:
            result = await self._save_commitment(
                command,
                conversation_id=conversation_id,
                user_message=user_message,
                response=self._reclassification_response(
                    command,
                    archived_record=archived_record,
                ),
                extra_records=self._archived_memory_record(archived_record),
            )
        return result

    def _detect_clarified_misclassified_goal(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[GoalCommand]:
        if not self._clarified_goal_body_pattern.search(message):
            return None
        if not self._conversation_mentions_saved_memory(conversation_history):
            return None

        body = self._reclassified_goal_body(
            message,
            conversation_history=conversation_history,
        )
        if not body:
            return None
        return self._reclassified_goal_command(
            body,
            message=message,
            time_context=time_context,
        )

    def _is_memory_reclassification_request(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> bool:
        if self._reclassify_request_pattern.search(message):
            return True
        if self._clarified_goal_body_pattern.search(message) and (
            self._conversation_mentions_saved_memory(conversation_history)
            or self._reclassify_request_pattern.search(message)
        ):
            return True
        return False

    def _conversation_mentions_saved_memory(
        self,
        conversation_history: list[dict],
    ) -> bool:
        for item in conversation_history[-10:]:
            content = str(item.get("content") or "").lower()
            if any(
                phrase in content
                for phrase in (
                    "you saved",
                    "saved memory",
                    "got it, you have",
                    "got it—you have",
                    "added as a goal",
                    "saved that commitment",
                )
            ):
                return True
        return False

    def _reclassified_goal_body(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[str]:
        match = self._clarified_goal_body_pattern.search(message)
        if match is not None:
            body = self._clean_reclassified_body(match.group("body"))
            if body:
                return body

        obligation = self._extract_obligation_action(message)
        if obligation:
            return self._clean_reclassified_body(obligation)

        for item in reversed(conversation_history[-8:]):
            if item.get("role") != "user":
                continue
            content = str(item.get("content") or "")
            nested = self._clarified_goal_body_pattern.search(content)
            if nested is not None:
                body = self._clean_reclassified_body(nested.group("body"))
                if body:
                    return body
            obligation = self._extract_obligation_action(content)
            if obligation:
                return self._clean_reclassified_body(obligation)
        return None

    def _reclassified_goal_command(
        self,
        body: str,
        *,
        message: str,
        time_context: dict,
    ) -> GoalCommand:
        prefer_goal = bool(
            self._plan_timeline_pattern.search(message)
            or self._relative_time_pattern.search(message)
            or re.search(r"\b(?:purchase|checklist|plan)\b", message, re.I)
        )
        target_text = self._relative_date_from_text(
            message
        ) or self._date_from_text(message, time_context=time_context)
        if prefer_goal:
            return GoalCommand(
                kind="goal",
                title=self._title(body),
                body=body,
                record_type=self._plan_type(body),
                target_text=target_text,
            )
        return GoalCommand(
            kind="commitment",
            title=self._title(body),
            body=body,
            record_type=self._commitment_type(body),
            due_text=target_text,
        )

    async def _find_memory_to_archive(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[dict]:
        list_memories = getattr(self.memory_service, "list_long_term_memory", None)
        if list_memories is None:
            return None

        memories = await list_memories(limit=40, active=True)
        if not memories:
            return None

        terms = self._reclassification_search_terms(message, conversation_history)
        if not terms:
            return None

        best_match = None
        best_score = 0
        for memory in memories:
            content = str(memory.get("content") or "").lower()
            score = sum(1 for term in terms if term in content)
            if score > best_score:
                best_score = score
                best_match = memory
        if best_score < 2 or best_match is None:
            return None
        return best_match

    async def _archive_memory(self, memory: dict) -> Optional[dict]:
        deactivate = getattr(self.memory_service, "deactivate_long_term_memory", None)
        if deactivate is None:
            return None
        memory_id = str(memory.get("id") or "")
        if not memory_id:
            return None
        result = await deactivate(memory_id)
        if isinstance(result, dict):
            return result
        if result is True:
            return {**memory, "active": False}
        return None

    def _reclassification_search_terms(
        self,
        message: str,
        conversation_history: list[dict],
    ) -> set[str]:
        combined = " ".join(
            [message]
            + [str(item.get("content") or "") for item in conversation_history[-8:]]
        ).lower()
        stopwords = {
            "memory",
            "saved",
            "goal",
            "commitment",
            "actually",
            "please",
            "would",
            "meant",
            "this",
            "that",
            "you",
            "have",
            "from",
            "could",
            "move",
        }
        terms = {
            word
            for word in re.findall(r"[a-z0-9]{3,}", combined)
            if word not in stopwords
        }
        for token in (
            "ram",
            "upgrade",
            "storage",
            "terabyte",
            "terab",
            "32gb",
            "64gb",
            "ssd",
        ):
            if token in combined:
                terms.add(token)
        return terms

    def _clean_reclassified_body(self, value: str) -> str:
        cleaned = self._clean(value)
        cleaned = re.sub(r"\b(\d+)\s*to\b", r"\1GB to", cleaned, flags=re.I)
        cleaned = re.sub(r"\b(\d+)\s*or\b", r"\1GB or", cleaned, flags=re.I)
        cleaned = re.sub(r"\bterab\b", "TB", cleaned, flags=re.I)
        cleaned = re.sub(r"\b1terab\b", "1TB", cleaned, flags=re.I)
        cleaned = re.sub(r"\b2terab\b", "2TB", cleaned, flags=re.I)
        return cleaned.strip(" .")

    def _reclassification_response(
        self,
        command: GoalCommand,
        *,
        archived_record: Optional[dict],
    ) -> Optional[str]:
        if archived_record is None:
            return None
        kind_label = "goal" if command.kind == "goal" else "commitment"
        return (
            f"Got it, I removed that from saved memory and added it as a "
            f"{kind_label}: {command.title}."
        )

    def _archived_memory_record(
        self,
        archived_record: Optional[dict],
    ) -> Optional[list[dict]]:
        if archived_record is None:
            return None
        return [
            {
                "kind": "long_term_memory",
                "type": archived_record.get("memory_type") or "fact",
                "action": "archived",
                "id": archived_record.get("id"),
                "title": str(archived_record.get("content") or "")[:80],
                "metadata": {"source": "memory_to_goal_reclassification"},
            }
        ]

    def _extract_obligation_action(self, message: str) -> Optional[str]:
        match = self._obligation_action_pattern.search(message)
        if match is None:
            return None
        return self._clean(match.group("action"))

    def _relative_date_from_text(self, text: str) -> Optional[str]:
        match = self._relative_time_pattern.search(text)
        if match is None:
            return None
        relative = match.group("relative")
        return relative[:1].upper() + relative[1:].lower()

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
        if any(
            term in lowered
            for term in ("wake up", "5 am", "5:00", "morning routine")
        ):
            return "habit"
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
