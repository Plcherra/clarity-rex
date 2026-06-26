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

        possessive_match = self._possessive_birthday_pattern.search(message)
        if possessive_match is not None:
            raw_person = possessive_match.group("person")
            if raw_person is not None:
                owner = self._clean_fact(possessive_match.group("owner"))
                person = self._clean_birthday_person(raw_person)
                date_text = self._normalize_date_phrase(
                    possessive_match.group("date"),
                    time_context=time_context,
                )
                if (
                    owner
                    and person
                    and date_text
                    and not self._is_first_party_possessive_owner(owner)
                ):
                    return self._third_party_birthday_intent(owner, person, date_text)

        match = self._birthday_pattern.search(message)
        if match is None:
            match = self._birthday_correction_pattern.search(message)
        if match is None:
            match = self._date_as_birthday_pattern.search(message)
        if match is None:
            match = self._inverted_birthday_pattern.search(message)
        if match is not None and match.re is self._inverted_birthday_pattern and not (
            self._date_normalizer.is_day_only(match.group("date"))
            or self._date_normalizer.month_from_text(match.group("date"))
        ):
            match = None
        if match is None:
            return None

        raw_date = match.group("date")

        person = self._clean_birthday_person(match.group("person"))
        date_text = self._normalize_date_phrase(
            raw_date,
            time_context=time_context,
        )
        if not person or not date_text:
            return None

        if self._is_broken_apostrophe_person_label(person):
            return None

        return self._birthday_intent(person, date_text)

    def _third_party_birthday_intent(
        self,
        owner: str,
        person: str,
        date_text: str,
    ) -> SimpleMemoryIntent:
        owner_clean = self._clean_fact(owner)
        person_clean = self._clean_birthday_person(person)
        entity_label = f"{owner_clean.lower()}'s {person_clean}"
        display = self._format_possessive_display_name(owner_clean, person_clean)
        return SimpleMemoryIntent(
            memory_type="fact",
            content=f"{display}'s birthday is {date_text}.",
            importance=5,
            metadata={
                "fact_kind": "birthday",
                "memory_category": "Events",
                "entity_label": entity_label,
                "entity_owner": owner_clean.lower(),
                "entity_relation": person_clean,
                "normalized_date": date_text,
                "topic_fingerprint": f"fact:birthday:{self._fingerprint(entity_label)}",
            },
        )

    def _format_possessive_display_name(self, owner: str, person: str) -> str:
        owner_display = owner.strip().title()
        person_display = self._relationship_display_name(person)
        return f"{owner_display}'s {person_display}"

    def _relationship_display_name(self, person: str) -> str:
        cleaned = self._clean_person(person)
        if cleaned in {"mom", "mother", "mum", "mama"}:
            return "Mom"
        if cleaned in {"dad", "father", "papa"}:
            return "Dad"
        return person.strip().title()

    def _is_broken_apostrophe_person_label(self, person: str) -> bool:
        normalized = self._clean_person(person)
        return bool(re.match(r"^s\s+\w+", normalized))

    def _is_first_party_possessive_owner(self, owner: str) -> bool:
        normalized = self._clean_person(owner)
        if normalized in {"my", "your", "our", "their", "i", "me", "we", "us"}:
            return True
        return normalized.startswith(("my ", "your ", "our ", "their "))

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
            content = f"User's {normalized_person}'s birthday is {date_text}."
            entity_label = normalized_person
            topic = f"fact:birthday:{normalized_person.lower()}"
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
        if not self._mentions_contextual_birthday_memory(
            message,
            conversation_history=conversation_history,
        ):
            return None
        return self._recent_birthday_intent(
            conversation_history,
            time_context=time_context,
        )

    def _mentions_contextual_birthday_memory(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> bool:
        normalized = self._normalize_reply(message)
        if "birthday" in normalized and self.is_contextual_memory_save_request(
            normalized
        ):
            return True
        if self.is_contextual_memory_save_request(normalized) or (
            self.is_contextual_memory_reject_request(normalized)
        ):
            recent_assistant = self._most_recent_assistant_message(conversation_history)
            if self._assistant_message_mentions_birthday_save(recent_assistant):
                return True
            if any(token in normalized for token in {"this", "that", "memory"}):
                return self._recent_birthday_person(conversation_history) is not None
        return False

    def _most_recent_assistant_message(self, conversation_history: list[dict]) -> str:
        for message in reversed(conversation_history):
            if message.get("role") == "assistant":
                return str(message.get("content") or "")
        return ""

    def _assistant_message_mentions_birthday_save(self, content: str) -> bool:
        normalized = content.lower()
        if "birthday" not in normalized:
            return False
        return bool(re.search(r"\b(?:save|remember|keep|memory)\b", normalized))

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
        for message in reversed(conversation_history[-6:]):
            if message.get("role") not in {"user", "assistant"}:
                continue
            person = self._birthday_person_from_text(
                str(message.get("content") or "")
            )
            if person is not None:
                return person
        return self._recent_birthday_person_from_context(conversation_history)

    def _recent_birthday_person_from_context(
        self, conversation_history: list[dict]
    ) -> Optional[str]:
        if not self._recent_birthday_topic_active(conversation_history):
            return None
        if not self._recent_birthday_pronoun_reference(conversation_history):
            return None
        return self._recent_relationship_person(conversation_history)

    def _recent_birthday_topic_active(self, conversation_history: list[dict]) -> bool:
        for message in reversed(conversation_history[-6:]):
            content = str(message.get("content") or "").lower()
            if "birthday" in content:
                return True
        return False

    def _recent_birthday_pronoun_reference(
        self, conversation_history: list[dict]
    ) -> bool:
        for message in reversed(conversation_history[-6:]):
            content = str(message.get("content") or "").lower()
            if re.search(
                r"\b(?:her|his|their|she|he|they)\b[^.!?]{0,40}\bbirthday\b",
                content,
            ) or re.search(
                r"\bbirthday\b[^.!?]{0,40}\b(?:her|his|their|she|he|they)\b",
                content,
            ):
                return True
        return False

    def _recent_relationship_person(
        self, conversation_history: list[dict]
    ) -> Optional[str]:
        for message in reversed(conversation_history[-6:]):
            if message.get("role") not in {"user", "assistant"}:
                continue
            content = str(message.get("content") or "")
            match = re.search(
                r"\b(?:my|your)\s+(?P<person>[A-Za-z][A-Za-z\s_-]{1,40}?)\b",
                content,
                re.IGNORECASE,
            )
            if match is None:
                continue
            person = self._clean_birthday_person(match.group("person"))
            if person in {
                "birthday",
                "her",
                "his",
                "its",
                "my",
                "our",
                "their",
                "your",
            }:
                continue
            if person:
                return person
        return None

    def _birthday_person_from_text(self, text: str) -> Optional[str]:
        if "birthday" not in text.lower():
            return None
        patterns = (
            r"\b(?:my|your)\s+(?P<person>[A-Za-z][A-Za-z\s_-]{1,40}?)\s*(?:'s)?\s+birthday\b",
            r"\b(?P<person>[A-Za-z][A-Za-z\s_-]{1,40}?)'s\s+birthday\b",
        )
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match is None:
                continue
            person = self._clean_birthday_person(match.group("person"))
            if person in {
                "birthday",
                "her",
                "his",
                "its",
                "my",
                "our",
                "their",
                "your",
            }:
                continue
            if person:
                return person
        return None

    def _clean_birthday_person(self, person: str) -> str:
        cleaned = re.split(
            r"\b(?:and|but|or)\s+(?:her|his|their|your|my)\b",
            person,
            maxsplit=1,
            flags=re.IGNORECASE,
        )[0]
        cleaned = re.sub(
            r"^(?:as\s+)?(?:my\s+|your\s+)?",
            "",
            cleaned.strip(),
            flags=re.IGNORECASE,
        )
        return self._clean_person(cleaned)

    def _recent_birthday_save_prompt(self, conversation_history: list[dict]) -> bool:
        for message in reversed(conversation_history[-6:]):
            if message.get("role") != "assistant":
                continue
            content = str(message.get("content") or "").lower()
            if "birthday" not in content:
                continue
            if re.search(r"\b(?:save|remember|keep|memory)\b", content):
                return True
        return False
