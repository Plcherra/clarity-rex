"""Move misclassified saved memory into goals or commitments."""

from __future__ import annotations

import re
from typing import Any, Optional

from app.services.goal_command_formatting import (
    archived_memory_record,
    clean_reclassified_body,
    commitment_type,
    combined_recent_text,
    date_from_text,
    extract_obligation_action,
    goal_title,
    plan_type,
    reclassification_response,
    relative_date_from_text,
)
from app.services.goal_command_parsing import (
    is_meta_instruction_body,
    looks_like_equipment_goal,
    normalize_equipment_goal_title,
    split_compound_goal_bodies,
    substantive_goal_from_history,
    target_date_for_message,
)
from app.services.goal_command_results import clarification_turn_result
from app.services.goal_command_types import GoalCommand

_RECLASSIFY_REQUEST_PATTERN = re.compile(
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
_CLARIFIED_GOAL_BODY_PATTERN = re.compile(
    r"\b(?:meant\s+to\s+be|should\s+be|was\s+supposed\s+to\s+be)\s+(?P<body>.+)$",
    re.IGNORECASE,
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
_RELATIVE_TIME_PATTERN = re.compile(
    r"\b(?P<relative>(?:next|this)\s+(?:month|week|quarter|year))\b",
    re.IGNORECASE,
)


def conversation_mentions_saved_memory(conversation_history: list[dict]) -> bool:
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


def is_memory_reclassification_request(
    message: str,
    *,
    conversation_history: list[dict],
) -> bool:
    if _RECLASSIFY_REQUEST_PATTERN.search(message):
        return True
    if _CLARIFIED_GOAL_BODY_PATTERN.search(message) and (
        conversation_mentions_saved_memory(conversation_history)
        or _RECLASSIFY_REQUEST_PATTERN.search(message)
    ):
        return True
    return False


def extract_reclassified_body(
    message: str,
    *,
    conversation_history: list[dict],
) -> Optional[str]:
    match = _CLARIFIED_GOAL_BODY_PATTERN.search(message)
    if match is not None:
        body = clean_reclassified_body(match.group("body"))
        if body and not is_meta_instruction_body(body):
            return body

    obligation = extract_obligation_action(message)
    if obligation and not is_meta_instruction_body(obligation):
        return clean_reclassified_body(obligation)

    substantive = substantive_goal_from_history(conversation_history)
    if substantive:
        return substantive

    for item in reversed(conversation_history[-8:]):
        if item.get("role") != "user":
            continue
        content = str(item.get("content") or "")
        nested = _CLARIFIED_GOAL_BODY_PATTERN.search(content)
        if nested is not None:
            body = clean_reclassified_body(nested.group("body"))
            if body and not is_meta_instruction_body(body):
                return body
        obligation = extract_obligation_action(content)
        if obligation and not is_meta_instruction_body(obligation):
            return clean_reclassified_body(obligation)
    return None


def build_reclassified_commands(
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
            items = [goal_title(body)]

    combined = combined_recent_text(message, conversation_history)
    target_text = (
        target_date_for_message(combined, time_context=time_context)
        or relative_date_from_text(combined, time_context=time_context)
        or date_from_text(combined, time_context=time_context)
    )
    prefer_goal = bool(
        _PLAN_TIMELINE_PATTERN.search(combined)
        or _RELATIVE_TIME_PATTERN.search(combined)
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
                record_type=plan_type(item),
                target_text=target_text,
            )
            for item in items
        ]
    return [
        GoalCommand(
            kind="commitment",
            title=item,
            body=item,
            record_type=commitment_type(item),
            due_text=target_text,
        )
        for item in items
    ]


def reclassification_search_terms(
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


class GoalCommandReclassifier:
    def __init__(self, memory_service: Any, writer: Any) -> None:
        self.memory_service = memory_service
        self.writer = writer

    async def try_move_memory_to_goal(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        time_context: dict,
    ) -> Optional[dict]:
        # Direct memory→goal reclassification writes are disabled.
        # Reclassification must go through DurableWriteService propose/confirm.
        return None

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

        terms = reclassification_search_terms(message, conversation_history)
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
