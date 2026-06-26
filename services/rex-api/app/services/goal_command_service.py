from __future__ import annotations

import re
from typing import Any, Optional

from app.models.commitment import CommitmentCreateRequest
from app.models.plan import PlanCreateRequest
from app.services.accountability_query_service import AccountabilityQueryService
from app.services.commitment_service import CommitmentService
from app.services.goal_command_parsing import (
    is_affirmation_or_goal_prefix,
    is_meta_instruction_body,
    looks_like_equipment_goal,
    normalize_equipment_goal_title,
    split_compound_goal_bodies,
    substantive_goal_from_history,
    target_date_for_message,
)
from app.services.goal_command_queries import try_list_goals_and_commitments
from app.services.goal_command_results import (
    clarification_turn_result,
    command_turn_result,
    failed_command_turn_result,
    multi_goal_turn_result,
    read_only_turn_result,
)
from app.services.goal_command_types import GoalCommand, GoalCommandStore
from app.services.memory_delete_reference import should_defer_to_delete_confirmation
from app.services.memory_date_normalizer import MemoryDateNormalizer
from app.services.plan_service import PlanService


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
        r"move\s+or\s+delete\s+(?:it|this|that)\s+from\s+(?:saved\s+)?memory|"
        r"move\s+from\s+memory|"
        r"remove\s+(?:it|this|that)\s+from\s+(?:saved\s+)?memory|"
        r"delete\s+(?:it|this|that)\s+from\s+(?:saved\s+)?memory|"
        r"(?:this|that)\s+is\s+(?:actually\s+)?(?:a\s+)?(?:goal|commitment)|"
        r"(?:actually|really)\s+(?:a\s+)?(?:goal|commitment)|"
        r"(?:goal|commitment)\s+(?:not|instead\s+of)\s+(?:saved\s+)?memory|"
        r"(?:you|that)\s+saved|"
        r"this\s+that\s+you\s+saved"
        r")\b",
        re.IGNORECASE,
    )
    _clarified_goal_body_pattern = re.compile(
        r"\b(?:meant\s+to\s+be|should\s+be|was\s+supposed\s+to\s+be)\s+(?P<body>.+)$",
        re.IGNORECASE,
    )
    _date_normalizer = MemoryDateNormalizer()

    def __init__(
        self,
        memory_service: Any,
        *,
        plan_service: Optional[PlanService] = None,
        commitment_service: Optional[CommitmentService] = None,
        accountability_query_service: Optional[AccountabilityQueryService] = None,
    ) -> None:
        self.memory_service = memory_service
        self.plan_service = plan_service or PlanService(memory_service)
        self.commitment_service = commitment_service or CommitmentService(
            memory_service
        )
        self.accountability_query_service = (
            accountability_query_service
            or AccountabilityQueryService(memory_service)
        )

    async def handle_turn(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        time_context: dict,
        pending_action=None,
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

        listed = await self._try_list_goals_and_commitments(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
        )
        if listed is not None:
            return listed

        if should_defer_to_delete_confirmation(
            message,
            conversation_history,
            self._pending_action_payload(pending_action),
        ):
            return None

        commands = self.detect_commands(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
            pending_action=pending_action,
        )
        if not commands:
            return None

        if len(commands) == 1:
            command = commands[0]
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
        return await self._save_multiple_goals(
            commands,
            conversation_id=conversation_id,
            user_message=user_message,
        )

    async def _try_list_goals_and_commitments(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> Optional[dict]:
        return await try_list_goals_and_commitments(
            message,
            conversation_id=conversation_id,
            user_message=user_message,
            accountability_query_service=self.accountability_query_service,
            memory_service=self.memory_service,
        )

    @staticmethod
    def _pending_action_payload(pending_action) -> dict | None:
        if pending_action is None:
            return None
        to_dict = getattr(pending_action, "to_dict", None)
        if callable(to_dict):
            return to_dict()
        if isinstance(pending_action, dict):
            return pending_action
        return None

    async def _read_only_result(
        self,
        *,
        conversation_id: str,
        user_message: dict,
        response: str,
    ) -> dict:
        return await read_only_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
        )

    def detect_commands(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
        pending_action=None,
    ) -> list[GoalCommand]:
        equipment_goals = self._detect_equipment_goals(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if equipment_goals:
            return equipment_goals

        if is_affirmation_or_goal_prefix(message):
            if should_defer_to_delete_confirmation(
                message,
                conversation_history,
                self._pending_action_payload(pending_action),
            ):
                return []
            substantive = substantive_goal_from_history(conversation_history)
            if substantive:
                affirmed = self._goal_commands_from_text(
                    substantive,
                    message=message,
                    conversation_history=conversation_history,
                    time_context=time_context,
                )
                if affirmed:
                    return affirmed

        command = self.detect_command(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        return [command] if command is not None else []

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
            message,
            time_context=time_context,
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
        ) or self._relative_date_from_text(message, time_context=time_context)
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

    def _detect_equipment_goals(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
    ) -> list[GoalCommand]:
        items = split_compound_goal_bodies(message)
        if not items:
            return []
        return self._goal_commands_from_items(
            items,
            message=message,
            conversation_history=conversation_history,
            time_context=time_context,
        )

    def _goal_commands_from_text(
        self,
        text: str,
        *,
        message: str,
        conversation_history: list[dict],
        time_context: dict,
    ) -> list[GoalCommand]:
        items = split_compound_goal_bodies(text)
        if not items and looks_like_equipment_goal(text):
            items = [normalize_equipment_goal_title(text)]
        if not items:
            return []
        return self._goal_commands_from_items(
            items,
            message=f"{message} {text}",
            conversation_history=conversation_history,
            time_context=time_context,
        )

    def _goal_commands_from_items(
        self,
        items: list[str],
        *,
        message: str,
        conversation_history: list[dict],
        time_context: dict,
    ) -> list[GoalCommand]:
        combined = self._combined_recent_text(message, conversation_history)
        target_text = target_date_for_message(
            combined,
            time_context=time_context,
        ) or self._relative_date_from_text(
            combined,
            time_context=time_context,
        ) or self._date_from_text(combined, time_context=time_context)
        return [
            GoalCommand(
                kind="goal",
                title=item,
                body=item,
                record_type=self._plan_type(item),
                target_text=target_text,
            )
            for item in items
        ]

    async def _save_multiple_goals(
        self,
        commands: list[GoalCommand],
        *,
        conversation_id: str,
        user_message: dict,
        response: Optional[str] = None,
        extra_records: Optional[list[dict]] = None,
    ) -> dict:
        saved_records: list[dict] = []
        for command in commands:
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
                        "I understood those goals, but I couldn't save them just now. "
                        "Please try again in a moment."
                    ),
                    kind="plan",
                    record_type=commands[0].record_type,
                    title=commands[0].title,
                )
            saved_records.append(record)

        if response is None:
            titles = ", ".join(command.title for command in commands)
            response = f"Got it, I added {len(commands)} goals: {titles}."
        return await self._multi_goal_result(
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            commands=commands,
            records=saved_records,
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

    async def _multi_goal_result(
        self,
        *,
        conversation_id: str,
        user_message: dict,
        response: str,
        commands: list[GoalCommand],
        records: list[dict],
        extra_records: Optional[list[dict]] = None,
    ) -> dict:
        return await multi_goal_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            commands=commands,
            records=records,
            extra_records=extra_records,
        )

    async def _clarification_result(
        self,
        *,
        conversation_id: str,
        user_message: dict,
        response: str,
    ) -> dict:
        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
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
        return await command_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            kind=kind,
            record_type=record_type,
            record=record,
            title=title,
            extra_records=extra_records,
        )

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
        return await failed_command_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            kind=kind,
            record_type=record_type,
            title=title,
        )

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
        commands = self._reclassified_goal_commands(
            body,
            message=message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if not commands:
            return await self._clarification_result(
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "I can move that out of saved memory once I know the exact goal. "
                    "Tell me what to track—for example, separate goals for RAM and "
                    "storage with a deadline like next month."
                ),
            )

        memory = await self._find_memory_to_archive(
            message,
            conversation_history=conversation_history,
        )
        archived_record = None
        if memory is not None:
            archived_record = await self._archive_memory(memory)

        extra_records = self._archived_memory_record(archived_record)
        if len(commands) == 1:
            command = commands[0]
            response = self._reclassification_response(
                command,
                archived_record=archived_record,
                total_goals=1,
            )
            if command.kind == "goal":
                return await self._save_goal(
                    command,
                    conversation_id=conversation_id,
                    user_message=user_message,
                    response=response,
                    extra_records=extra_records,
                )
            return await self._save_commitment(
                command,
                conversation_id=conversation_id,
                user_message=user_message,
                response=response,
                extra_records=extra_records,
            )

        response = self._reclassification_response(
            commands[0],
            archived_record=archived_record,
            total_goals=len(commands),
            titles=[command.title for command in commands],
        )
        return await self._save_multiple_goals(
            commands,
            conversation_id=conversation_id,
            user_message=user_message,
            response=response,
            extra_records=extra_records,
        )

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
        commands = self._reclassified_goal_commands(
            body,
            message=message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        return commands[0] if len(commands) == 1 else None

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
            if body and not is_meta_instruction_body(body):
                return body

        obligation = self._extract_obligation_action(message)
        if obligation and not is_meta_instruction_body(obligation):
            return self._clean_reclassified_body(obligation)

        substantive = substantive_goal_from_history(conversation_history)
        if substantive:
            return substantive

        for item in reversed(conversation_history[-8:]):
            if item.get("role") != "user":
                continue
            content = str(item.get("content") or "")
            nested = self._clarified_goal_body_pattern.search(content)
            if nested is not None:
                body = self._clean_reclassified_body(nested.group("body"))
                if body and not is_meta_instruction_body(body):
                    return body
            obligation = self._extract_obligation_action(content)
            if obligation and not is_meta_instruction_body(obligation):
                return self._clean_reclassified_body(obligation)
        return None

    def _reclassified_goal_commands(
        self,
        body: Optional[str],
        *,
        message: str,
        conversation_history: list[dict],
        time_context: dict,
    ) -> list[GoalCommand]:
        if not body or is_meta_instruction_body(body):
            return []

        items = split_compound_goal_bodies(body)
        if not items:
            if looks_like_equipment_goal(body):
                items = [normalize_equipment_goal_title(body)]
            else:
                items = [self._title(body)]

        combined = self._combined_recent_text(message, conversation_history)
        target_text = target_date_for_message(
            combined,
            time_context=time_context,
        ) or self._relative_date_from_text(
            combined,
            time_context=time_context,
        ) or self._date_from_text(combined, time_context=time_context)
        prefer_goal = bool(
            self._plan_timeline_pattern.search(combined)
            or self._relative_time_pattern.search(combined)
            or re.search(r"\b(?:purchase|checklist|plan)\b", combined, re.I)
            or len(items) > 1
            or any(looks_like_equipment_goal(item) for item in items)
        )
        if prefer_goal:
            return [
                GoalCommand(
                    kind="goal",
                    title=item,
                    body=item,
                    record_type=self._plan_type(item),
                    target_text=target_text,
                )
                for item in items
            ]
        return [
            GoalCommand(
                kind="commitment",
                title=item,
                body=item,
                record_type=self._commitment_type(item),
                due_text=target_text,
            )
            for item in items
        ]

    def _combined_recent_text(
        self,
        message: str,
        conversation_history: list[dict],
    ) -> str:
        recent = " ".join(
            str(item.get("content") or "")
            for item in conversation_history[-8:]
        )
        return f"{message} {recent}".strip()

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
        if best_match is None:
            return None
        if best_score >= 2:
            return best_match

        upgrade_memories = [
            memory
            for memory in memories
            if re.search(
                r"\b(?:ram|upgrade|storage|ssd|terabyte|tb)\b",
                str(memory.get("content") or ""),
                re.I,
            )
        ]
        if len(upgrade_memories) == 1:
            return upgrade_memories[0]
        if best_score >= 1:
            return best_match
        return None

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
        total_goals: int = 1,
        titles: Optional[list[str]] = None,
    ) -> Optional[str]:
        if archived_record is None:
            if total_goals > 1 and titles:
                joined = ", ".join(titles)
                return f"Got it, I added {total_goals} goals: {joined}."
            if total_goals == 1:
                kind_label = "goal" if command.kind == "goal" else "commitment"
                return (
                    f"Got it, I added that as a {kind_label}: {command.title}."
                )
            return None
        if total_goals > 1 and titles:
            joined = ", ".join(titles)
            return (
                "Got it, I removed that from saved memory and added "
                f"{total_goals} goals: {joined}."
            )
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

    def _relative_date_from_text(
        self,
        text: str,
        *,
        time_context: Optional[dict] = None,
    ) -> Optional[str]:
        month_target = target_date_for_message(text, time_context=time_context)
        if month_target:
            return month_target
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
