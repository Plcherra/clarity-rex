"""Shared guards for when a chat turn should not propose durable saves."""

from __future__ import annotations

import re

_EXPLICIT_SAVE_PATTERN = re.compile(
    r"\b(?:"
    r"(?:can|could|would)\s+you\s+(?:please\s+)?"
    r"(?:save|remember|keep|track|add)\b|"
    r"(?:track|save|add)\s+.+\s+as\s+(?:a\s+)?(?:goal|plan|commitment)|"
    r"(?:track|save|add)\s+(?:a\s+)?(?:goal|plan)\s+to\b|"
    r"(?:save|remember|keep)\s+\S.+\s+as\s+(?:my|your|a|an)\s+\w|"
    r"my\s+goal\s+is\b|"
    r"(?:remember|remind)\s+me\s+to\b|"
    r"(?:please\s+)?(?:save|track|add)\s+(?:this|that|it)\b"
    r")",
    re.IGNORECASE,
)

_ADVICE_QUESTION_PATTERN = re.compile(
    r"\b(?:"
    r"how\s+much|how\s+many|how\s+heavy|what\s+(?:size|weight|kind)|"
    r"do\s+you\s+think|would\s+you\s+recommend|"
    r"should\s+i\s+(?:get|buy)|can\s+you\s+(?:tell|help|advise)"
    r")\b",
    re.IGNORECASE,
)

_COMPARISON_QUESTION_PATTERN = re.compile(
    r"\b(?:"
    r"what\s+would\s+you\s+(?:pick|choose|recommend|get)|"
    r"which\s+(?:one|would\s+you|should\s+i)|"
    r"if\s+you\s+(?:gotta|have\s+to|had\s+to)\s+(?:pick|choose)|"
    r"(?:pick|choose)\s+between"
    r")\b",
    re.IGNORECASE,
)

_ANTI_SAVE_INTENT_PATTERN = re.compile(
    r"\b(?:"
    r"(?:don't|do\s+not|dont|doesn't|does\s+not|we\s+does\s+not)\s+(?:need\s+)?(?:to\s+)?(?:save|track|add)|"
    r"not\s+(?:gonna|going\s+to)\s+(?:save|track)|"
    r"won't\s+save|"
    r"without\s+saving|"
    r"need\s+save\s+that\s+in\s+a\s+(?:goal|plan|thread)"
    r")\b",
    re.IGNORECASE,
)

_DEFERRED_PURCHASE_PATTERN = re.compile(
    r"\b(?:"
    r"(?:it's\s+)?not\s+(?:gonna|going\s+to)\s+(?:be\s+)?now|"
    r"not\s+now|maybe\s+later|someday|eventually"
    r")\b",
    re.IGNORECASE,
)

_PLAN_SAVE_REJECTION_PATTERN = re.compile(
    r"^(?:no(?:pe)?|nah|don't|do not)\.?$",
    re.IGNORECASE,
)

_LEADING_QUESTION_PATTERN = re.compile(
    r"^\s*(?:how|what|which|when|where|why|who|should|can|could|would|do|did)\b",
    re.IGNORECASE,
)

_REMEMBER_ME_TO_PATTERN = re.compile(
    r"\b(?:remember|remind)\s+me\s+to\s+(?P<action>.+)",
    re.IGNORECASE,
)


def has_explicit_save_intent(message: str) -> bool:
    text = str(message or "").strip()
    if not text:
        return False
    return _EXPLICIT_SAVE_PATTERN.search(text) is not None


def is_advice_seeking_turn(message: str) -> bool:
    """True when the user is asking for guidance, not requesting a save."""
    text = str(message or "").strip()
    if len(text) < 8:
        return False
    if _ANTI_SAVE_INTENT_PATTERN.search(text):
        return True
    if is_deferred_purchase_discussion(text):
        return True
    if has_explicit_save_intent(text):
        return False
    if "?" in text:
        return True
    if _COMPARISON_QUESTION_PATTERN.search(text):
        return True
    if _ADVICE_QUESTION_PATTERN.search(text):
        return True
    return _LEADING_QUESTION_PATTERN.search(text) is not None


def is_deferred_purchase_discussion(message: str) -> bool:
    text = str(message or "").strip()
    if len(text) < 12:
        return False
    if _ANTI_SAVE_INTENT_PATTERN.search(text):
        return True
    if has_explicit_save_intent(text):
        return False
    has_purchase = re.search(
        r"\b(?:buy|purchase|want(?:a|ing)?|wanna)\b",
        text,
        re.IGNORECASE,
    )
    return bool(has_purchase and _DEFERRED_PURCHASE_PATTERN.search(text))


def user_declined_plan_save_recently(conversation_history: list[dict]) -> bool:
    recent = list(conversation_history or [])[-8:]
    for index, item in enumerate(recent):
        if item.get("role") != "user":
            continue
        content = str(item.get("content") or "").strip()
        if not _PLAN_SAVE_REJECTION_PATTERN.fullmatch(content):
            continue
        for prior in reversed(recent[:index]):
            if prior.get("role") != "assistant":
                continue
            assistant_text = str(prior.get("content") or "").casefold()
            if "save" in assistant_text and (
                "plan" in assistant_text or "goal" in assistant_text
            ):
                return True
            break
    return False


def purchase_clause_from_message(message: str) -> str:
    """Extract the actionable purchase/reminder clause from a longer utterance."""
    text = str(message or "").strip()
    match = _REMEMBER_ME_TO_PATTERN.search(text)
    if match is None:
        return text
    action = re.sub(r"\s+", " ", match.group("action")).strip(" .,!?:;")
    return action or text
