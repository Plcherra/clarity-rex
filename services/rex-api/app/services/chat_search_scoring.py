import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

from app.services.chat_search_terms import ChatSearchTermBuilder


SEARCH_QUESTION_MARKERS = (
    "do i have",
    "did i have",
    "do you have",
    "do you have information about",
    "do you know",
    "do you remember",
    "have any information",
    "any information about",
    "can you search",
    "can you check",
    "can you look",
    "look into old chat",
    "look into the old chat",
    "look into old chats",
    "look into the old chats",
    "tell me about",
    "what about",
    "what did i say",
    "what kind",
    "what type",
    "search old",
    "search the old",
    "check old",
    "check the old",
)
NO_RESULT_MARKERS = (
    "do not have anything saved",
    "don't have anything saved",
    "do not have any info",
    "don't have any info",
    "nothing about",
    "nothing came up",
    "nothing showed up",
    "found nothing",
    "could not find",
    "couldn't find",
    "did not find",
    "didn't find",
    "no mentions",
    "no mention",
)
FACTUAL_STATEMENT_PATTERNS = (
    r"\bi\s+(?:own|have|bought|want|wanted|prefer|like|live|work|plan|planned|need|intend)\b",
    r"\bmy\s+[a-z0-9'\s]{1,40}\s+(?:is|are|was|were)\b",
    r"\b(?:it|that|this|the\s+[a-z0-9'\s]{1,30})\s+(?:is|was|are|were)\b",
    r"\b(?:model|birthday|deadline|address|name|preference)\s+(?:is|was|are|were)\b",
    r"\b(?:my|her|his|their)\s+[a-z0-9'\s]{1,40}\s+birthday\b",
    r"\b(?:send|sending|sent|transfer|transferring|transferred)\b.{0,60}\b(?:money|cash|\$|\d+)\b",
    r"\b(?:money|cash|\$|\d+)\b.{0,60}\b(?:send|sending|sent|transfer|transferring|transferred)\b",
)
DETAIL_PATTERNS = (
    r"\$\s*\d+",
    r"\b\d+(?:\.\d{2})?\s*(?:bucks|dollars)\b",
    r"\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|"
    r"thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|"
    r"thirty|forty|fifty|hundred)\b.{0,30}\b(?:bucks|dollars|money|cash)\b",
    r"\b(?:january|february|march|april|may|june|july|august|september|october|"
    r"november|december)\s+\d{1,2}(?:st|nd|rd|th)?\b",
    r"\b(?:on|by|around)\s+(?:the\s+)?(?:\d{1,2}(?:st|nd|rd|th)?|"
    r"first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|"
    r"eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|seventeenth|"
    r"eighteenth|nineteenth|twentieth|twenty first|twenty second|twenty third)\b",
    r"\bbirthday\b",
    r"\bmodel\b|\b[a-z][a-z0-9 -]*\d{1,4}\s*[a-z]{0,3}\b",
    r"\bfor\s+(?:her|his|their|my|the)\b",
)


@dataclass(frozen=True)
class ChatSearchScore:
    score: float
    reason: str
    matched_terms: tuple[str, ...]


class ChatSearchScorer:
    def __init__(self, *, terms: Optional[ChatSearchTermBuilder] = None) -> None:
        self.terms = terms or ChatSearchTermBuilder()

    def score_text(
        self,
        query: str,
        text: str,
        *,
        role: Optional[str] = None,
        timestamp: Optional[str] = None,
        title_match: bool = False,
        repeated_mentions: int = 1,
    ) -> ChatSearchScore:
        normalized_query = self.normalize_text(query)
        normalized_text = self.normalize_text(text)
        if not normalized_query or not normalized_text:
            return ChatSearchScore(0.0, "No searchable text.", ())

        subject = self.subject_only_query(normalized_query)
        exact_terms = self.content_terms(subject or normalized_query)
        expanded_terms = self.expand_terms(subject or normalized_query, max_terms=16)
        matched_exact = tuple(
            term for term in exact_terms if self.term_in_text(term, normalized_text)
        )
        matched_expanded = tuple(
            term
            for term in expanded_terms
            if term not in matched_exact and self.term_in_text(term, normalized_text)
        )

        score = 0.0
        reasons = []
        if self.phrase_in_text(normalized_query, normalized_text):
            score += 5.0
            reasons.append("exact phrase")
        if subject and self.phrase_in_text(subject, normalized_text):
            score += 4.0
            reasons.append("subject phrase")
        if matched_exact:
            score += 2.0 * len(matched_exact)
            reasons.append("exact terms")
        if matched_expanded:
            score += 1.1 * len(matched_expanded)
            reasons.append("expanded terms")
        if role == "user":
            score += 1.5
            reasons.append("user-authored")
            if self.is_search_question_text(normalized_text):
                score -= 1.8
                reasons.append("search-question demotion")
            elif self.is_factual_statement_text(normalized_text):
                score += 2.0
                reasons.append("factual statement")
            detail_score = self.detail_density_score(normalized_text)
            if detail_score > 0:
                score += min(4.0, detail_score)
                reasons.append("detail-rich")
        elif role == "assistant":
            score += 0.4
            reasons.append("assistant-authored")
            if self.is_no_result_text(normalized_text):
                score -= 3.5
                reasons.append("no-result demotion")
        if title_match:
            score += 2.5
            reasons.append("conversation title")
        if repeated_mentions > 1:
            score += min(2.0, 0.35 * (repeated_mentions - 1))
            reasons.append("repeated mentions")
        score += self.recency_score(timestamp)

        matched = (*matched_exact, *matched_expanded)
        if not matched and not self.phrase_in_text(normalized_query, normalized_text):
            return ChatSearchScore(0.0, "No matching terms.", ())

        return ChatSearchScore(
            round(score, 4),
            ", ".join(reasons) if reasons else "keyword match",
            matched,
        )

    def is_no_result_text(self, text: str) -> bool:
        normalized = self.normalize_text(text)
        return any(marker in normalized for marker in NO_RESULT_MARKERS)

    def is_search_question_text(self, text: str) -> bool:
        normalized = self.normalize_text(text)
        if "?" in str(text or "") and any(
            normalized.startswith(prefix)
            for prefix in ("do i", "did i", "what", "can you", "do you")
        ):
            return True
        return any(marker in normalized for marker in SEARCH_QUESTION_MARKERS)

    def is_factual_statement_text(self, text: str) -> bool:
        normalized = self.normalize_text(text)
        if not normalized or self.is_search_question_text(normalized):
            return False
        return any(
            re.search(pattern, normalized)
            for pattern in FACTUAL_STATEMENT_PATTERNS
        )

    def detail_density_score(self, text: str) -> float:
        normalized = self.normalize_text(text)
        if not normalized or self.is_search_question_text(normalized):
            return 0.0
        matches = sum(1 for pattern in DETAIL_PATTERNS if re.search(pattern, normalized))
        return float(matches) * 1.5

    def recency_score(self, timestamp: Optional[str]) -> float:
        if not timestamp:
            return 0.0
        try:
            parsed = datetime.fromisoformat(str(timestamp).replace("Z", "+00:00"))
        except ValueError:
            return 0.0
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        age_days = max(0, (datetime.now(timezone.utc) - parsed).days)
        if age_days <= 1:
            return 0.25
        if age_days <= 7:
            return 0.2
        if age_days <= 30:
            return 0.1
        return 0.05

    def __getattr__(self, name: str):
        return getattr(self.terms, name)
