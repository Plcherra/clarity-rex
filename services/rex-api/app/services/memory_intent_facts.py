import re
from typing import Optional

from app.services.memory_intent_models import SimpleMemoryIntent

_RELATIONSHIP_ROLES = (
    "best friend",
    "friend",
    "brother",
    "sister",
    "cousin",
    "partner",
    "wife",
    "husband",
    "boyfriend",
    "girlfriend",
    "fiancé",
    "fiance",
    "fiancée",
    "fiancee",
    "mother",
    "mama",
    "mom",
    "mum",
    "father",
    "papa",
    "dad",
)
_RELATIONSHIP_ROLE_ALT = "|".join(
    sorted((re.escape(role) for role in _RELATIONSHIP_ROLES), key=len, reverse=True)
)
_RELATIONSHIP_SAVE_USER_PATTERN = re.compile(
    r"\b(?:save|remember|keep)\s+my\s+"
    rf"(?P<relationship>{_RELATIONSHIP_ROLE_ALT})\s+"
    r"(?P<name>[\w][\w\s.'-]{1,60})",
    re.IGNORECASE | re.UNICODE,
)
_RELATIONSHIP_NAME_CALLED_PATTERN = re.compile(
    rf"\b(?:my\s+)?(?P<relationship>{_RELATIONSHIP_ROLE_ALT})(?:'s)?\s+name\b"
    r".{0,200}?\b(?:(?:is\s+)?called|named)\s+"
    r"(?P<name>[\w][\w'-]{0,40})",
    re.IGNORECASE | re.UNICODE | re.DOTALL,
)
_RELATIONSHIP_NAME_IS_PATTERN = re.compile(
    rf"\b(?:my\s+)?(?P<relationship>{_RELATIONSHIP_ROLE_ALT})(?:'s)?\s+name\s+is\s+"
    r"(?P<name>[\w][\w'-]{0,40})",
    re.IGNORECASE | re.UNICODE,
)
_RELATIONSHIP_IS_PATTERN = re.compile(
    rf"\bmy\s+(?P<relationship>{_RELATIONSHIP_ROLE_ALT})\s+is\s+"
    r"(?P<name>[\w][\w'-]{0,40})",
    re.IGNORECASE | re.UNICODE,
)
_ASSISTANT_RELATIONSHIP_SAVE_PATTERN = re.compile(
    r"\bsave\s+(?P<name>[\w][\w\s.'-]{1,40}?)\s+as\s+your\s+"
    r"(?P<relationship>[^?.!]+)",
    re.IGNORECASE | re.UNICODE,
)
_DEVICE_TAIL = (
    r"(?:\bpc\b|\bcomputer\b|\blaptop\b|\bdesktop\b|\bphone\b|\btablet\b|"
    r"\bconsole\b|\b[A-Za-z][A-Za-z0-9 -]*\d{1,4}\s*[A-Za-z]{0,3}\b)"
)
_MENTIONED_DEVICE_PATTERN = re.compile(
    rf"\bmentioned\s+(?:having\s+)?(?:an?\s+|the\s+)?(?P<device>[^.!?]{{2,90}}?"
    rf"{_DEVICE_TAIL})",
    re.IGNORECASE,
)
_HAVING_DEVICE_PATTERN = re.compile(
    rf"\b(?:having|with|owns?|uses?)\s+(?:an?\s+|the\s+)?(?P<device>[^.!?]{{2,90}}?"
    rf"{_DEVICE_TAIL})",
    re.IGNORECASE,
)
_DEVICE_IS_PATTERN = re.compile(
    r"\b(?:your|my)\s+(?:pc|computer|laptop|device|model)\s+is\s+"
    r"(?:an?\s+)?(?P<device>[^.!?]{2,90})",
    re.IGNORECASE,
)
_SAVE_OFFER_PHRASES = (
    "want me to save",
    "would you like me to save",
    "should i save",
    "want me to remember",
    "would you like me to remember",
    "save to clarity knows",
    "save that",
    "save this",
    "saving that",
    "keep that in memory",
    "remember that for",
)


