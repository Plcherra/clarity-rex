"""Shared cleanup for chat and voice user text before Rex Brain processing."""

from __future__ import annotations

import re
from typing import Iterable


FIRST_PERSON_AI_VERBS = (
    "bought",
    "purchased",
    "got",
    "gotten",
    "said",
    "told",
    "mentioned",
    "wanted",
    "downloaded",
    "installed",
    "ordered",
    "grabbed",
    "picked",
    "played",
    "play",
    "get",
    "need",
    "needed",
    "have",
    "had",
)

PRODUCT_TERM_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    (r"\bgog\b", "GOG"),
    (r"\b8bitdo\b", "8BitDo"),
    (r"\b8 bitdo\b", "8BitDo"),
    (r"\bsteam\b", "Steam"),
    (r"\bepic games\b", "Epic Games"),
    (r"\bxbox\b", "Xbox"),
    (r"\bplaystation\b", "PlayStation"),
    (r"\bnintendo\b", "Nintendo"),
)

RECALL_PHRASE_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    (r"\bdon't you know\b|\bdont you know\b", "do you know"),
    (r"\bdon't you remember\b|\bdont you remember\b", "do you remember"),
    (r"\bdidn't you\b|\bdidnt you\b", "did you"),
    (r"\bcan't you\b|\bcant you\b", "can you"),
    (r"\bwon't you\b|\bwont you\b", "will you"),
)

CONTRACTION_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    (r"\bdont\b", "don't"),
    (r"\bcant\b", "can't"),
    (r"\bwont\b", "won't"),
    (r"\bisnt\b", "isn't"),
    (r"\barent\b", "aren't"),
    (r"\bwasnt\b", "wasn't"),
    (r"\bwerent\b", "weren't"),
    (r"\bcouldnt\b", "couldn't"),
    (r"\bwouldnt\b", "wouldn't"),
    (r"\bshouldnt\b", "shouldn't"),
    (r"\bdidnt\b", "didn't"),
    (r"\bhasnt\b", "hasn't"),
    (r"\bhavent\b", "haven't"),
    (r"\bim\b", "I'm"),
    (r"\bive\b", "I've"),
    (r"\bid\b", "I'd"),
    (r"\bill\b", "I'll"),
    (r"\byoure\b", "you're"),
    (r"\byouve\b", "you've"),
    (r"\byoud\b", "you'd"),
    (r"\btheyre\b", "they're"),
    (r"\bweve\b", "we've"),
)


class TranscriptNormalizer:
    """Deterministic ASR/chat cleanup used before intent, recall, and Grok."""

    def __init__(
        self,
        *,
        recall_phrases: Iterable[tuple[str, str]] = RECALL_PHRASE_REPLACEMENTS,
        contractions: Iterable[tuple[str, str]] = CONTRACTION_REPLACEMENTS,
        product_terms: Iterable[tuple[str, str]] = PRODUCT_TERM_REPLACEMENTS,
    ) -> None:
        self.recall_phrases = tuple(recall_phrases)
        self.contractions = tuple(contractions)
        self.product_terms = tuple(product_terms)
        verb_pattern = "|".join(FIRST_PERSON_AI_VERBS)
        self.first_person_ai_pattern = re.compile(
            rf"\b(\w+(?:\s+\w+)?)\s+ai\s+({verb_pattern})\b",
            flags=re.IGNORECASE,
        )

    def normalize(self, message: str) -> str:
        """Return cleaned text for Rex Brain processing, preserving user casing."""
        text = " ".join(str(message or "").strip().split())
        if not text:
            return ""

        text = re.sub(r"\bchet\b", "chat", text, flags=re.IGNORECASE)
        text = self._apply_rules(text, self.contractions)
        text = self._apply_rules(text, self.recall_phrases)
        text = self.first_person_ai_pattern.sub(self._replace_first_person_ai, text)
        text = self._apply_product_terms(text)
        return text

    def normalize_for_matching(self, message: str) -> str:
        """Lowercase normalized text for intent and recall matching."""
        return self.normalize(message).lower()

    def _replace_first_person_ai(self, match: re.Match[str]) -> str:
        subject = match.group(1)
        verb = match.group(2)
        return f"{subject} I {verb}"

    def _apply_rules(
        self,
        text: str,
        rules: Iterable[tuple[str, str]],
    ) -> str:
        updated = text
        for pattern, replacement in rules:
            updated = re.sub(pattern, replacement, updated, flags=re.IGNORECASE)
        return updated

    def _apply_product_terms(self, text: str) -> str:
        updated = text
        for pattern, canonical in self.product_terms:
            updated = re.sub(pattern, canonical, updated, flags=re.IGNORECASE)
        return updated


DEFAULT_TRANSCRIPT_NORMALIZER = TranscriptNormalizer()
