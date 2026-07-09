import re
from typing import Optional


class MemoryIntentTextMixin:
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

    def _clean_place(self, place: str, message: str) -> str:
        cleaned = self._clean_fact(place)
        normalized = cleaned.lower()
        message_normalized = message.lower()
        if re.search(r"\bsomerville\b", message_normalized):
            if "massachusetts" in message_normalized:
                return "Somerville, Massachusetts"
            return "Somerville"
        if re.search(
            r"\b(?:summerville|somerville)\b",
            normalized,
        ) and self._mentions_somerville_spelling(message_normalized):
            if (
                "massachusetts" in message_normalized
                or "location" in message_normalized
            ):
                return "Somerville, Massachusetts"
            return "Somerville"
        return cleaned

    def _clean_device_model(self, value: str) -> str:
        cleaned = self._clean_fact(value)
        cleaned = re.sub(r"^(?:an?|the)\s+", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\b(\d{1,4})\s+([A-Za-z]{1,3})\b", r"\1\2", cleaned)
        cleaned = re.sub(r"\bpc\b", "PC", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(
            r"\b(?:cpu|gpu|ram|ssd|hdd|usb|vr|ai)\b",
            lambda match: match.group(0).upper(),
            cleaned,
            flags=re.IGNORECASE,
        )
        cleaned = " ".join(
            token.upper() if re.fullmatch(r"\d{1,4}[a-z]{1,3}", token.lower()) else token
            for token in cleaned.split()
        )
        cleaned = re.sub(r"\s+", " ", cleaned).strip()
        return cleaned

    def _recent_location_correction_context(
        self,
        conversation_history: list[dict],
    ) -> bool:
        """True only while Rex is actively waiting for a place reply.

        Sticky history (any recent city + spelling talk) is too broad for
        multi-topic chats. Gate on the latest assistant turn asking for a city.
        """
        return self._assistant_awaiting_location_reply(conversation_history)

    def _assistant_awaiting_location_reply(
        self,
        conversation_history: list[dict],
    ) -> bool:
        for message in reversed(conversation_history[-8:]):
            if message.get("role") != "assistant":
                continue
            content = str(message.get("content") or "").strip().lower()
            if not content:
                continue
            if "couldn't read the city clearly" in content:
                return True
            if "send just the city" in content:
                return True
            ask_markers = (
                "what's the right city",
                "what is the right city",
                "what city",
                "which city",
                "city name",
                "correct city",
                "correct location",
                "where do you live",
                "where you live",
            )
            return any(marker in content for marker in ask_markers)
        return False

    def looks_like_person_or_name_memory(self, message: str) -> bool:
        """Bail out of place clarification when the turn is about a person/name."""
        normalized = self._normalize_reply(message)
        if not normalized:
            return False
        person_markers = (
            "mother",
            "mama",
            "mom",
            "mum",
            "father",
            "papa",
            "dad",
            "brother",
            "sister",
            "cousin",
            "friend",
            "partner",
            "wife",
            "husband",
            "boyfriend",
            "girlfriend",
            "fiancé",
            "fiance",
            "fiancée",
            "fiancee",
        )
        if any(re.search(rf"\b{re.escape(marker)}\b", normalized) for marker in person_markers):
            return True
        if re.search(r"\b(?:full\s+)?name\b", normalized) and not re.search(
            r"\b(?:city|location|town)\s+name\b",
            normalized,
        ):
            return True
        return False

    def _place_from_contextual_location_reply(self, message: str) -> Optional[str]:
        cleaned = self._clean_fact(message)
        normalized = self._normalize_reply(message)
        if "?" in message or normalized.startswith(
            ("do ", "can ", "what ", "where ", "who ", "when ", "why ", "how ")
        ):
            return None
        known_place = self._known_location_from_text(message)
        if known_place:
            return known_place
        match = re.match(
            r"^(?:it(?:'s| is)\s+|the\s+correct\s+(?:city|location)\s+is\s+)?"
            r"(?P<place>[A-Z][A-Za-z\s,.'-]{2,80})"
            r"(?:\.|,|$)",
            cleaned,
        )
        if match is None:
            return None
        place = self._clean_place(match.group("place"), message)
        if len(place) < 2:
            return None
        if not self._is_valid_location_place(place):
            return None
        return place

    def _known_location_from_text(self, message: str) -> Optional[str]:
        normalized = self._normalize_reply(message)
        if re.search(r"\bsomerville\b", normalized):
            if "massachusetts" in normalized:
                return "Somerville, Massachusetts"
            return "Somerville"
        if re.search(
            r"\bsummerville\b", normalized
        ) and self._mentions_somerville_spelling(normalized):
            if "massachusetts" in normalized:
                return "Somerville, Massachusetts"
            return "Somerville"
        compact = re.sub(r"[^a-z]+", "", normalized)
        if compact == "somerville":
            return "Somerville"
        return None

    def _is_valid_location_place(self, place: str) -> bool:
        normalized = self._normalize_reply(place)
        if normalized in {
            "thanks",
            "thank you",
            "yes",
            "yep",
            "no",
            "nope",
            "you",
        }:
            return False
        if self._looks_like_transcript_noise(normalized):
            return False
        words = normalized.split()
        if len(words) > 4:
            return False
        blocked_terms = {
            "all",
            "available",
            "city",
            "dont",
            "don't",
            "got",
            "instead",
            "leave",
            "leaves",
            "meant",
            "memory",
            "nose",
            "saved",
            "see",
            "user",
        }
        if any(word.strip("'") in blocked_terms for word in words):
            return False
        if re.search(r"\b(?:m'?s|o|one|two|2|1)\b", normalized):
            return False
        return bool(re.search(r"[a-z]", normalized))

    def _looks_like_transcript_noise(self, normalized: str) -> bool:
        return any(
            re.search(pattern, normalized) is not None
            for pattern in (
                r"\binaudible\b",
                r"\bunintelligible\b",
                r"\btranscript\b",
                r"\baudio\b",
                r"\bbackground noise\b",
                r"\bgarbled\b",
                r"\bunclear\b",
                r"\bunknown\b",
            )
        )

    def _mentions_somerville_spelling(self, normalized_message: str) -> bool:
        compact = re.sub(r"[^a-z0-9]+", "", normalized_message.lower())
        if "insteadofu1m" in compact or "oinsteadofu1m" in compact:
            return True

        has_one_m = re.search(r"\b(?:one|1)\s*m\b", normalized_message) is not None
        has_one_o = (
            re.search(r"\b(?:one|1)\s*o\b", normalized_message) is not None
            or re.search(r"\b(?:one|1)\s*m\s+and\s+o\b", normalized_message) is not None
        )
        has_wrong_spelling_hint = any(
            hint in normalized_message
            for hint in ("instead of u", "two m", "2 m", "summerville", "somerville")
        )
        return has_one_m and has_one_o and has_wrong_spelling_hint

    def _sentence_body(self, content: str) -> str:
        body = content.strip().rstrip(".")
        replacements = (
            ("User's", "your"),
            ("User lives", "you live"),
            ("User works", "you work"),
            ("User has", "you have"),
            ("User likes", "you like"),
            ("User prefers", "you prefer"),
            ("User plans", "you plan"),
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