class MemoryIntentFactMixin:
    def _detect_remember_that(self, message: str) -> Optional[SimpleMemoryIntent]:
        match = self._remember_that_pattern.search(message)
        if match is None:
            return None

        fact = self._clean_fact(match.group("fact"))
        if self._looks_like_transcript_noise(self._normalize_reply(fact)):
            return None
        if len(fact) < 8:
            return None

        content = f"{fact[0].upper()}{fact[1:]}."
        return SimpleMemoryIntent(
            memory_type="fact",
            content=content,
            importance=4,
            metadata={
                "fact_kind": "remember_that",
                "memory_category": "Facts",
                "topic_fingerprint": f"fact:remember_that:{self._fingerprint(fact)}",
            },
        )

    def _detect_identity_fact(self, message: str) -> Optional[SimpleMemoryIntent]:
        negative_location_correction = (
            self._negative_location_correction_pattern.search(message)
        )
        if negative_location_correction is not None:
            place = self._clean_place(
                negative_location_correction.group("place"),
                message,
            )
            if len(place) >= 2 and self._is_valid_location_place(place):
                return self._location_intent(place)

        location_correction = self._location_correction_pattern.search(message)
        if location_correction is not None:
            place = self._clean_place(location_correction.group("place"), message)
            if len(place) >= 2 and self._is_valid_location_place(place):
                return self._location_intent(place)

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
                        "memory_category": "People",
                        "topic_fingerprint": "fact:identity:name",
                    },
                )

        place_match = self._live_in_pattern.search(message)
        if place_match is None:
            return None
        place = self._clean_fact(place_match.group("place"))
        if len(place) < 2:
            return None
        return self._location_intent(place)

    def _detect_work_fact(self, message: str) -> Optional[SimpleMemoryIntent]:
        match = self._work_at_pattern.search(message)
        if match is None:
            return None
        workplace = self._clean_fact(match.group("workplace"))
        if len(workplace) < 2:
            return None
        return SimpleMemoryIntent(
            memory_type="fact",
            content=f"User works at {workplace}.",
            importance=4,
            metadata={
                "fact_kind": "work",
                "memory_category": "People",
                "workplace": workplace,
                "topic_fingerprint": "fact:identity:work",
            },
        )

    def _detect_device_fact(self, message: str) -> Optional[SimpleMemoryIntent]:
        if self.is_memory_lookup_or_topic_shift(message):
            return None
        match = self._device_fact_pattern.search(message)
        if match is None:
            return None

        device = self._clean_device_model(match.group("device"))
        if len(device) < 4:
            return None
        article = "an" if device[:1].lower() in {"a", "e", "i", "o", "u"} else "a"
        return SimpleMemoryIntent(
            memory_type="fact",
            content=f"User has {article} {device}.",
            importance=4,
            metadata={
                "fact_kind": "device",
                "memory_category": "Facts",
                "device_model": device,
            },
        )

    def _detect_relationship_person(self, message: str) -> Optional[SimpleMemoryIntent]:
        match = _RELATIONSHIP_SAVE_USER_PATTERN.search(message)
        if match is None:
            match = _RELATIONSHIP_NAME_CALLED_PATTERN.search(message)
        if match is None:
            match = _RELATIONSHIP_NAME_IS_PATTERN.search(message)
        if match is None:
            match = _RELATIONSHIP_IS_PATTERN.search(message)
        if match is None:
            match = _ASSISTANT_RELATIONSHIP_SAVE_PATTERN.search(message)
        if match is None:
            return None
        return self._relationship_person_intent(
            match.group("name"),
            match.group("relationship"),
        )

    def _relationship_person_intent(
        self,
        name: str,
        relationship: str,
    ) -> Optional[SimpleMemoryIntent]:
        clean_name = self._clean_fact(name)
        clean_relationship = self._clean_person(relationship)
        if len(clean_name) < 2 or len(clean_relationship) < 2:
            return None
        if clean_name.lower() in {"birthday", "memory", "friend", "called", "named"}:
            return None
        display_name = clean_name.title()
        entity_label = self._normalize_name(clean_name)
        return SimpleMemoryIntent(
            memory_type="fact",
            content=f"User's {clean_relationship} is {display_name}.",
            importance=4,
            metadata={
                "fact_kind": "relationship",
                "memory_category": "People",
                "entity_label": entity_label,
                "relationship": clean_relationship,
                "topic_fingerprint": (
                    f"fact:relationship:{entity_label}:"
                    f"{self._fingerprint(clean_relationship)}"
                ),
            },
        )

    def _normalize_name(self, value: str) -> str:
        return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")

    def _device_intent_from_label(self, device: str) -> Optional[SimpleMemoryIntent]:
        cleaned = self._clean_device_model(device)
        if len(cleaned) < 4:
            return None
        article = "an" if cleaned[:1].lower() in {"a", "e", "i", "o", "u"} else "a"
        return SimpleMemoryIntent(
            memory_type="fact",
            content=f"User has {article} {cleaned}.",
            importance=4,
            metadata={
                "fact_kind": "device",
                "memory_category": "Facts",
                "device_model": cleaned,
            },
        )

    def _detect_mentioned_device_fact(
        self,
        message: str,
        *,
        from_conversation_history: bool = False,
    ) -> Optional[SimpleMemoryIntent]:
        if not from_conversation_history and self.is_memory_lookup_or_topic_shift(message):
            return None
        match = _MENTIONED_DEVICE_PATTERN.search(message)
        if match is None:
            return None
        return self._device_intent_from_label(match.group("device"))

    def _detect_having_device_fact(
        self,
        message: str,
        *,
        from_conversation_history: bool = False,
    ) -> Optional[SimpleMemoryIntent]:
        if not from_conversation_history and self.is_memory_lookup_or_topic_shift(message):
            return None
        match = _HAVING_DEVICE_PATTERN.search(message)
        if match is None:
            return None
        return self._device_intent_from_label(match.group("device"))

    def _detect_device_is_fact(
        self,
        message: str,
        *,
        from_conversation_history: bool = False,
    ) -> Optional[SimpleMemoryIntent]:
        if not from_conversation_history and self.is_memory_lookup_or_topic_shift(message):
            return None
        match = _DEVICE_IS_PATTERN.search(message)
        if match is None:
            return None
        return self._device_intent_from_label(match.group("device"))

    def _extract_device_intent_from_text(
        self,
        message: str,
        *,
        from_conversation_history: bool = False,
    ) -> Optional[SimpleMemoryIntent]:
        if not message.strip():
            return None
        for detector in (
            self._detect_mentioned_device_fact,
            self._detect_having_device_fact,
            self._detect_device_is_fact,
        ):
            intent = detector(
                message,
                from_conversation_history=from_conversation_history,
            )
            if intent is not None:
                return intent
        if from_conversation_history:
            candidate = re.sub(r"\byou\b", "I", message, flags=re.IGNORECASE)
            candidate = re.sub(r"\byour\b", "my", candidate, flags=re.IGNORECASE)
            return self._detect_device_fact(candidate)
        return None

    def _assistant_offered_save(self, content: str) -> bool:
        normalized = self._normalize_reply(content)
        return any(phrase in normalized for phrase in _SAVE_OFFER_PHRASES)

    def _intent_from_conversation_history(
        self,
        conversation_history: list[dict],
        *,
        time_context: Optional[dict] = None,
    ) -> Optional[SimpleMemoryIntent]:
        for item in reversed(conversation_history[-8:]):
            content = str(item.get("content") or "")
            if not content.strip():
                continue
            intent = self._extract_device_intent_from_text(
                content,
                from_conversation_history=True,
            )
            if intent is not None:
                return intent
            if item.get("role") == "assistant":
                candidate = re.sub(r"\byou\b", "I", content, flags=re.IGNORECASE)
                candidate = re.sub(r"\byour\b", "my", candidate, flags=re.IGNORECASE)
                intent = self._detect_birthday(
                    candidate,
                    time_context=time_context,
                )
                if intent is not None:
                    return intent
            intent = self._detect_relationship_person(content)
            if intent is not None:
                return intent
            intent = self._detect_birthday(content, time_context=time_context)
            if intent is not None:
                return intent
        return None

    def _detect_contextual_save_proposal_memory(
        self,
        message: str,
        *,
        conversation_history: list[dict],
        time_context: Optional[dict] = None,
    ) -> Optional[SimpleMemoryIntent]:
        if not self.is_contextual_memory_save_request(message):
            return None

        normalized = self._normalize_reply(message)
        if re.search(
            r"\b(?:save|remember|keep)\b",
            normalized,
        ) and re.search(r"\b(?:pc|computer|laptop|device|model)\b", normalized):
            intent = self._intent_from_conversation_history(
                conversation_history,
                time_context=time_context,
            )
            if intent is not None:
                return intent

        for item in reversed(conversation_history[-8:]):
            if item.get("role") != "assistant":
                continue
            content = str(item.get("content") or "")
            if not self._assistant_offered_save(content):
                continue
            intent = self._intent_from_conversation_history(
                [item],
                time_context=time_context,
            )
            if intent is not None:
                return intent

        return self._intent_from_conversation_history(
            conversation_history,
            time_context=time_context,
        )

    def _detect_contextual_location_memory(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[SimpleMemoryIntent]:
        if self.is_memory_lookup_or_topic_shift(message):
            return None
        if not self._recent_location_correction_context(conversation_history):
            return None

        normalized = self._normalize_reply(message)
        recent_text = " ".join(
            str(item.get("content") or "")
            for item in conversation_history[-8:]
            if item.get("role") in {"user", "assistant"}
        ).lower()
        if self._mentions_somerville_spelling(normalized):
            if "massachusetts" in normalized or "massachusetts" in recent_text:
                return self._location_intent("Somerville, Massachusetts")
            return self._location_intent("Somerville")

        direct_place = self._place_from_contextual_location_reply(message)
        if direct_place:
            return self._location_intent(direct_place)

        return None

    def _location_intent(self, place: str) -> SimpleMemoryIntent:
        return SimpleMemoryIntent(
            memory_type="fact",
            content=f"User lives in {place}.",
            importance=4,
            metadata={
                "fact_kind": "location",
                "memory_category": "Places",
                "topic_fingerprint": "fact:identity:location",
            },
        )

    def _detect_personal_plan(
        self,
        message: str,
        *,
        conversation_history: Optional[list[dict]] = None,
    ) -> Optional[SimpleMemoryIntent]:
        draft = self._personal_plan_parser.detect(
            message,
            conversation_history=conversation_history,
        )
        if draft is None:
            return None
        metadata = dict(draft.metadata)
        metadata.setdefault("memory_category", "Goals")
        return SimpleMemoryIntent(
            memory_type="event",
            content=draft.content,
            importance=draft.importance,
            metadata=metadata,
        )

    def _detect_preference(self, message: str) -> Optional[SimpleMemoryIntent]:
        match = self._preference_pattern.search(message)
        if match is None:
            match = self._like_preference_pattern.search(message)
        if match is None:
            return None

        preferred = self._clean_fact(match.group("preferred"))
        other = self._clean_fact(match.group("other"))
        if len(preferred) < 2 or len(other) < 2:
            return None

        content = f"User prefers {preferred} over {other}."
        return SimpleMemoryIntent(
            memory_type="preference",
            content=content,
            importance=4,
            metadata={
                "fact_kind": "preference",
                "memory_category": "Preferences",
                "preferred": preferred,
                "compared_to": other,
                "topic_fingerprint": (
                    f"preference:{self._fingerprint(preferred)}:"
                    f"{self._fingerprint(other)}"
                ),
            },
        )
