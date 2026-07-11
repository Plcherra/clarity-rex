"""Relationship / person-name memory intent detection."""

from __future__ import annotations

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
_RELATIONSHIP_NAME_AS_PATTERN = re.compile(
    r"\b(?:save|remember|keep|update|change|set|put)\s+(?:my\s+)?"
    rf"(?P<relationship>{_RELATIONSHIP_ROLE_ALT})(?:'s)?\s+name\s+"
    r"(?:as|to)\s+(?P<name>[\w][\w'-]{0,40})",
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
_RELATIONSHIP_NAME_TOPIC_PATTERN = re.compile(
    r"\b(?:save|remember|keep|update|change|set|put|what(?:'s| is))\s+"
    r"(?:my\s+)?"
    rf"(?P<relationship>{_RELATIONSHIP_ROLE_ALT})(?:'s)?\s+name\b",
    re.IGNORECASE | re.UNICODE,
)
_GENERIC_PERSON_ROLE_ALT = r"(?:girl|guy|woman|man|person|friend)"
_GENERIC_PERSON_NAME_TOPIC_PATTERN = re.compile(
    r"\b(?:save|remember|keep|update|change|set|put|what(?:'s| is))\s+"
    r"(?:the\s+|my\s+|a\s+)?"
    rf"(?P<relationship>{_GENERIC_PERSON_ROLE_ALT})(?:'s)?\s+name\b",
    re.IGNORECASE | re.UNICODE,
)
_NAME_REPLY_PATTERN = re.compile(
    r"^(?:it(?:'s| is|s)\s+|that(?:'s| is)\s+|her\s+name\s+is\s+|his\s+name\s+is\s+)?"
    r"(?P<name>[A-Za-z][\w'-]{1,40})\.?$",
    re.IGNORECASE | re.UNICODE,
)
_BLOCKED_NAME_TOKENS = {
    "birthday",
    "memory",
    "friend",
    "called",
    "named",
    "yes",
    "no",
    "ok",
    "okay",
    "please",
    "thanks",
    "thank",
    "mom",
    "mama",
    "mother",
    "dad",
    "father",
}


class MemoryIntentRelationshipMixin:
    """Detect relationship person facts and contextual name replies."""

    def _detect_relationship_person(self, message: str) -> Optional[SimpleMemoryIntent]:
        match = _RELATIONSHIP_NAME_AS_PATTERN.search(message)
        if match is None:
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

    def _detect_contextual_relationship_name(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[SimpleMemoryIntent]:
        """Two-turn: 'update my mama's name?' → 'Its Ariadyna'."""
        relationship = self._recent_relationship_name_topic(conversation_history)
        if not relationship:
            return None
        name = self._extract_name_reply(message)
        if not name:
            return None
        return self._relationship_person_intent(name, relationship)

    def _relationship_person_intent(
        self,
        name: str,
        relationship: str,
    ) -> Optional[SimpleMemoryIntent]:
        clean_name = self._clean_fact(name)
        clean_relationship = self._clean_person(relationship)
        if len(clean_name) < 2 or len(clean_relationship) < 2:
            return None
        if clean_name.lower() in _BLOCKED_NAME_TOKENS:
            return None
        display_name = clean_name.title()
        entity_label = self._normalize_relationship_name(clean_name)
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
                    f"fact:relationship:{self._fingerprint(clean_relationship)}"
                ),
            },
        )

    def _recent_relationship_name_topic(
        self,
        conversation_history: list[dict],
    ) -> Optional[str]:
        for item in reversed(conversation_history[-8:]):
            if item.get("role") not in {"user", "assistant"}:
                continue
            content = str(item.get("content") or "")
            match = _RELATIONSHIP_NAME_TOPIC_PATTERN.search(content)
            if match is None:
                match = _GENERIC_PERSON_NAME_TOPIC_PATTERN.search(content)
            if match is None:
                # Also catch "Can you update my mama's name?" without save verbs
                # already covered; and "mother's name" talk.
                soft = re.search(
                    rf"\b(?:my\s+)?(?P<relationship>{_RELATIONSHIP_ROLE_ALT})"
                    r"(?:'s)?\s+name\b",
                    content,
                    re.IGNORECASE | re.UNICODE,
                )
                if soft is None:
                    soft = re.search(
                        r"\b(?:the\s+|my\s+|a\s+)?"
                        rf"(?P<relationship>{_GENERIC_PERSON_ROLE_ALT})"
                        r"(?:'s)?\s+name\b",
                        content,
                        re.IGNORECASE | re.UNICODE,
                    )
                if soft is None:
                    continue
                return self._clean_person(soft.group("relationship"))
            return self._clean_person(match.group("relationship"))
        return None

    def _extract_name_reply(self, message: str) -> Optional[str]:
        cleaned = self._clean_fact(message)
        if not cleaned or "?" in message:
            return None
        normalized = self._normalize_reply(cleaned)
        if normalized.startswith(
            ("do ", "can ", "what ", "where ", "who ", "when ", "why ", "how ", "save ")
        ):
            return None
        match = _NAME_REPLY_PATTERN.match(cleaned)
        if match is None:
            return None
        name = self._clean_fact(match.group("name"))
        if len(name) < 2 or name.lower() in _BLOCKED_NAME_TOKENS:
            return None
        if not re.fullmatch(r"[A-Za-z][\w'-]{1,40}", name):
            return None
        return name

    def _normalize_relationship_name(self, value: str) -> str:
        return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
