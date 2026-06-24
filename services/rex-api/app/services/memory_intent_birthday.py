import re
from typing import Optional

from app.services.memory_intent_models import SimpleMemoryIntent


class MemoryIntentBirthdayMixin:
    def _detect_birthday(
        self,
        message: str,
        *,
        time_context: Optional[dict],
    ) -> Optional[SimpleMemoryIntent]:
        self_match = self._self_birthday_pattern.search(message)
        if self_match is not None:
            date_text = self._normalize_date_phrase(
                self_match.group("date"),
                time_context=time_context,
            )
            if date_text:
                return self._birthday_intent("self", date_text)

        match = self._birthday_pattern.search(message)
        if match is None:
            match = self._birthday_correction_pattern.search(message)
        if match is None:
            match = self._inverted_birthday_pattern.search(message)
        if match is None:
            return None

        raw_date = match.group("date")
        if match.re is self._inverted_birthday_pattern and not (
            self._date_normalizer.is_day_only(raw_date)
            or self._date_normalizer.month_from_text(raw_date)
        ):
            return None

        person = self._clean_person(match.group("person"))
        date_text = self._normalize_date_phrase(
            raw_date,
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
        normalized_person = self._clean_person(person)
        if normalized_person in {"self", "user", "me", "myself"}:
            content = f"User's birthday is {date_text}."
            entity_label = "self"
            topic = "fact:birthday:self"
        else:
            content = f"User's {person}'s birthday is {date_text}."
            entity_label = person
            topic = f"fact:birthday:{person.lower()}"
        return SimpleMemoryIntent(
            memory_type="fact",
            content=content,
            importance=5,
            metadata={
                "fact_kind": "birthday",
                "memory_category": "Events",
                "entity_label": entity_label,
                "normalized_date": date_text,
                "topic_fingerprint": topic,
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
        if "birthday" in normalized and self.is_contextual_memory_save_request(
            normalized
        ):
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
            content_for_detection = content
            if message.get("role") == "assistant":
                content_for_detection = re.sub(
                    r"\byour\b",
                    "my",
                    content_for_detection,
                    flags=re.IGNORECASE,
                )
            explicit = self._detect_birthday(
                content_for_detection,
                time_context=time_context,
            )
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

    def _recent_birthday_person(
        self, conversation_history: list[dict]
    ) -> Optional[str]:
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
