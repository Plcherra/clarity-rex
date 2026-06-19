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
        """Small recall probes beat one broad query for old-chat search."""

        normalized = self.normalize_text(query)
        terms = self.expand_terms(normalized, max_terms=max_queries * 2)
        content_terms = list(self.content_terms(normalized))
        subject = self.subject_only_query(normalized)
        if subject:
            terms = [*self.expand_terms(subject, max_terms=max_queries), *terms]
            content_terms = [*self.content_terms(subject), *content_terms]

        probes: list[str] = []
        if "pc" in terms and "game" in terms:
            probes.append("pc game")
        if "send" in terms and "money" in terms:
            probes.append("send money")

        for term in [*content_terms, *terms]:
            if term in CHAT_SEARCH_STOP_WORDS:
                continue
            if len(term) < 3 and term not in {"pc"}:
                continue
            probes.append(term)

        return self.unique_terms(probes)[:max_queries]

    def expand_terms(self, query: str, *, max_terms: int = 10) -> list[str]:
        raw_terms = [self.normalize_term(term) for term in self.raw_terms(query)]
        expanded_terms: list[str] = []
        for term in raw_terms:
            if term in CHAT_SEARCH_STOP_WORDS:
                continue
            if len(term) < 3 and term not in CHAT_SEARCH_TERM_ALIASES:
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
        if normalized_query in normalized_text:
            score += 5.0
            reasons.append("exact phrase")
        if subject and subject in normalized_text:
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
        if not matched and normalized_query not in normalized_text:
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
        if term.endswith("ies") and len(term) > 4:
            variants.add(f"{term[:-3]}y")
        elif term.endswith("s") and len(term) > 3:
            variants.add(term[:-1])
        elif len(term) > 3:
            variants.add(f"{term}s")
        return tuple(variants)

    def normalize_text(self, text: str) -> str:
        return " ".join(str(text or "").lower().split())

    def term_in_text(self, term: str, text: str) -> bool:
        return bool(re.search(rf"\b{re.escape(term)}\b", text))

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
