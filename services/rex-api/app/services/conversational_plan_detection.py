"""Detect plan-like chat statements that are not explicit goal commands."""

from __future__ import annotations

import re

from app.services.goal_command_detection import GoalCommandDetector
from app.services.personal_plan_intent_parser import PersonalPlanIntentParser
from app.services.save_intent_guards import is_advice_seeking_turn

_CONVERSATIONAL_PLAN_PATTERN = re.compile(
    r"\b(?:"
    r"i(?:'m| am)\s+(?:working on|trying to|planning to|looking to|hoping to|focused on|making progress on)\b|"
    r"i\s+want\s+to\s+(?:build|launch|reach|start|save|move|relocate|get|achieve|create)\b|"
    r"my\s+(?:focus|priority)\s+is\s+to\b|"
    r"my\s+next\s+step\s+is\s+to\b|"
    r"i\s+need\s+to\s+(?:finish|complete|build|save|reach|start|launch|move|get|achieve|create)\b|"
    r"this\s+(?:month|quarter|year)\s+i(?:'m| am)\s+(?:trying|working|focused)\b"
    r")\b",
    re.IGNORECASE,
)
_QUESTION_PATTERN = re.compile(
    r"^\s*(?:can you|could you|would you|do you|did you|what|how|why|when|where|who|should i)\b",
    re.IGNORECASE,
)
_EXPLICIT_SAVE_PATTERN = re.compile(
    r"\b(?:track|save|add)\s+.+\s+as\s+(?:a\s+)?(?:goal|commitment|plan)\b",
    re.IGNORECASE,
)


class ConversationalPlanDetector:
    def __init__(
        self,
        *,
        goal_detector: GoalCommandDetector | None = None,
        personal_plan_parser: PersonalPlanIntentParser | None = None,
    ) -> None:
        self._goal_detector = goal_detector or GoalCommandDetector()
        self._personal_plan_parser = personal_plan_parser or PersonalPlanIntentParser()

    def looks_like_conversational_plan(self, message: str) -> bool:
        text = str(message or "").strip()
        if len(text) < 12:
            return False
        if is_advice_seeking_turn(text):
            return False
        if _QUESTION_PATTERN.search(text):
            return False
        if _EXPLICIT_SAVE_PATTERN.search(text):
            return False
        if self._personal_plan_parser.detect(text) is not None:
            return False
        return _CONVERSATIONAL_PLAN_PATTERN.search(text) is not None

    def should_skip_for_explicit_command(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: dict,
    ) -> bool:
        return (
            self._goal_detector.detect_command(
                message,
                conversation_history=conversation_history,
                time_context=time_context,
            )
            is not None
        )
