import re
from dataclasses import dataclass
from typing import Optional

from app.services.chat_search_text_normalization import ChatSearchTextNormalizer
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
    "i",
    "info",
    "information",
    "kind",
    "know",
    "knows",
    "look",
    "looking",
    "me",
    "memories",
    "memory",
    "mention",
    "mentioned",
    "my",
    "old",
    "of",
    "our",
    "past",
    "phrase",
    "previous",
    "pull",
    "remember",
    "rex",
    "said",
    "saved",
    "say",
    "search",
    "tell",
    "told",
    "there",
    "up",
    "us",
    "was",
    "were",
}
CHAT_SEARCH_CONCEPT_GROUPS = (
    ("mom", "mother", "mum", "mama"),
    ("dad", "father", "papa"),
    ("money", "cash", "gift", "amount"),
    ("send", "sent", "sending", "transfer", "transferring", "transferred"),
    ("pc", "computer", "desktop", "model"),
    ("game", "games", "gaming", "gog", "steam"),
    ("buy", "bought", "purchase", "purchased", "grab", "grabbed", "picked"),
)
CHAT_SEARCH_CONCEPT_ALIASES = {
    term: group
    for group in CHAT_SEARCH_CONCEPT_GROUPS
    for term in group
}


@dataclass(frozen=True)
class ChatSearchQuery:
    query: str
    mode: str


class ChatSearchTermBuilder:
    def __init__(
        self, *, normalizer: Optional[ChatSearchTextNormalizer] = None
    ) -> None:
        self.normalizer = normalizer or ChatSearchTextNormalizer()

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
        search_terms = self.search_terms(normalized, max_terms=max_terms)
        expanded_query = " ".join(search_terms)
        if expanded_query:
            queries.append(ChatSearchQuery(expanded_query, "expanded_keywords"))
        subject_query = self.subject_only_query(normalized)
        if subject_query and " " in subject_query:
            queries.append(ChatSearchQuery(subject_query, "subject"))
        for keyword_query in search_terms[:max_terms]:
            queries.append(ChatSearchQuery(keyword_query, "keyword"))
        if subject_query and " " not in subject_query:
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
        return self.search_terms(normalized, max_terms=max_queries)

    def assistant_topic_query(self, query: str, *, max_terms: int = 6) -> str:
        """Convert natural recall language into the query a user would type."""

        normalized = self.normalize_text(query)
        subject = self.subject_only_query(normalized)
        if subject:
            return subject
        terms = list(self.content_terms(normalized))[:max_terms]
        return " ".join(terms)

    def search_terms(self, query: str, *, max_terms: int = 10) -> list[str]:
        normalized = self.normalize_text(query)
        subject = self.subject_only_query(normalized)
        probes: list[str] = []
        if subject:
            probes.extend(self.expand_terms(subject, max_terms=max_terms))
        probes.extend(self.expand_terms(normalized, max_terms=max_terms * 2))
        probes.extend(self.content_terms(subject or normalized))
        return self.unique_terms(
            [
                term
                for term in probes
                if term not in CHAT_SEARCH_STOP_WORDS
                and self.is_searchable_short_term(term)
            ]
        )[:max_terms]

    def expand_terms(self, query: str, *, max_terms: int = 10) -> list[str]:
        raw_terms = [self.normalize_term(term) for term in self.raw_terms(query)]
        expanded_terms: list[str] = []
        for term in raw_terms:
            if term in CHAT_SEARCH_STOP_WORDS:
                continue
            if not self.is_searchable_short_term(term):
                continue
            expanded_terms.extend(self.simple_term_variants(term))
            expanded_terms.extend(self.concept_variants(term))

        unique_terms: list[str] = []
        for term in expanded_terms:
            if term and term not in unique_terms:
                unique_terms.append(term)
        return unique_terms[:max_terms]

    def concept_variants(self, term: str) -> tuple[str, ...]:
        normalized = self.normalize_term(term)
        if not normalized:
            return ()
        return tuple(CHAT_SEARCH_CONCEPT_ALIASES.get(normalized, ()))

    def unique_terms(self, terms: list[str]) -> list[str]:
        return self.normalizer.unique_terms(terms)

    def subject_only_query(self, normalized_query: str) -> str:
        match = re.search(
            r"\b(?:about|for|of|on|regarding|with|mention(?:ed)?(?:\s+of)?|"
            r"search(?:\s+for)?)\s+"
            r"(?:my\s+)?(?P<subject>[a-z0-9'\s]{2,80})",
            normalized_query,
        )
        if match is None:
            return ""
        subject = re.sub(
            r"\b(?:about|for|in|my|old|on|our|past|previous|the|your|chat|"
            r"chats|conversation|conversations|anything|information|details|"
            r"exact|memory|memories|phrase|saved|know|remember|words)\b",
            " ",
            match.group("subject"),
        )
        subject = re.sub(r"[^a-z0-9'\s]+", " ", subject)
        subject = re.sub(r"\s+", " ", subject).strip()
        return subject if len(subject) >= 3 else ""

    def content_terms(self, query: str) -> tuple[str, ...]:
        terms = []
        for term in (self.normalize_term(term) for term in self.raw_terms(query)):
            if term and term not in CHAT_SEARCH_STOP_WORDS and term not in terms:
                terms.append(term)
        return tuple(terms)

    def __getattr__(self, name: str):
        return getattr(self.normalizer, name)
