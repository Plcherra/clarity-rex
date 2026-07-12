"""Generic eligibility signals for open thread tracking offers."""

from __future__ import annotations

import re
from typing import Any, Optional

from app.services.memory_discipline_similarity import token_overlap_score

CASUAL_ONLY_PATTERNS = (
    re.compile(r"^\s*(hey|hi|hello|thanks|thank you|ok|okay|lol|haha|yep|nope)\s*[!.?]*\s*$", re.I),
)

RECALL_PATTERNS = (
    re.compile(r"\bdo you remember\b", re.I),
    re.compile(r"\bwhat did i say about\b", re.I),
    re.compile(r"\bsearch chats?\b", re.I),
    re.compile(r"\bwhat do you know about\b", re.I),
)

ONGOING_SIGNAL_PATTERNS = (
    re.compile(r"\bi(?:'m| am)\s+(?:trying|working|figuring|dealing|going)\b", re.I),
    re.compile(r"\bi want to\b", re.I),
    re.compile(r"\bi need to\b", re.I),
    re.compile(r"\bi plan to\b", re.I),
    re.compile(r"\bmy plan is\b", re.I),
    re.compile(r"\bi(?:'m| am)\s+going to\b", re.I),
    re.compile(r"\bkeep(?:ing)?\s+(?:working|going|at it)\b", re.I),
    re.compile(r"\bstill\b.+\b(?:working|figuring|dealing|processing)\b", re.I),
    re.compile(r"\bongoing\b", re.I),
    re.compile(r"\bstruggling with\b", re.I),
    re.compile(r"\b(?:sorting out|figuring out|working through)\b", re.I),
    re.compile(r"\bwe(?:'re| are)\s+(?:moving|relocating|building|working)\b", re.I),
)

ACTIONABLE_PLAN_PATTERNS = (
    re.compile(r"\bmy plan is\b", re.I),
    re.compile(r"\bi(?:'m| am)\s+going to\b", re.I),
    re.compile(r"\b(?:every|each)\s+(?:day|night|morning|week)\b", re.I),
    re.compile(r"\b(?:no|without)\s+\w+.+\b(?:after|before|by)\s+\d", re.I),
    re.compile(r"\b(?:step|steps)\s+(?:one|1|two|2)\b", re.I),
    re.compile(r"\bgot (?:a|the) plan\b", re.I),
    re.compile(r"\b(?:because|so (?:i|we) can|to fix)\b", re.I),
    re.compile(r"\bfigure out a better\b", re.I),
)

STRONG_ACTIONABLE_PLAN_PATTERNS = ACTIONABLE_PLAN_PATTERNS

WEAK_ACTIONABLE_PLAN_PATTERNS = (
    re.compile(
        r"\bi(?:'m| am)\s+(?:working on|trying to|planning to|looking to|hoping to|focused on|making progress on)\s+(?:my\s+)?[\w-]+",
        re.I,
    ),
    re.compile(
        r"\bi\s+want\s+to\s+(?:build|launch|reach|start|save|move|relocate|get|achieve|create|fix|change|improve)\b",
        re.I,
    ),
    re.compile(
        r"\bi\s+need\s+to\s+(?:finish|complete|build|save|reach|start|launch|move|get|achieve|create|fix|change)\b",
        re.I,
    ),
    re.compile(
        r"\b(?:trying to|working on)\s+(?:figure out|rebuild|build|fix|change|improve)\b",
        re.I,
    ),
    re.compile(r"\brebuild my\b", re.I),
)

TOPIC_CONTINUITY_PATTERNS = (
    re.compile(r"\b(?:night|morning|evening|bedtime|daily|weekly)\s+(?:routine|habits?)\b", re.I),
    re.compile(r"\b(?:routine|habit|schedule)\b", re.I),
    re.compile(r"\b(?:citizenship|immigration|relocation|moving)\s+(?:application|process|plan)?\b", re.I),
    re.compile(r"\b(?:workout|fitness|training|study|sleep)\b", re.I),
)

VAGUE_TOPIC_PATTERNS = (
    re.compile(r"^\s*about\s+(?:changing|change|fixing|fix|improving|improve)\b", re.I),
    re.compile(r"^\s*i just got an? idea\b", re.I),
    re.compile(r"^\s*(?:hey|hi|hello)[\s,.!?-]*i just got an? idea\b", re.I),
)

