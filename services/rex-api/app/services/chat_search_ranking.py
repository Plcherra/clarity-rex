import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

from app.services.memory_retrieval_terms import STOP_WORDS


CHAT_SEARCH_STOP_WORDS = STOP_WORDS | {
    "all",
    "anything",
    "chat",
    "chats",
    "check",
    "checked",
    "conversation",
    "conversations",
    "did",
    "do",
    "does",
    "else",
    "find",
    "know",
    "knows",
    "me",
    "memories",
    "memory",
    "mention",
    "mentioned",
    "old",
    "our",
    "past",
    "previous",
    "remember",
    "rex",
    "said",
    "saved",
    "say",
    "search",
    "tell",
    "told",
    "there",
    "us",
    "was",
    "were",
}

CHAT_SEARCH_TERM_ALIASES = {
    "mom": ("mom", "mother", "mum", "mama"),
    "mother": ("mom", "mother", "mum", "mama"),
    "mum": ("mom", "mother", "mum", "mama"),
    "mama": ("mom", "mother", "mum", "mama"),
    "dad": ("dad", "father", "papa"),
    "father": ("dad", "father", "papa"),
    "papa": ("dad", "father", "papa"),
    "parent": ("parent", "parents", "mom", "mother", "dad", "father"),
    "parents": ("parent", "parents", "mom", "mother", "dad", "father"),
    "family": ("family", "mom", "mother", "dad", "father", "parent"),
    "birthday": ("birthday", "birthdays", "birthdate", "date", "event"),
    "game": ("game", "games", "gaming", "play", "played"),
    "games": ("game", "games", "gaming", "play", "played"),
    "gaming": ("game", "games", "gaming", "play", "played"),
    "pc": ("pc", "computer", "game", "games"),
    "gift": ("gift", "gifts", "present", "send", "sent"),
    "gifts": ("gift", "gifts", "present", "send", "sent"),
    "give": ("give", "giving", "gift", "gifts", "present", "send", "sent"),
    "giving": ("give", "giving", "gift", "gifts", "present", "send", "sent"),
    "money": ("money", "send", "sent", "cash", "gift"),
    "send": ("send", "sending", "sent"),
    "sending": ("send", "sending", "sent"),
    "sent": ("send", "sending", "sent"),
    "purchase": ("purchase", "purchases", "buy", "buying", "bought"),
    "purchases": ("purchase", "purchases", "buy", "buying", "bought"),
    "buy": ("purchase", "purchases", "buy", "buying", "bought"),
    "buying": ("purchase", "purchases", "buy", "buying", "bought"),
    "bought": ("purchase", "purchases", "buy", "buying", "bought"),
    "wanted": ("want", "wanted", "buy", "buying", "purchase"),
    "payroll": ("payroll", "paycheck", "income", "work"),
    "job": ("job", "work", "company"),
    "work": ("work", "job", "company", "payroll"),
    "place": ("place", "places", "city", "home", "live", "lived"),
    "places": ("place", "places", "city", "home", "live", "lived"),
    "preference": ("preference", "preferences", "prefer", "like", "likes"),
    "preferences": ("preference", "preferences", "prefer", "like", "likes"),
    "goal": ("goal", "goals", "plan", "plans"),
    "goals": ("goal", "goals", "plan", "plans"),
    "immigration": ("immigration", "ead", "uscis", "visa", "green"),
    "visa": ("visa", "immigration", "uscis"),
}


@dataclass(frozen=True)
class ChatSearchQuery:
    query: str
    mode: str


@dataclass(frozen=True)
class ChatSearchScore:
    score: float
    reason: str
    matched_terms: tuple[str, ...]


