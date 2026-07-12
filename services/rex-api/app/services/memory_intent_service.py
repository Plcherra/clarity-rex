import re
from typing import Optional

from app.services.memory_date_normalizer import MemoryDateNormalizer
from app.services.memory_intent_birthday import MemoryIntentBirthdayMixin
from app.services.memory_intent_contextual_save import MemoryIntentContextualSaveMixin
from app.services.memory_intent_facts import MemoryIntentFactMixin
from app.services.memory_intent_models import SimpleMemoryIntent
from app.services.memory_intent_relationship import MemoryIntentRelationshipMixin
from app.services.memory_intent_text import MemoryIntentTextMixin
from app.services.personal_plan_intent_parser import PersonalPlanIntentParser


class MemoryIntentService(
    MemoryIntentBirthdayMixin,
    MemoryIntentRelationshipMixin,
    MemoryIntentContextualSaveMixin,
    MemoryIntentFactMixin,
    MemoryIntentTextMixin,
):
    """Detects low-risk memories that can be confirmed naturally in chat."""

    _birthday_pattern = re.compile(
        r"\bmy\s+(?P<person>[A-Za-z][A-Za-z\s_-]{1,40}?)\s*(?:'s)?\s+"
        r"birthday\s+(?:is|it's|it is|falls on|will be|on)\s+"
        r"(?P<date>[^,.!?]{2,60})",
        re.IGNORECASE,
    )
    _birthday_correction_pattern = re.compile(
        r"\b(?:no[,\s]+)?(?:my\s+)?(?P<person>[A-Za-z][A-Za-z\s_-]{1,40}?)"
        r"\s*(?:'s)?\s+birthday\s+(?:is|it's|it is|was|will be)\s+"
        r"(?P<date>[^,.!?]{2,60})",
        re.IGNORECASE,
    )
    _inverted_birthday_pattern = re.compile(
        r"\b(?:on\s+)?(?:the\s+)?"
        r"(?P<date>[A-Za-z]+(?:\s+\d{1,2}(?:st|nd|rd|th)?)?|\d{1,2}(?:st|nd|rd|th)?)"
        r"\s*,?\s*(?:it(?:'s| is)\s+)?(?:my\s+)?"
        r"(?P<person>[A-Za-z][A-Za-z\s_-]{1,40}?)\s*(?:'s)?\s+birthday\b",
        re.IGNORECASE,
    )
    _date_as_birthday_pattern = re.compile(
        r"\b(?P<date>[A-Za-z]+(?:\s+\d{1,2}(?:st|nd|rd|th)?)?|\d{1,2}(?:st|nd|rd|th)?)"
        r"\s+as\s+(?:my\s+|your\s+)?"
        r"(?P<person>[A-Za-z][A-Za-z\s_-]{1,40}?)\s*(?:'s)?\s+birthday\b",
        re.IGNORECASE,
    )
    _self_birthday_pattern = re.compile(
        r"\bmy\s+birthday\s+(?:is|it's|it is|falls on|will be|on)\s+"
        r"(?P<date>[^,.!?]{2,60})",
        re.IGNORECASE,
    )
    _possessive_birthday_pattern = re.compile(
        r"\b(?P<owner>[A-Za-z][A-Za-z\s.'-]{0,40}?)'s\s+"
        r"(?:(?P<person>[A-Za-z][A-Za-z\s_-]{0,40}?)\s*(?:'s)?\s+)?"
        r"birthday\s+(?:is|it's|it is|was|will be|on)\s+"
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
    _location_correction_pattern = re.compile(
        r"\b(?:change|correct|update|fix)\s+(?:my\s+)?(?:city|location)\b.*?"
        r"(?:\bit(?:'s| is)\b|\bto\b)\s+(?P<place>[A-Za-z][A-Za-z\s,.'-]{1,120})",
        re.IGNORECASE,
    )
    _negative_location_correction_pattern = re.compile(
        r"\bi\s+(?:do\s+not|don't|dont)\s+live\s+in\s+"
        r"(?P<old_place>[A-Za-z][A-Za-z\s,.'-]{1,80})\b.*?"
        r"(?:\bit(?:'s| is)\b|\bi\s+live\s+in\b)\s+"
        r"(?P<place>[A-Za-z][A-Za-z\s,.'-]{1,120})",
        re.IGNORECASE,
    )
    _work_at_pattern = re.compile(
        r"\bi\s+work\s+(?:at|for)\s+(?P<workplace>[^.!?;,]{2,100})",
        re.IGNORECASE,
    )
    _device_fact_pattern = re.compile(
        r"\b(?:i\s+(?:have|own|use)(?!\s+to\b)|it(?:'s| is)|that(?:'s| is))\s+"
        r"(?:an?\s+|the\s+)?(?P<device>[^.!?]{2,90}?"
        r"(?:\bpc\b|\bcomputer\b|\blaptop\b|\bdesktop\b|\bphone\b|\btablet\b|"
        r"\bconsole\b|\b[A-Za-z][A-Za-z0-9 -]*\d{1,4}\s*[A-Za-z]{0,3}\b))",
        re.IGNORECASE,
    )
    _preference_pattern = re.compile(
        r"\bi\s+prefer\s+(?P<preferred>[^.!?]{2,80}?)\s+"
        r"(?:over|to|more\s+than|instead\s+of)\s+(?P<other>[^.!?]{2,80})",
        re.IGNORECASE,
    )
    _like_preference_pattern = re.compile(
        r"\bi\s+like\s+(?P<preferred>[^.!?]{2,80}?)\s+"
        r"(?:more\s+than|better\s+than|over)\s+(?P<other>[^.!?]{2,80})",
        re.IGNORECASE,
    )
    _explicit_save_request_pattern = re.compile(
        r"\b(?:remember|save|keep|note)\b.*\b(?:this|that|memory|birthday)\b|"
        r"\bremember\s+me\s+(?:about|to)\b",
        re.IGNORECASE,
    )
    _explicit_reject_request_pattern = re.compile(
        r"\b(?:do\s+not|don't|dont|no|nope)\b.*\b(?:save|remember|keep)\b",
        re.IGNORECASE,
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
    _personal_plan_parser = PersonalPlanIntentParser()

    def detect_simple_memory(
        self,
        message: str,
        *,
        time_context: Optional[dict] = None,
    ) -> Optional[SimpleMemoryIntent]:
        if self._looks_like_goal_or_commitment(message):
            return None

        birthday_intent = self._detect_birthday(message, time_context=time_context)
        if birthday_intent is not None:
            return birthday_intent

        for detector in (
            self._detect_identity_fact,
            self._detect_work_fact,
            self._detect_relationship_person,
            self._detect_device_fact,
            self._detect_preference,
            self._detect_personal_plan,
            self._detect_remember_that,
        ):
            intent = detector(message)
            if intent is not None:
                return intent
        return None

    def detect_contextual_memory(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: Optional[dict] = None,
    ) -> Optional[SimpleMemoryIntent]:
        contextual_location = self._detect_contextual_location_memory(
            message,
            conversation_history=conversation_history,
        )
        if contextual_location is not None:
            return contextual_location

        contextual_save_proposal = self._detect_contextual_save_proposal_memory(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if contextual_save_proposal is not None:
            return contextual_save_proposal

        contextual_relationship = self._detect_contextual_relationship_name(
            message,
            conversation_history=conversation_history,
        )
        if contextual_relationship is not None:
            return contextual_relationship

        contextual_birthday = self._detect_contextual_birthday_memory(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )
        if contextual_birthday is not None:
            return contextual_birthday

        personal_plan = self._detect_personal_plan(
            message,
            conversation_history=conversation_history,
        )
        if personal_plan is not None:
            return personal_plan

        return self._detect_contextual_date_memory(
            message,
            conversation_history=conversation_history,
            time_context=time_context,
        )

    def is_contextual_memory_save_request(self, message: str) -> bool:
        normalized = self._normalize_reply(message)
        is_recall = normalized.startswith(("do you remember", "did you remember"))
        if is_recall:
            return False
        if normalized in {
            "yes",
            "yes please",
            "yep",
            "yeah",
            "sure",
            "please",
            "please do",
            "do it",
            "save it",
            "save that",
            "save this",
        }:
            return True
        if re.search(r"\b(?:save|remember|keep|note)\s+(?:it|that|this)\b", normalized):
            return True
        return bool(self._explicit_save_request_pattern.search(normalized))

    def is_contextual_memory_reject_request(self, message: str) -> bool:
        normalized = self._normalize_reply(message)
        return bool(self._explicit_reject_request_pattern.search(normalized))

    def needs_contextual_location_clarification(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> bool:
        if self.is_memory_lookup_or_topic_shift(message):
            return False
        if self.looks_like_person_or_name_memory(message):
            return False
        if not self._recent_location_correction_context(conversation_history):
            return False
        if self._detect_contextual_location_memory(
            message,
            conversation_history=conversation_history,
        ):
            return False

        normalized = self._normalize_reply(message)
        if not normalized:
            return False
        if "?" in message or normalized.startswith(
            ("do ", "can ", "what ", "where ", "who ", "when ", "why ", "how ")
        ):
            return False
        if normalized in {
            "thanks",
            "thank you",
            "you",
            "yes",
            "yep",
            "no",
            "nope",
            "ok",
            "okay",
        }:
            return False
        return True

    def needs_direct_location_clarification(self, message: str) -> bool:
        if self.is_memory_lookup_or_topic_shift(message):
            return False
        location_correction = self._location_correction_pattern.search(message)
        if location_correction is None:
            location_correction = self._negative_location_correction_pattern.search(
                message,
            )
        if location_correction is None:
            return False

        place = self._clean_place(location_correction.group("place"), message)
        return not self._is_valid_location_place(place)

    def needs_unclear_memory_clarification(self, message: str) -> bool:
        normalized = self._normalize_reply(message)
        if not normalized:
            return False
        if not any(
            token in normalized.split()
            for token in {
                "remember",
                "save",
                "keep",
                "note",
                "change",
                "correct",
                "update",
                "fix",
            }
        ):
            return False
        return self._looks_like_transcript_noise(normalized)

    def unclear_memory_clarification_response(self) -> str:
        return (
            "I couldn't read that clearly enough to save it. "
            "Please send the exact detail you want me to remember."
        )

    def is_memory_lookup_or_topic_shift(self, message: str) -> bool:
        """Protect recall/search turns from the direct memory write path."""

        normalized = self._normalize_reply(message)
        if not normalized:
            return False

        lookup_phrases = (
            "what do you know",
            "what do you remember",
            "what information",
            "do you know",
            "do you remember",
            "anything about",
            "information about",
            "look into",
            "find any mention",
            "find mentions",
            "check old chat",
            "check old chats",
            "check the old chat",
            "check the old chats",
            "search old chat",
            "search old chats",
            "old chat",
            "old chats",
            "old conversation",
            "old conversations",
            "past chat",
            "past chats",
            "previous chat",
            "previous chats",
        )
        if any(phrase in normalized for phrase in lookup_phrases):
            return True
        lookup_starters = (
            "can ",
            "could ",
            "did ",
            "do ",
            "find ",
            "how ",
            "look ",
            "search ",
            "what ",
            "when ",
            "where ",
            "who ",
            "why ",
        )
        recall_terms = (
            "chat",
            "chats",
            "conversation",
            "conversations",
            "information",
            "know",
            "mention",
            "mentions",
            "memories",
            "memory",
            "remember",
            "said",
            "told",
        )
        return normalized.startswith(lookup_starters) and any(
            term in normalized.split() for term in recall_terms
        )

    def location_clarification_response(self) -> str:
        return (
            "I couldn't read the city clearly enough to save it. "
            "Please send just the city name, like Somerville or "
            "Somerville, Massachusetts."
        )

    def saved_response(self, intent: SimpleMemoryIntent) -> str:
        return f"Got it, {self.memory_sentence(intent.content)}"

    def memory_sentence(self, content: str) -> str:
        return self._sentence_body(content)

    def rejected_response(self) -> str:
        return "No problem. I won't save that."

    def _detect_contextual_date_memory(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: Optional[dict],
    ) -> Optional[SimpleMemoryIntent]:
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

    def _looks_like_goal_or_commitment(self, message: str) -> bool:
        if re.search(
            r"\b(?:"
            r"(?:my\s+)?(?:next\s+)?checklist\b|"
            r"next\s+month(?:'?s)?\s+(?:purchase|checklist|shopping)\b|"
            r"(?:purchase|shopping)\s+(?:plan|list|checklist)\b|"
            r"hold\s+me\s+accountable|"
            r"(?:remind|remember)\s+me\s+to|"
            r"(?:set|create|add)\s+(?:a\s+)?reminder\s+to|"
            r"\bmy\s+goal\s+is\b|"
            r"(?:track|save|add)\s+.+\s+as\s+(?:a\s+)?(?:goal|commitment)\b"
            r")\b",
            message,
            re.IGNORECASE,
        ):
            return True
        if re.search(
            r"\bi\s+(?:need|have)\s+to\s+"
            r"(?:upgrade|install|buy|get|replace|purchase|add|pick\s+up)\b",
            message,
            re.IGNORECASE,
        ):
            return True
        if re.search(
            r"\bi\s+(?:need|have)\s+to\s+.+\b(?:on|by)\b",
            message,
            re.IGNORECASE,
        ):
            return True
        return False