TEMPORAL_ONLY_PATTERNS = (
    re.compile(r"^\s*(?:about\s+)?[\w\s'-]{0,40}\b(?:right now|lately|these days)\s*[.!?]*\s*$", re.I),
)

STRESS_ONLY_VENT_PATTERNS = (
    re.compile(r"\b(?:stressful|overwhelming|a lot to handle|really stressful)\b", re.I),
    re.compile(r"\bcan'?t sleep\b", re.I),
    re.compile(r"\btoo much on my mind\b", re.I),
    re.compile(r"\bracing thoughts?\b", re.I),
)

ONE_OFF_COMMITMENT_PATTERNS = (
    re.compile(
        r"\b(?:gotta|have to|need to)\s+wake\b.+\b(?:tomorrow|tonight|today|this morning)\b",
        re.I,
    ),
    # One-shot urgency only — "start waking up around 4am" is habit territory.
    re.compile(
        r"\b(?:gotta|have to|need to|got to)\s+wake(?:\s+up)?\s+around\s+\d",
        re.I,
    ),
    re.compile(r"\b(?:tomorrow|tonight).+\b(?:wake|get up|be up)\b", re.I),
    re.compile(r"\bjust (?:starting|trying) to get (?:some )?sleep\b", re.I),
)

HABIT_THREAD_PATTERNS = (
    re.compile(r"\b(?:every|each)\s+(?:day|night|morning|week)\b", re.I),
    re.compile(r"\bchange my (?:sleep )?schedule\b", re.I),
    re.compile(r"\bwish I could wake\b.+\b(?:every|each)\b", re.I),
    re.compile(r"\bwake up (?:every|each)\b", re.I),
    re.compile(r"\bstart\s+wak(?:ing|e)\b", re.I),
    re.compile(r"\bnew habit\b", re.I),
    re.compile(r"\b(?:night|morning|bedtime)\s+(?:routine|habit)\b", re.I),
)

COMPANION_FOLLOW_UP_SIGNAL_PATTERNS = (
    re.compile(r"\bthe\s+\w+(?:\s+\w+){0,3}\s+process\s+is\b", re.I),
    re.compile(r"\b(?:sorting out|figuring out|working through)\b", re.I),
    re.compile(r"\bwe(?:'re| are)\s+(?:moving|relocating|building|working)\b", re.I),
    re.compile(r"\bkeep(?:ing)?\s+working on\b", re.I),
    re.compile(r"\b(?:citizenship|immigration)\s+(?:application|process)\b", re.I),
    re.compile(r"\bworking on my\s+(?:citizenship|immigration)\b", re.I),
)

CLEAR_MEASURABLE_GOAL_PATTERNS = (
    re.compile(r"\bi (?:want|need) to save\b", re.I),
    re.compile(r"\bmy (?:goal|focus|priority) is\b", re.I),
    re.compile(r"\bi (?:want|need) to reach\b", re.I),
)

EXPLICIT_TRACK_CONSENT_PATTERNS = (
    re.compile(r"\b(?:yes|yeah|yep|sure|ok(?:ay)?)\b.*\b(?:track|follow up|check in)\b", re.I),
    re.compile(r"\b(?:track|follow up on|keep track of)\b.+\b(?:this|that|it)\b", re.I),
    re.compile(r"\bkeep track of this\b", re.I),
    re.compile(r"\bcheck in (?:on|about) (?:this|that|it)\b", re.I),
)

EXPLICIT_TRACK_DECLINE_PATTERNS = (
    re.compile(r"\b(?:no|nope|don't|do not)\b.*\b(?:track|follow up|check in)\b", re.I),
    re.compile(r"\bnot now\b", re.I),
    re.compile(r"\bno thanks\b", re.I),
)

ONE_OFF_QUESTION_PATTERNS = (
    re.compile(r"^\s*(?:what|when|where|who|how much|how many)\b.+\?\s*$", re.I),
)

_MIN_SINGLE_TURN_LENGTH = 40


def is_casual_only_message(message: str) -> bool:
    return any(pattern.match(message) for pattern in CASUAL_ONLY_PATTERNS)


def is_recall_message(message: str) -> bool:
    return any(pattern.search(message) for pattern in RECALL_PATTERNS)