class ChatSearchRanking:
    def build_queries(
        self,
        query: str,
        *,
        inventory_query: Optional[str] = None,
        max_terms: int = 10,
    ) -> list[ChatSearchQuery]:
        cleaned_query = str(query or "").strip()
        normalized = " ".join(cleaned_query.lower().split())
        if inventory_query and cleaned_query == inventory_query:
            return [ChatSearchQuery(cleaned_query, "inventory")]

        queries = [ChatSearchQuery(cleaned_query, "exact")]
        subject_query = self.subject_only_query(normalized)
        expanded_terms = self.expand_terms(normalized, max_terms=max_terms)
        subject_terms = self.expand_terms(subject_query, max_terms=max_terms)
        if subject_terms:
            expanded_terms = [*subject_terms, *expanded_terms]
        expanded_query = " ".join(self.unique_terms(expanded_terms)[:max_terms])
        if expanded_query:
            queries.append(ChatSearchQuery(expanded_query, "expanded_keywords"))
        for keyword_query in self.atomic_keyword_queries(
            normalized,
            max_queries=max_terms,
        ):
            queries.append(ChatSearchQuery(keyword_query, "keyword"))
        if subject_query:
            queries.append(ChatSearchQuery(subject_query, "subject"))

        unique: list[ChatSearchQuery] = []
        seen: set[str] = set()
        for item in queries:
            if item.query and item.query not in seen:
                seen.add(item.query)
                unique.append(item)
        return unique

    def atomic_keyword_queries(
        self,
        query: str,
        *,
        max_queries: int = 10,
    ) -> list[str]:
        """Small generic recall probes beat one broad query for old-chat search."""

        normalized = self.normalize_text(query)
        terms = self.expand_terms(normalized, max_terms=max_queries * 2)
        content_terms = list(self.content_terms(normalized))
        subject = self.subject_only_query(normalized)
        if subject:
            terms = [*self.expand_terms(subject, max_terms=max_queries), *terms]
            content_terms = [*self.content_terms(subject), *content_terms]

        probes: list[str] = []
        for term in [*content_terms, *terms]:
            if term in CHAT_SEARCH_STOP_WORDS:
                continue
            if not self.is_searchable_short_term(term):
                continue
            probes.append(term)

        return self.unique_terms(probes)[:max_queries]

    def expand_terms(self, query: str, *, max_terms: int = 10) -> list[str]:
        raw_terms = [self.normalize_term(term) for term in self.raw_terms(query)]
        expanded_terms: list[str] = []
        for term in raw_terms:
            if term in CHAT_SEARCH_STOP_WORDS:
                continue
            if not self.is_searchable_short_term(term):
                continue
            expanded_terms.extend(CHAT_SEARCH_TERM_ALIASES.get(term, (term,)))
            expanded_terms.extend(self.simple_term_variants(term))

        unique_terms: list[str] = []
        for term in expanded_terms:
            if term and term not in unique_terms:
                unique_terms.append(term)
        return unique_terms[:max_terms]

    def unique_terms(self, terms: list[str]) -> list[str]:
        unique: list[str] = []
        for term in terms:
            if term and term not in unique:
                unique.append(term)
        return unique

    def subject_only_query(self, normalized_query: str) -> str:
        match = re.search(
            r"\b(?:about|for|with)\s+(?:my\s+)?(?P<subject>[a-z0-9'\s]{3,80})",
            normalized_query,
        )
        if match is None:
            return ""
        subject = re.sub(
            r"\b(?:old|past|previous|chat|chats|conversation|conversations|"
            r"anything|information|details|memory|memories|saved|know|remember)\b",
            " ",
            match.group("subject"),
        )
        subject = re.sub(r"[^a-z0-9'\s]+", " ", subject)
        subject = re.sub(r"\s+", " ", subject).strip()
        return subject if len(subject) >= 3 else ""

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
        matched_exact = tuple(term for term in exact_terms if self.term_in_text(term, normalized_text))
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
        elif role == "assistant":
            score += 0.4
            reasons.append("assistant-authored")
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

    def content_terms(self, query: str) -> tuple[str, ...]:
        terms = []
        for term in (self.normalize_term(term) for term in self.raw_terms(query)):
            if term and term not in CHAT_SEARCH_STOP_WORDS and term not in terms:
                terms.append(term)
        return tuple(terms)

    def raw_terms(self, query: str) -> list[str]:
        return re.findall(r"[a-z0-9']+", str(query or "").lower())

    def normalize_term(self, term: str) -> str:
        normalized = term.strip("'")
        if normalized.endswith("'s"):
            normalized = normalized[:-2]
        return normalized

    def simple_term_variants(self, term: str) -> tuple[str, ...]:
        variants = {term}
        ordinal_base = self.ordinal_base(term)
        if term.isdigit():
            variants.add(self.ordinal_variant(term))
        elif ordinal_base:
            variants.add(ordinal_base)
        elif term.endswith("ies") and len(term) > 4:
            variants.add(f"{term[:-3]}y")
        elif term.endswith("s") and len(term) > 3:
            variants.add(term[:-1])
        elif len(term) > 3:
            variants.add(f"{term}s")
        return tuple(variants)

    def normalize_text(self, text: str) -> str:
        return " ".join(str(text or "").lower().split())

    def term_in_text(self, term: str, text: str) -> bool:
        normalized_term = self.normalize_term(term)
        if self.numeric_or_ordinal(normalized_term):
            return any(
                self.terms_match(normalized_term, token)
                for token in self.normalized_tokens(text)
            )
        return bool(re.search(rf"\b{re.escape(term)}\b", text))

    def phrase_in_text(self, phrase: str, text: str) -> bool:
        phrase_terms = self.normalized_tokens(phrase)
        if not phrase_terms:
            return False
        text_terms = self.normalized_tokens(text)
        if len(phrase_terms) > len(text_terms):
            return False
        for start in range(0, len(text_terms) - len(phrase_terms) + 1):
            candidate = text_terms[start : start + len(phrase_terms)]
            if all(
                self.terms_match(expected, actual)
                for expected, actual in zip(phrase_terms, candidate)
            ):
                return True
        return False

    def normalized_tokens(self, text: str) -> list[str]:
        return [
            self.normalize_term(term)
            for term in self.raw_terms(text)
            if self.normalize_term(term)
        ]

    def is_searchable_short_term(self, term: str) -> bool:
        return (
            len(term) >= 3
            or term in CHAT_SEARCH_TERM_ALIASES
            or term == "pc"
            or term.isdigit()
            or self.ordinal_base(term) is not None
        )

    def numeric_or_ordinal(self, term: str) -> bool:
        return term.isdigit() or self.ordinal_base(term) is not None

    def terms_match(self, expected: str, actual: str) -> bool:
        if expected == actual:
            return True
        expected_base = self.ordinal_base(expected)
        actual_base = self.ordinal_base(actual)
        if expected.isdigit() and actual_base == expected:
            return True
        if expected_base is not None and actual == expected_base:
            return True
        if expected_base is not None and actual_base == expected_base:
            return True
        return False

    def ordinal_base(self, term: str) -> Optional[str]:
        match = re.fullmatch(r"(\d{1,2})(?:st|nd|rd|th)", term)
        return match.group(1) if match else None

    def ordinal_variant(self, term: str) -> str:
        try:
            number = int(term)
        except ValueError:
            return term
        if 10 <= number % 100 <= 20:
            suffix = "th"
        else:
            suffix = {1: "st", 2: "nd", 3: "rd"}.get(number % 10, "th")
        return f"{number}{suffix}"

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
            return 1.0
        if age_days <= 7:
            return 0.7
        if age_days <= 30:
            return 0.35
        return 0.1
