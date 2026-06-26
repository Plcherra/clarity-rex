"""Detect explicit goal and commitment commands from user messages."""

from __future__ import annotations

import re
from typing import Optional

from app.services.goal_command_formatting import (
    clean_goal_text,
    commitment_type,
    date_from_text,
    extract_obligation_action,
    goal_title,
    plan_type,
    recent_user_content,
    relative_date_from_text,
    target_date_for_combined_text,
)
from app.services.goal_command_parsing import (
    is_affirmation_or_goal_prefix,
    looks_like_equipment_goal,
    normalize_equipment_goal_title,
    split_compound_goal_bodies,
    substantive_goal_from_history,
)
from app.services.goal_command_reclassify import (
    build_reclassified_commands,
    conversation_mentions_saved_memory,
    extract_reclassified_body,
)
from app.services.goal_command_types import GoalCommand
from app.services.memory_delete_reference import should_defer_to_delete_confirmation

_CONTEXTUAL_GOAL_PATTERN = re.compile(
    r"\b(?:track|save|add)\s+this\s+as\s+(?:a\s+)?goal\b",
    re.IGNORECASE,
)
_INLINE_GOAL_PATTERNS = (
    re.compile(
        r"\b(?:track|save|add)\s+(?P<goal>.+?)\s+as\s+(?:a\s+)?goal\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\bmy\s+goal\s+is\s+(?P<goal>.+)",
        re.IGNORECASE,
    ),
)
_COMMITMENT_PATTERNS = (
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
_PLAN_TIMELINE_PATTERN = re.compile(
    r"\b(?:"
    r"(?:my\s+)?(?:next\s+)?checklist\b|"
    r"next\s+month(?:'?s)?\s+(?:purchase|checklist|shopping)\b|"
    r"(?:purchase|shopping)\s+(?:plan|list|checklist)\b|"
    r"plan(?:ned|ning)?\s+(?:for|to)\s+(?:next|this)\s+(?:month|week)"
    r")\b",
    re.IGNORECASE,
)
_CLARIFIED_GOAL_BODY_PATTERN = re.compile(
    r"\b(?:meant\s+to\s+be|should\s+be|was\s+supposed\s+to\s+be)\s+(?P<body>.+)$",
    re.IGNORECASE,
)


class GoalCommandDetector:
    def detect_commands(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
        pending_action=None,
    ) -> list[GoalCommand]:
        equipment_goals = self.detect_equipment_goals(
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
                pending_action_payload(pending_action),
            ):
                return []
            substantive = substantive_goal_from_history(conversation_history)
            if substantive:
                affirmed = self.goal_commands_from_text(
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
        commitment = self.detect_commitment(message, time_context=time_context)
        if commitment is not None:
            return commitment
        future_plan = self.detect_future_plan_goal(
            message,
            time_context=time_context,
        )
        if future_plan is not None:
            return future_plan
        obligation = self.detect_obligation_commitment(
            message,
            time_context=time_context,
        )
        if obligation is not None:
            return obligation
        clarified = self.detect_clarified_misclassified_goal(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if clarified is not None:
            return clarified
        return self.detect_goal(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )

    def detect_goal(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[GoalCommand]:
        goal_text = None
        if _CONTEXTUAL_GOAL_PATTERN.search(message):
            goal_text = recent_user_content(conversation_history)
        else:
            for pattern in _INLINE_GOAL_PATTERNS:
                match = pattern.search(message)
                if match:
                    goal_text = match.group("goal")
                    break
        goal_text = clean_goal_text(goal_text)
        if not goal_text:
            return None

        target_text = date_from_text(goal_text, time_context=time_context)
        return GoalCommand(
            kind="goal",
            title=goal_title(goal_text),
            body=goal_text,
            record_type=plan_type(goal_text),
            target_text=target_text,
        )

    def detect_future_plan_goal(
        self,
        message: str,
        *,
        time_context: dict,
    ) -> Optional[GoalCommand]:
        if _PLAN_TIMELINE_PATTERN.search(message) is None:
            return None

        body = extract_obligation_action(message) or clean_goal_text(message)
        if not body or len(body) < 8:
            return None

        target_text = relative_date_from_text(
            message,
            time_context=time_context,
        ) or date_from_text(message, time_context=time_context)
        return GoalCommand(
            kind="goal",
            title=goal_title(body),
            body=body,
            record_type=plan_type(body),
            target_text=target_text,
        )

    def detect_obligation_commitment(
        self,
        message: str,
        *,
        time_context: dict,
    ) -> Optional[GoalCommand]:
        if _PLAN_TIMELINE_PATTERN.search(message):
            return None

        body = extract_obligation_action(message)
        if not body:
            return None

        due_text = date_from_text(
            message,
            time_context=time_context,
        ) or relative_date_from_text(message, time_context=time_context)
        return GoalCommand(
            kind="commitment",
            title=goal_title(body),
            body=body,
            record_type=commitment_type(body),
            due_text=due_text,
        )

    def detect_commitment(
        self,
        message: str,
        *,
        time_context: dict,
    ) -> Optional[GoalCommand]:
        commitment_text = None
        for pattern in _COMMITMENT_PATTERNS:
            match = pattern.search(message)
            if match:
                commitment_text = match.group("commitment")
                break
        commitment_text = clean_goal_text(commitment_text)
        if not commitment_text:
            return None

        due_text = date_from_text(commitment_text, time_context=time_context)
        return GoalCommand(
            kind="commitment",
            title=goal_title(commitment_text),
            body=commitment_text,
            record_type=commitment_type(commitment_text),
            due_text=due_text,
        )

    def detect_equipment_goals(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
    ) -> list[GoalCommand]:
        items = split_compound_goal_bodies(message)
        if not items:
            return []
        return self.goal_commands_from_items(
            items,
            message=message,
            conversation_history=conversation_history,
            time_context=time_context,
        )

    def goal_commands_from_text(
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
        return self.goal_commands_from_items(
            items,
            message=f"{message} {text}",
            conversation_history=conversation_history,
            time_context=time_context,
        )

    def goal_commands_from_items(
        self,
        items: list[str],
        *,
        message: str,
        conversation_history: list[dict],
        time_context: dict,
    ) -> list[GoalCommand]:
        target_text = target_date_for_combined_text(
            message,
            conversation_history,
            time_context=time_context,
        )
        return [
            GoalCommand(
                kind="goal",
                title=item,
                body=item,
                record_type=plan_type(item),
                target_text=target_text,
            )
            for item in items
        ]

    def detect_clarified_misclassified_goal(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[GoalCommand]:
        if not _CLARIFIED_GOAL_BODY_PATTERN.search(message):
            return None
        if not conversation_mentions_saved_memory(conversation_history):
            return None

        body = extract_reclassified_body(
            message,
            conversation_history=conversation_history,
        )
        commands = build_reclassified_commands(
            body,
            message=message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        return commands[0] if len(commands) == 1 else None


def pending_action_payload(pending_action) -> dict | None:
    if pending_action is None:
        return None
    to_dict = getattr(pending_action, "to_dict", None)
    if callable(to_dict):
        return to_dict()
    if isinstance(pending_action, dict):
        return pending_action
    return None