def is_one_off_factual_question(message: str) -> bool:
    if not message.strip().endswith("?"):
        return False
    return any(pattern.match(message) for pattern in ONE_OFF_QUESTION_PATTERNS)


def has_ongoing_personal_signal(message: str) -> bool:
    if len(message.strip()) < 20:
        return False
    return any(pattern.search(message) for pattern in ONGOING_SIGNAL_PATTERNS)


def has_actionable_plan_signal(text: str) -> bool:
    return has_strong_actionable_plan_signal(text) or has_weak_actionable_plan_signal(text)


def has_strong_actionable_plan_signal(text: str) -> bool:
    cleaned = re.sub(r"\s+", " ", text.strip())
    if len(cleaned) < 20:
        return False
    has_strong = any(pattern.search(cleaned) for pattern in STRONG_ACTIONABLE_PLAN_PATTERNS)
    if not has_strong:
        return False
    has_topic = any(pattern.search(cleaned) for pattern in TOPIC_CONTINUITY_PATTERNS)
    if has_topic:
        return True
    return _has_topic_noun(cleaned)


def has_weak_actionable_plan_signal(text: str) -> bool:
    cleaned = re.sub(r"\s+", " ", text.strip())
    if len(cleaned) < 20:
        return False
    has_weak = any(pattern.search(cleaned) for pattern in WEAK_ACTIONABLE_PLAN_PATTERNS)
    if not has_weak:
        return False
    has_topic = any(pattern.search(cleaned) for pattern in TOPIC_CONTINUITY_PATTERNS)
    if has_topic:
        return True
    return _has_topic_noun(cleaned)


def should_propose_open_thread_confirm_card(
    message: str,
    *,
    conversation_history: Optional[list[dict]] = None,
) -> bool:
    """Clear plans and routines get a confirm card; vaguer topics keep the text offer."""
    context = _combined_user_context(message, conversation_history)
    if has_habit_thread_signal(context):
        return True
    if is_vague_thread_topic(message, conversation_history=conversation_history):
        return False
    return has_strong_actionable_plan_signal(context)


def is_stress_only_vent(message: str) -> bool:
    cleaned = re.sub(r"\s+", " ", message.strip())
    if not any(pattern.search(cleaned) for pattern in STRESS_ONLY_VENT_PATTERNS):
        return False
    if has_habit_thread_signal(cleaned):
        return False
    return not re.search(
        r"\bi(?:'m| am)\s+(?:working on|trying to|planning to|going to)\b",
        cleaned,
        flags=re.I,
    )


def has_habit_thread_signal(message: str) -> bool:
    cleaned = re.sub(r"\s+", " ", message.strip())
    return any(pattern.search(cleaned) for pattern in HABIT_THREAD_PATTERNS)


def is_one_off_commitment(message: str, *, conversation_history: Optional[list[dict]] = None) -> bool:
    context = _combined_user_context(message, conversation_history)
    if has_habit_thread_signal(context):
        return False
    return any(pattern.search(context) for pattern in ONE_OFF_COMMITMENT_PATTERNS)


def is_vague_thread_topic(message: str, *, conversation_history: Optional[list[dict]] = None) -> bool:
    cleaned = re.sub(r"\s+", " ", message.strip())
    if not cleaned:
        return True
    if any(pattern.search(cleaned) for pattern in VAGUE_TOPIC_PATTERNS):
        return not has_strong_actionable_plan_signal(
            _combined_user_context(message, conversation_history)
        )
    if any(pattern.match(cleaned) for pattern in TEMPORAL_ONLY_PATTERNS):
        return not has_strong_actionable_plan_signal(
            _combined_user_context(message, conversation_history)
        )
    if len(cleaned) < _MIN_SINGLE_TURN_LENGTH:
        return not _multi_turn_context_is_actionable(message, conversation_history)
    return False


