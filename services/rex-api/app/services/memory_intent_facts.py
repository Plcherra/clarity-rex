import re
from typing import Optional

from app.services.memory_intent_models import SimpleMemoryIntent


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

    def _detect_contextual_save_proposal_memory(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[SimpleMemoryIntent]:
        if not self.is_contextual_memory_save_request(message):
            return None
        for item in reversed(conversation_history[-8:]):
            if item.get("role") != "assistant":
                continue
            content = str(item.get("content") or "")
            normalized = self._normalize_reply(content)
            if not any(
                phrase in normalized
                for phrase in (
                    "want me to save",
                    "would you like me to save",
                    "should i save",
                    "save that",
                    "save this",
                    "saving that",
                )
            ):
                continue
            candidate = re.sub(r"\byou\b", "I", content, flags=re.IGNORECASE)
            intent = self._detect_device_fact(candidate)
            if intent is not None:
                return intent
        return None

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
