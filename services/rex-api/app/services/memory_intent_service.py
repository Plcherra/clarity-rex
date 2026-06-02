import base64
import json
import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


CONFIRMATION_MARKER_PATTERN = re.compile(
    r"\s*<!--\s*rex_memory_confirmation:(?P<payload>[A-Za-z0-9+/=]+)\s*-->\s*",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class SimpleMemoryIntent:
    memory_type: str
    content: str
    importance: int
    confirmation_question: str
    source: str = "simple_memory_intent"
    metadata: dict = field(default_factory=dict)


class MemoryIntentService:
    """Detects low-risk memories that can be confirmed naturally in chat."""

    _birthday_pattern = re.compile(
        r"\bmy\s+(?P<person>[A-Za-z][A-Za-z\s_-]{1,40}?)\s*(?:'s)?\s+"
        r"birthday\s+(?:is|falls on|will be)\s+"
        r"(?P<date>[^,.!?]{2,60})",
        re.IGNORECASE,
    )
    _remember_that_pattern = re.compile(
        r"\bremember\s+that\s+(?P<fact>[^.!?]+)",
        re.IGNORECASE,
    )
    _month_names = {
        "january": "January",
        "jan": "January",
        "february": "February",
        "feb": "February",
        "march": "March",
        "mar": "March",
        "april": "April",
        "apr": "April",
        "may": "May",
        "june": "June",
        "jun": "June",
        "july": "July",
        "jul": "July",
        "august": "August",
        "aug": "August",
        "september": "September",
        "sep": "September",
        "sept": "September",
        "october": "October",
        "oct": "October",
        "november": "November",
        "nov": "November",
        "december": "December",
        "dec": "December",
    }
    _confirmation_phrases = {
        "yes",
        "yep",
        "yeah",
        "correct",
        "confirmed",
        "confirm",
        "right",
        "that's right",
        "that is right",
        "exactly",
        "save it",
        "save that",
        "remember it",
        "remember that",
    }
    _rejection_phrases = {
        "no",
        "nope",
        "not correct",
        "that's wrong",
        "that is wrong",
        "cancel",
        "do not save",
        "dont save",
        "don't save",
        "forget it",
    }

    def detect_simple_memory(
        self,
        message: str,
        *,
        time_context: Optional[dict] = None,
    ) -> Optional[SimpleMemoryIntent]:
        birthday_intent = self._detect_birthday(message, time_context=time_context)
        if birthday_intent is not None:
            return birthday_intent

        remember_intent = self._detect_remember_that(message)
        if remember_intent is not None:
            return remember_intent

        return None

    def pending_confirmation_from_history(
        self,
        conversation_history: list[dict],
    ) -> Optional[SimpleMemoryIntent]:
        if not conversation_history:
            return None

        last_message = conversation_history[-1]
        if last_message.get("role") != "assistant":
            return None

        payload = self.confirmation_payload(str(last_message.get("content") or ""))
        if payload is None:
            return None

        try:
            return SimpleMemoryIntent(
                memory_type=str(payload["memory_type"]),
                content=str(payload["content"]),
                importance=int(payload.get("importance") or 4),
                confirmation_question="",
                source=str(payload.get("source") or "simple_memory_intent"),
                metadata=(
                    payload.get("metadata")
                    if isinstance(payload.get("metadata"), dict)
                    else {}
                ),
            )
        except (KeyError, TypeError, ValueError):
            return None

    def classify_confirmation_reply(self, message: str) -> Optional[str]:
        normalized = self._normalize_reply(message)
        if not normalized:
            return None
        if normalized in self._confirmation_phrases:
            return "confirm"
        if normalized in self._rejection_phrases:
            return "reject"
        if normalized.startswith(("yes ", "yeah ", "yep ")):
            return "confirm"
        if normalized.startswith(("no ", "nope ")):
            return "reject"
        return None

    def with_confirmation_marker(self, response: str, intent: SimpleMemoryIntent) -> str:
        payload = {
            "memory_type": intent.memory_type,
            "content": intent.content,
            "importance": intent.importance,
            "source": intent.source,
            "metadata": intent.metadata,
        }
        encoded = base64.b64encode(json.dumps(payload).encode("utf-8")).decode(
            "ascii"
        )
        return f"{response}\n\n<!-- rex_memory_confirmation:{encoded} -->"

    def strip_internal_markers(self, text: str) -> str:
        return CONFIRMATION_MARKER_PATTERN.sub("", text).strip()

    def confirmation_payload(self, text: str) -> Optional[dict]:
        match = CONFIRMATION_MARKER_PATTERN.search(text)
        if match is None:
            return None
        try:
            decoded = base64.b64decode(match.group("payload")).decode("utf-8")
            payload = json.loads(decoded)
        except (ValueError, json.JSONDecodeError):
            return None
        return payload if isinstance(payload, dict) else None

    def saved_response(self, intent: SimpleMemoryIntent) -> str:
        return f"Saved. I'll remember that {self._sentence_body(intent.content)}"

    def rejected_response(self) -> str:
        return "No problem. I won't save that."

    def _detect_birthday(
        self,
        message: str,
        *,
        time_context: Optional[dict],
    ) -> Optional[SimpleMemoryIntent]:
        match = self._birthday_pattern.search(message)
        if match is None:
            return None

        person = self._clean_person(match.group("person"))
        date_text = self._normalize_date_phrase(
            match.group("date"),
            time_context=time_context,
        )
        if not person or not date_text:
            return None

        content = f"User's {person}'s birthday is {date_text}."
        question = f"So your {person}'s birthday is {date_text}, correct?"
        return SimpleMemoryIntent(
            memory_type="fact",
            content=content,
            importance=5,
            confirmation_question=question,
            metadata={
                "fact_kind": "birthday",
                "entity_label": person,
                "normalized_date": date_text,
                "topic_fingerprint": f"fact:birthday:{person.lower()}",
            },
        )

    def _detect_remember_that(self, message: str) -> Optional[SimpleMemoryIntent]:
        match = self._remember_that_pattern.search(message)
        if match is None:
            return None

        fact = self._clean_fact(match.group("fact"))
        if len(fact) < 8:
            return None

        content = f"{fact[0].upper()}{fact[1:]}."
        return SimpleMemoryIntent(
            memory_type="fact",
            content=content,
            importance=4,
            confirmation_question=f"Should I remember that {fact}?",
            metadata={
                "fact_kind": "remember_that",
                "topic_fingerprint": f"fact:remember_that:{self._fingerprint(fact)}",
            },
        )

    def _normalize_date_phrase(
        self,
        raw_date: str,
        *,
        time_context: Optional[dict],
    ) -> Optional[str]:
        cleaned = self._clean_fact(raw_date)
        cleaned = re.sub(r"^(on|the)\s+", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\s+", " ", cleaned).strip(" .")
        if not cleaned:
            return None

        month = self._month_from_text(cleaned)
        day_match = re.search(r"\b(?P<day>\d{1,2})(?:st|nd|rd|th)?\b", cleaned)
        if day_match is None:
            return cleaned

        day = int(day_match.group("day"))
        if day < 1 or day > 31:
            return None

        month_name = month or self._current_month(time_context)
        if month_name:
            return f"{month_name} {day}"
        return f"the {self._ordinal(day)}"

    def _month_from_text(self, text: str) -> Optional[str]:
        normalized = text.lower()
        for token, month in self._month_names.items():
            if re.search(rf"\b{re.escape(token)}\b", normalized):
                return month
        return None

    def _current_month(self, time_context: Optional[dict]) -> Optional[str]:
        if not time_context:
            return None
        raw_date = str(time_context.get("date") or "")
        try:
            parsed = datetime.fromisoformat(raw_date)
        except ValueError:
            return None
        return parsed.strftime("%B")

    def _clean_person(self, person: str) -> str:
        cleaned = re.sub(r"\s+", " ", person).strip(" .'_-").lower()
        aliases = {
            "mother": "mom",
            "mum": "mom",
            "mama": "mom",
            "father": "dad",
            "papa": "dad",
        }
        return aliases.get(cleaned, cleaned)

    def _clean_fact(self, fact: str) -> str:
        cleaned = re.sub(r"\s+", " ", fact).strip()
        return cleaned.strip(" .!?")

    def _sentence_body(self, content: str) -> str:
        return content.strip().rstrip(".").replace("User's", "your", 1) + "."

    def _normalize_reply(self, message: str) -> str:
        normalized = message.lower().strip()
        normalized = re.sub(r"[,;:]+", " ", normalized)
        normalized = re.sub(r"[.!?]+$", "", normalized)
        normalized = re.sub(r"\s+", " ", normalized)
        return normalized

    def _fingerprint(self, text: str) -> str:
        normalized = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
        return normalized[:80] or "unknown"

    def _ordinal(self, day: int) -> str:
        if 10 <= day % 100 <= 20:
            suffix = "th"
        else:
            suffix = {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")
        return f"{day}{suffix}"