def has_specific_actionable_continuity(
    message: str,
    *,
    conversation_history: Optional[list[dict]] = None,
) -> bool:
    context = _combined_user_context(message, conversation_history)
    if is_vague_thread_topic(message, conversation_history=conversation_history):
        if _multi_turn_context_is_actionable(message, conversation_history):
            return True
        prior_context = _combined_user_context("", conversation_history)
        if prior_context and has_habit_thread_signal(prior_context):
            return True
        return False
    # Habit continuity wins even when the current turn is a short "remember that".
    if has_habit_thread_signal(context):
        return True
    if has_companion_follow_up_signal(message):
        return True
    if has_strong_actionable_plan_signal(context):
        return True
    if _multi_turn_context_is_actionable(message, conversation_history):
        return True
    from app.services.conversational_plan_detection import ConversationalPlanDetector

    if ConversationalPlanDetector().looks_like_conversational_plan(context):
        return has_strong_actionable_plan_signal(context) or has_companion_follow_up_signal(
            context
        )
    return False


def message_might_need_open_thread_offer(
    message: str,
    *,
    already_offered: bool,
    already_declined: bool,
    conversation_history: Optional[list[dict]] = None,
) -> bool:
    if already_offered or already_declined:
        return False
    if is_casual_only_message(message):
        return False
    if is_recall_message(message):
        return False
    if is_one_off_factual_question(message):
        return False
    if is_stress_only_vent(message):
        return False
    if is_one_off_commitment(message, conversation_history=conversation_history):
        return False
    if is_clear_measurable_goal(message):
        return False
    if should_defer_open_thread_to_plan(message):
        return False
    return has_specific_actionable_continuity(
        message,
        conversation_history=conversation_history,
    )


def is_clear_measurable_goal(message: str) -> bool:
    return any(pattern.search(message) for pattern in CLEAR_MEASURABLE_GOAL_PATTERNS)


def has_companion_follow_up_signal(message: str) -> bool:
    if len(message.strip()) < 20:
        return False
    return any(pattern.search(message) for pattern in COMPANION_FOLLOW_UP_SIGNAL_PATTERNS)


def should_defer_open_thread_to_plan(message: str) -> bool:
    from app.services.conversational_plan_detection import ConversationalPlanDetector

    if not ConversationalPlanDetector().looks_like_conversational_plan(message):
        return False
    if re.search(r"\bi(?:'m| am)\s+working on\b", message, re.I):
        return False
    return not has_companion_follow_up_signal(message)


def is_explicit_track_consent(message: str) -> bool:
    return any(pattern.search(message) for pattern in EXPLICIT_TRACK_CONSENT_PATTERNS)


def is_explicit_track_decline(message: str) -> bool:
    return any(pattern.search(message) for pattern in EXPLICIT_TRACK_DECLINE_PATTERNS)


def is_bare_pending_offer_decline(message: str) -> bool:
    normalized = re.sub(r"[^a-z0-9']+", " ", message.strip().lower())
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized in {"no", "nope", "nah"}


def thread_offer_message_eligible(
    message: str,
    *,
    already_offered: bool,
    already_declined: bool,
    conversation_history: Optional[list[dict]] = None,
    active_threads: Optional[list[dict[str, Any]]] = None,
    active_plans: Optional[list[dict[str, Any]]] = None,
    saved_memories: Optional[list[dict[str, Any]]] = None,
    active_entities: Optional[list[dict[str, Any]]] = None,
) -> bool:
    if already_offered or already_declined:
        return False
    if is_casual_only_message(message):
        return False
    if is_recall_message(message):
        return False
    if is_one_off_factual_question(message):
        return False
    if is_stress_only_vent(message):
        return False
    if is_clear_measurable_goal(message):
        return False
    if should_defer_open_thread_to_plan(message):
        return False
    if not has_specific_actionable_continuity(
        message,
        conversation_history=conversation_history,
    ):
        return False
    if active_threads is not None and topic_overlaps_existing_context(
        message,
        active_threads=active_threads,
        active_plans=active_plans or [],
        saved_memories=saved_memories or [],
        active_entities=active_entities or [],
    ):
        return False
    return True


def thread_offer_eligible(
    message: str,
    *,
    already_offered: bool,
    already_declined: bool,
    active_thread_count: int,
    max_active: int = 5,
    conversation_history: Optional[list[dict]] = None,
    active_threads: Optional[list[dict[str, Any]]] = None,
    active_plans: Optional[list[dict[str, Any]]] = None,
    saved_memories: Optional[list[dict[str, Any]]] = None,
    active_entities: Optional[list[dict[str, Any]]] = None,
) -> bool:
    if active_thread_count >= max_active:
        return False
    return thread_offer_message_eligible(
        message,
        already_offered=already_offered,
        already_declined=already_declined,
        conversation_history=conversation_history,
        active_threads=active_threads,
        active_plans=active_plans,
        saved_memories=saved_memories,
        active_entities=active_entities,
    )


