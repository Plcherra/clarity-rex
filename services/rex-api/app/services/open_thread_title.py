"""Generate concise open-thread titles from conversational context."""

from __future__ import annotations

import re
from typing import Optional

_MAX_TITLE_LENGTH = 60
_MAX_DESCRIPTION_LENGTH = 200

_FILLER_PREFIX = re.compile(
    r"^(?:"
    r"(?:hey|hi|hello|yeah|yep|ok|okay)[\s,.!?-]*|"
    r"about\s+|"
    r"i(?:'ve| have)\s+been\s+|"
    r"i(?:'m| am)\s+(?:just\s+)?|"
    r"i just got (?:an?\s+)?(?:idea|plan)\s*(?:about|that|to)?\s*"
    r")+",
    re.IGNORECASE,
)
_TRAILING_FILLER = re.compile(
    r"\b(?:right now|lately|these days|for now|at the moment|this month)\b[\s,.!?-]*$",
    re.IGNORECASE,
)
_TOPIC_PATTERNS = (
    re.compile(
        r"\b(?P<topic>better\s+(?:morning|night|evening|bedtime|daily|weekly)\s+routine)\b",
        re.I,
    ),
    re.compile(
        r"\b(?:(?:new|better|changing|change(?:ing)?|fix(?:ing)?|improve(?:ing)?)\s+)?"
        r"(?P<topic>(?:night|morning|evening|bedtime|daily|weekly)\s+routine)\b",
        re.I,
    ),
    re.compile(
        r"\b(?:(?:new|better|changing|change(?:ing)?|fix(?:ing)?|improve(?:ing)?)\s+)?"
        r"(?P<topic>(?:morning|night|evening|bedtime|daily|weekly)\s+habits?)\b",
        re.I,
    ),
    re.compile(
        r"\b(?P<topic>citizenship\s+(?:application|process))\b",
        re.I,
    ),
    re.compile(
        r"\b(?P<topic>(?:moving|relocation|relocating)(?:\s+(?:plan|process|logistics))?)\b",
        re.I,
    ),
    re.compile(
        r"\b(?:rebuild(?:ing)?|rebuilding)\s+(?:my\s+)?(?P<topic>[\w\s-]{3,40}?)(?:\s+habit)?\b",
        re.I,
    ),
    re.compile(
        r"\b(?P<topic>(?:workout|fitness|training)\s+habits?)\b",
        re.I,
    ),
    re.compile(
        r"\b(?:figure out|figuring out)\s+(?:a\s+)?(?P<topic>[\w\s-]{3,40}?)(?:[,.!?]|$)",
        re.I,
    ),
    re.compile(
        r"\b(?:working on|building|launching|starting)\s+(?:an?\s+)?(?P<topic>[\w\s-]{3,40}?)"
        r"(?:\s+(?:in|on|for|at)\s+\w+)?(?:[,.!?]|$)",
        re.I,
    ),
    re.compile(
        r"\b(?:changing|change(?:ing)?|fix(?:ing)?|improve(?:ing)?)\s+my\s+"
        r"(?P<topic>[\w\s-]{3,40}?)(?:[,.!?]|$)",
        re.I,
    ),
)
_PURPOSE_PATTERNS = (
    (re.compile(r"\b(?:trouble|problems?|issues?)\s+(?:to\s+)?sleep(?:ing)?\b", re.I), "Fix Sleep"),
    (re.compile(r"\b(?:can't|cannot|can not)\s+sleep\b", re.I), "Fix Sleep"),
    (re.compile(r"\b(?:having|have)\s+(?:some\s+)?(?:trouble|problems?)\s+sleep(?:ing)?\b", re.I), "Fix Sleep"),
    (re.compile(r"\bto fix\s+(?P<purpose>[\w\s-]{3,30})", re.I), None),
    (re.compile(r"\bbecause\s+(?:i(?:'m| am)\s+)?(?P<purpose>[\w\s-]{3,40})", re.I), None),
    (re.compile(r"\bso (?:i|we) can\s+(?P<purpose>[\w\s-]{3,40})", re.I), None),
)
_FOLLOW_UP_PHRASE_PATTERNS = (
    re.compile(
        r"\b(?:trying to|working on|figure out|figuring out|rebuild(?:ing)?|rebuilding)\s+"
        r"(?:a\s+)?(?:better\s+)?(?P<phrase>[\w\s-]{3,50}?)(?:[,.!?]|$)",
        re.I,
    ),
    re.compile(
        r"\b(?:changing|change(?:ing)?|fix(?:ing)?|improve(?:ing)?)\s+my\s+"
        r"(?P<phrase>[\w\s-]{3,50}?)(?:[,.!?]|$)",
        re.I,
    ),
    re.compile(
        r"\b(?:sorting out|working through)\s+(?P<phrase>[\w\s-]{3,50}?)(?:[,.!?]|$)",
        re.I,
    ),
)


def infer_thread_title(
    message: str,
    *,
    conversation_history: Optional[list[dict]] = None,
    max_length: int = _MAX_TITLE_LENGTH,
) -> str:
    context = _combined_user_context(message, conversation_history)
    cleaned = _clean_context(context)
    if not cleaned:
        return _truncate_title("Open Thread", max_length)

    topic = _extract_topic(cleaned)
    purpose = _extract_purpose(cleaned)
    title = _format_title(topic, purpose, cleaned)
    return _truncate_title(title, max_length)


