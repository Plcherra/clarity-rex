import re
from dataclasses import dataclass, field
from typing import Optional

from app.services.memory_date_normalizer import MemoryDateNormalizer


@dataclass(frozen=True)
class SimpleMemoryIntent:
    memory_type: str
    content: str
    importance: int
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
    _name_pattern = re.compile(
        r"\bmy\s+name\s+is\s+(?P<name>[A-Za-z][A-Za-z\s.'-]{1,80})",
        re.IGNORECASE,
    )
    _live_in_pattern = re.compile(
        r"\bi\s+live\s+in\s+(?P<place>[A-Za-z][A-Za-z\s,.'-]{1,100})",
        re.IGNORECASE,
    )
    _explicit_save_request_pattern = re.compile(
        r"\b(?:remember|save|keep|note)\b.*\b(?:this|that|memory|birthday)\b|"
        r"\bremember\s+me\s+(?:about|to)\b", re.IGNORECASE,
    )
    _explicit_reject_request_pattern = re.compile(
        r"\b(?:do\s+not|don't|dont|no|nope)\b.*\b(?:save|remember|keep)\b", re.IGNORECASE,
    )
    _date_only_pattern = re.compile(
        r"^(?:on\s+)?(?:the\s+)?(?P<date>[A-Za-z]+(?:\s+\d{1,2}(?:st|nd|rd|th)?)?|\d{1,2}(?:st|nd|rd|th)?)$",
        re.IGNORECASE,
    )
    _date_correction_pattern = re.compile(
        r"^(?:no[,\s]+)?(?:it(?:'s| is)|that(?:'s| is))\s+"
        r"(?P<date>[A-Za-z]+(?:\s+\d{1,2}(?:st|nd|rd|th)?)?|\d{1,2}(?:st|nd|rd|th)?)$",
        re.IGNORECASE,
    )
    _date_normalizer = MemoryDateNormalizer()
    def detect_simple_memory(
        self,
        message: str,
        *,
        time_context: Optional[dict] = None,
    ) -> Optional[SimpleMemoryIntent]:
        birthday_intent = self._detect_birthday(message, time_context=time_context)
        if birthday_intent is not None:
            return birthday_intent

        identity_intent = self._detect_identity_fact(message)
        if identity_intent is not None:
            return identity_intent

        remember_intent = self._detect_remember_that(message)
        if remember_intent is not None:
            return remember_intent

        return None

    def detect_contextual_memory(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: Optional[dict] = None,
    ) -> Optional[SimpleMemoryIntent]:
        contextual_birthday = self._detect_contextual_birthday_memory(
            message, conversation_history=conversation_history, time_context=time_context,
        )
        if contextual_birthday is not None:
            return contextual_birthday

        cleaned_message = self._clean_fact(message)
        date_correction = self._date_correction_pattern.match(cleaned_message)
        date_only = date_correction or self._date_only_pattern.match(cleaned_message)
        if date_only is None:
            return None

        raw_date = date_only.group("date")
        if not (
            self._date_normalizer.is_day_only(raw_date)
            or self._date_normalizer.month_from_text(raw_date)
        ):
            return None

        person = self._recent_birthday_person(conversation_history)
        if person is None:
            return None

        date_text = self._normalize_date_phrase(
            raw_date,
            time_context=time_context,
        )
        if not date_text:
            return None

        return self._birthday_intent(person, date_text)

    def is_contextual_memory_save_request(self, message: str) -> bool:
        normalized = self._normalize_reply(message)
        is_recall = normalized.startswith(("do you remember", "did you remember"))
        return not is_recall and bool(self._explicit_save_request_pattern.search(normalized))

    def is_contextual_memory_reject_request(self, message: str) -> bool:
        normalized = self._normalize_reply(message)
        return bool(self._explicit_reject_request_pattern.search(normalized))

    def saved_response(self, intent: SimpleMemoryIntent) -> str:
        return f"Got it, {self.memory_sentence(intent.content)}"

    def memory_sentence(self, content: str) -> str:
        return self._sentence_body(content)

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

        return self._birthday_intent(person, date_text)

    def _birthday_intent(
        self,
        person: str,
        date_text: str,
    ) -> SimpleMemoryIntent:
        content = f"User's {person}'s birthday is {date_text}."
        return SimpleMemoryIntent(
            memory_type="fact",
            content=content,
            importance=5,
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
            metadata={
                "fact_kind": "remember_that",
                "topic_fingerprint": f"fact:remember_that:{self._fingerprint(fact)}",
            },
        )

    def _detect_identity_fact(self, message: str) -> Optional[SimpleMemoryIntent]:
        name_match = self._name_pattern.search(message)
        if name_match is not None:
            name = self._clean_fact(name_match.group("name"))
            if len(name) >= 2:
                return SimpleMemoryIntent(
                    memory_type="fact",
                    content=f"User's name is {name}.",
                    importance=5,
                    metadata={
                        "fact_kind": "name",
                        "topic_fingerprint": "fact:identity:name",
                    },
                )

        place_match = self._live_in_pattern.search(message)
        if place_match is None:
            return None
        place = self._clean_fact(place_match.group("place"))
        if len(place) < 2:
            return None
        return SimpleMemoryIntent(
            memory_type="fact",
            content=f"User lives in {place}.",
            importance=4,
            metadata={
                "fact_kind": "location",
                "topic_fingerprint": "fact:identity:location",
            },
        )

    def _detect_contextual_birthday_memory(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: Optional[dict],
    ) -> Optional[SimpleMemoryIntent]:
        if not self._mentions_contextual_birthday_memory(message):
            return None
        return self._recent_birthday_intent(
            conversation_history,
            time_context=time_context,
        )

    def _mentions_contextual_birthday_memory(self, message: str) -> bool:
        normalized = self._normalize_reply(message)
        if "birthday" in normalized and self.is_contextual_memory_save_request(normalized):
            return True
        if self.is_contextual_memory_save_request(normalized) or (
            self.is_contextual_memory_reject_request(normalized)
        ):
            return any(token in normalized for token in {"this", "that", "memory"})
        return False

    def _recent_birthday_intent(
        self,
        conversation_history: list[dict],
        *,
        time_context: Optional[dict],
    ) -> Optional[SimpleMemoryIntent]:
        person = self._recent_birthday_person(conversation_history)
        if person is None:
            return None

        for message in reversed(conversation_history[-10:]):
            content = str(message.get("content") or "")
            explicit = self._detect_birthday(content, time_context=time_context)
            if explicit is not None:
                return explicit
            date_only = self._date_only_pattern.match(self._clean_fact(content))
            if date_only is None:
                continue
            raw_date = date_only.group("date")
            if not (
                self._date_normalizer.is_day_only(raw_date)
                or self._date_normalizer.month_from_text(raw_date)
            ):
                continue
            date_text = self._normalize_date_phrase(
                raw_date,
                time_context=time_context,
            )
            if date_text:
                return self._birthday_intent(person, date_text)
        return None

    def _normalize_date_phrase(
        self,
        raw_date: str,
        *,
        time_context: Optional[dict],
    ) -> Optional[str]:
        cleaned = self._clean_fact(raw_date)
        return self._date_normalizer.normalize(cleaned, time_context=time_context)

    def _recent_birthday_person(self, conversation_history: list[dict]) -> Optional[str]:
        recent_text = " ".join(
            str(message.get("content") or "")
            for message in conversation_history[-6:]
            if message.get("role") in {"user", "assistant"}
        ).lower()
        if "birthday" not in recent_text:
            return None
        if re.search(r"\b(my\s+)?(mom|mother|mum|mama)\b", recent_text):
            return "mom"
        if re.search(r"\b(my\s+)?(dad|father|papa)\b", recent_text):
            return "dad"
        return None

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
        body = content.strip().rstrip(".")
        replacements = (
            ("User's", "your"),
            ("User lives", "you live"),
            ("User works", "you work"),
            ("User has", "you have"),
            ("User likes", "you like"),
            ("User prefers", "you prefer"),
        )
        for old, new in replacements:
            if body.startswith(old):
                body = body.replace(old, new, 1)
                break
        return f"{body}."

    def _normalize_reply(self, message: str) -> str:
        normalized = message.lower().strip()
        normalized = re.sub(r"[,;:]+", " ", normalized)
        normalized = re.sub(r"[.!?]+$", "", normalized)
        normalized = re.sub(r"\s+", " ", normalized)
        return normalized

    def _fingerprint(self, text: str) -> str:
        normalized = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
        return normalized[:80] or "unknown"