def infer_thread_title(
    message: str,
    *,
    conversation_history: Optional[list[dict]] = None,
    max_length: int = 60,
) -> str:
    from app.services.open_thread_title import infer_thread_title as build_title

    return build_title(
        message,
        conversation_history=conversation_history,
        max_length=max_length,
    )


def thread_summary_from_message(
    message: str,
    *,
    conversation_history: Optional[list[dict]] = None,
    max_length: int = 200,
) -> Optional[str]:
    from app.services.open_thread_title import thread_summary_from_message as build_summary

    return build_summary(
        message,
        conversation_history=conversation_history,
        max_length=max_length,
    )


def build_thread_description(
    message: str,
    *,
    conversation_history: Optional[list[dict]] = None,
    max_length: int = 200,
) -> Optional[str]:
    from app.services.open_thread_title import build_thread_description as build_description

    return build_description(
        message,
        conversation_history=conversation_history,
        max_length=max_length,
    )


def _combined_user_context(
    message: str,
    conversation_history: Optional[list[dict]],
) -> str:
    parts: list[str] = []
    if conversation_history:
        for entry in conversation_history[-6:]:
            if str(entry.get("role") or "") != "user":
                continue
            content = str(entry.get("content") or "").strip()
            if _is_substantive_user_content(content):
                parts.append(content)
    current = str(message or "").strip()
    if current and (not parts or parts[-1] != current):
        parts.append(current)
    return " ".join(parts).strip()


def _is_substantive_user_content(content: str) -> bool:
    cleaned = content.strip()
    if len(cleaned) < 8:
        return False
    normalized = re.sub(r"[^a-z0-9']+", " ", cleaned.casefold()).strip()
    return normalized not in {"yes", "no", "ok", "okay", "thanks", "thank you", "nope", "nah"}


def _multi_turn_context_is_actionable(
    message: str,
    conversation_history: Optional[list[dict]],
) -> bool:
    if not conversation_history:
        return False
    substantive = [
        str(entry.get("content") or "").strip()
        for entry in conversation_history[-6:]
        if str(entry.get("role") or "") == "user"
        and _is_substantive_user_content(str(entry.get("content") or ""))
    ]
    current = str(message or "").strip()
    if current and (not substantive or substantive[-1] != current):
        substantive.append(current)
    if len(substantive) < 2:
        return False
    combined = " ".join(substantive)
    return has_strong_actionable_plan_signal(combined) or has_companion_follow_up_signal(
        combined
    )


def _has_topic_noun(text: str) -> bool:
    cleaned = re.sub(r"\s+", " ", text.strip())
    if len(cleaned) < 20:
        return False
    generic_only = re.fullmatch(
        r"(?:i(?:'m| am)\s+(?:stressed|worried|anxious|overwhelmed)[\s,.!?-]*)+",
        cleaned,
        flags=re.I,
    )
    if generic_only:
        return False
    return bool(
        re.search(
            r"\b(?:routine|habit|plan|project|process|move|moving|sleep|job|work|app|business|health|budget|training|study|citizenship)\b",
            cleaned,
            flags=re.I,
        )
    )


def _context_text_fields(record: dict[str, Any]) -> list[str]:
    fields: list[str] = []
    for key in ("title", "summary", "description", "content", "display_name"):
        value = record.get(key)
        if isinstance(value, str) and value.strip():
            fields.append(value.strip())
    return fields


def topic_overlaps_existing_context(
    message: str,
    *,
    active_threads: list[dict[str, Any]],
    active_plans: list[dict[str, Any]],
    saved_memories: list[dict[str, Any]],
    active_entities: list[dict[str, Any]],
    threshold: float = 0.45,
) -> bool:
    candidates: list[str] = []
    for collection in (
        active_threads,
        active_plans,
        saved_memories,
        active_entities,
    ):
        for record in collection:
            if not isinstance(record, dict):
                continue
            candidates.extend(_context_text_fields(record))

    for candidate in candidates:
        if token_overlap_score(message, candidate) >= threshold:
            return True
    return False