def build_thread_description(
    message: str,
    *,
    conversation_history: Optional[list[dict]] = None,
    max_length: int = _MAX_DESCRIPTION_LENGTH,
) -> Optional[str]:
    context = _combined_user_context(message, conversation_history)
    cleaned = _clean_context(context)
    if not cleaned:
        return None

    topic = _extract_topic(cleaned)
    purpose = _extract_purpose(cleaned)
    phrase = _extract_follow_up_phrase(cleaned)

    if topic and purpose:
        description = (
            f"Follow up on {_description_phrase(topic)} to {purpose.lower()}."
        )
    elif topic:
        description = f"Follow up on {_description_phrase(topic)}."
    elif phrase:
        description = f"Follow up on {_description_phrase(phrase)}."
    else:
        description = f"Follow up on {_description_phrase(cleaned)}."

    return _truncate_description(description, max_length)


def thread_summary_from_message(
    message: str,
    *,
    conversation_history: Optional[list[dict]] = None,
    max_length: int = _MAX_DESCRIPTION_LENGTH,
) -> Optional[str]:
    return build_thread_description(
        message,
        conversation_history=conversation_history,
        max_length=max_length,
    )


def clamp_thread_title(title: str, *, max_length: int = _MAX_TITLE_LENGTH) -> str:
    return _truncate_title(str(title or "").strip() or "Open Thread", max_length)


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


def _clean_context(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", text.strip())
    cleaned = _FILLER_PREFIX.sub("", cleaned)
    cleaned = _TRAILING_FILLER.sub("", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" .,!?:;-")
    return cleaned


def _extract_topic(text: str) -> Optional[str]:
    for pattern in _TOPIC_PATTERNS:
        match = pattern.search(text)
        if match is None:
            continue
        topic = re.sub(r"\s+", " ", match.group("topic").strip(" .,!?:;-"))
        if len(topic) >= 3 and not _is_generic_topic(topic):
            return topic
    return None


def _extract_follow_up_phrase(text: str) -> Optional[str]:
    for pattern in _FOLLOW_UP_PHRASE_PATTERNS:
        match = pattern.search(text)
        if match is None:
            continue
        phrase = re.sub(r"\s+", " ", match.group("phrase").strip(" .,!?:;-"))
        if len(phrase) >= 3 and not _is_generic_topic(phrase):
            return phrase
    words = text.split()
    if len(words) >= 3:
        return " ".join(words[:6])
    return text or None


def _description_phrase(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", text.strip()).strip(" .,!?:;-")
    if not cleaned:
        return "this topic"
    normalized = cleaned.casefold()
    if normalized.startswith(("your ", "my ", "the ", "a ", "an ")):
        return cleaned.lower()
    return f"your {cleaned.lower()}"


def _is_generic_topic(topic: str) -> bool:
    normalized = topic.casefold().strip()
    return normalized in {
        "this",
        "that",
        "it",
        "something",
        "things",
        "stuff",
        "idea",
        "plan",
    }


def _extract_purpose(text: str) -> Optional[str]:
    for pattern, fixed in _PURPOSE_PATTERNS:
        match = pattern.search(text)
        if match is None:
            continue
        if fixed:
            return fixed
        purpose = re.sub(r"\s+", " ", match.group("purpose").strip(" .,!?:;-"))
        if len(purpose) >= 3:
            return _title_case_words(purpose)
    return None


def _format_title(
    topic: Optional[str],
    purpose: Optional[str],
    fallback: str,
) -> str:
    if topic:
        normalized_topic = topic.casefold().strip()
        if normalized_topic.startswith("better "):
            base = _title_case_words(topic)
        elif "routine" in normalized_topic or "habit" in normalized_topic:
            if re.search(r"\b(?:rebuild(?:ing)?|chang(?:e|ing)|fix(?:ing)?|new)\b", fallback, flags=re.I):
                if re.search(r"\brebuild", fallback, flags=re.I):
                    base = _title_case_words(topic)
                    if "rebuild" not in base.casefold():
                        base = f"{base} Rebuild"
                else:
                    base = f"New {_title_case_words(topic)} Change"
            else:
                base = f"New {_title_case_words(topic)}"
        elif normalized_topic.startswith(("moving", "relocation", "relocating")):
            base = _title_case_words(topic)
        else:
            base = _title_case_words(topic)
        if purpose:
            if purpose.casefold().startswith("fix "):
                return f"{base} to {purpose}"
            return f"{base} to {purpose}"
        return base
    if purpose:
        return purpose if purpose.startswith("Fix ") else f"Plan to {purpose}"

    phrase = _extract_follow_up_phrase(fallback)
    if phrase:
        return _title_case_words(phrase)
    return _title_case_words(fallback) or "Open Thread"


def _title_case_words(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", text.strip())
    if not cleaned:
        return "Open Thread"
    words = []
    for word in cleaned.split():
        if word.lower() in {"a", "an", "the", "to", "for", "and", "or", "my"}:
            words.append(word.lower())
        else:
            words.append(word[:1].upper() + word[1:])
    if words:
        words[0] = words[0][:1].upper() + words[0][1:]
    return " ".join(words)


def _truncate_title(title: str, max_length: int) -> str:
    cleaned = re.sub(r"\s+", " ", title.strip())
    if len(cleaned) <= max_length:
        return cleaned
    truncated = cleaned[: max_length - 3].rstrip()
    last_space = truncated.rfind(" ")
    if last_space > max_length // 2:
        truncated = truncated[:last_space]
    return f"{truncated}..."


def _truncate_description(description: str, max_length: int) -> str:
    cleaned = re.sub(r"\s+", " ", description.strip())
    if len(cleaned) <= max_length:
        return cleaned
    truncated = cleaned[: max_length - 3].rstrip()
    last_space = truncated.rfind(" ")
    if last_space > max_length // 2:
        truncated = truncated[:last_space]
    return f"{truncated}..."
