from typing import Optional

from app.services.chat_search_scoring import (
    FACTUAL_STATEMENT_PATTERNS,
    NO_RESULT_MARKERS,
    SEARCH_QUESTION_MARKERS,
    ChatSearchScore,
    ChatSearchScorer,
)
from app.services.chat_search_terms import (
    CHAT_SEARCH_STOP_WORDS,
    ChatSearchQuery,
    ChatSearchTermBuilder,
)
from app.services.chat_search_text_normalization import (
    CARDINAL_ONES,
    CARDINAL_TENS,
    MAX_SHORT_TOKEN_LENGTH,
    MIN_PARTIAL_TERM_LENGTH,
    ORDINAL_NUMBERS,
    ORDINAL_WORDS,
    ChatSearchTextNormalizer,
)


class ChatSearchRanking:
    def __init__(self) -> None:
        self.normalizer = ChatSearchTextNormalizer()
        self.terms = ChatSearchTermBuilder(normalizer=self.normalizer)
        self.scorer = ChatSearchScorer(terms=self.terms)

    def build_queries(
        self,
        query: str,
        *,
        inventory_query: Optional[str] = None,
        max_terms: int = 10,
    ) -> list[ChatSearchQuery]:
        return self.terms.build_queries(
            query,
            inventory_query=inventory_query,
            max_terms=max_terms,
        )

    def atomic_keyword_queries(
        self,
        query: str,
        *,
        max_queries: int = 10,
    ) -> list[str]:
        return self.terms.atomic_keyword_queries(query, max_queries=max_queries)

    def search_terms(self, query: str, *, max_terms: int = 10) -> list[str]:
        return self.terms.search_terms(query, max_terms=max_terms)

    def expand_terms(self, query: str, *, max_terms: int = 10) -> list[str]:
        return self.terms.expand_terms(query, max_terms=max_terms)

    def unique_terms(self, terms: list[str]) -> list[str]:
        return self.normalizer.unique_terms(terms)

    def subject_only_query(self, normalized_query: str) -> str:
        return self.terms.subject_only_query(normalized_query)

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
        return self.scorer.score_text(
            query,
            text,
            role=role,
            timestamp=timestamp,
            title_match=title_match,
            repeated_mentions=repeated_mentions,
        )

    def content_terms(self, query: str) -> tuple[str, ...]:
        return self.terms.content_terms(query)

    def is_no_result_text(self, text: str) -> bool:
        return self.scorer.is_no_result_text(text)

    def is_search_question_text(self, text: str) -> bool:
        return self.scorer.is_search_question_text(text)

    def is_factual_statement_text(self, text: str) -> bool:
        return self.scorer.is_factual_statement_text(text)

    def raw_terms(self, query: str) -> list[str]:
        return self.normalizer.raw_terms(query)

    def normalize_term(self, term: str) -> str:
        return self.normalizer.normalize_term(term)

    def simple_term_variants(self, term: str) -> tuple[str, ...]:
        return self.normalizer.simple_term_variants(term)

    def inflection_variants(self, term: str) -> set[str]:
        return self.normalizer.inflection_variants(term)

    def normalize_text(self, text: str) -> str:
        return self.normalizer.normalize_text(text)

    def term_in_text(self, term: str, text: str) -> bool:
        return self.normalizer.term_in_text(term, text)

    def phrase_in_text(self, phrase: str, text: str) -> bool:
        return self.normalizer.phrase_in_text(phrase, text)

    def normalized_tokens(self, text: str) -> list[str]:
        return self.normalizer.normalized_tokens(text)

    def is_searchable_short_term(self, term: str) -> bool:
        return self.normalizer.is_searchable_short_term(term)

    def is_searchable_variant(self, term: str) -> bool:
        return self.normalizer.is_searchable_variant(term)

    def is_acronym_like(self, term: str) -> bool:
        return self.normalizer.is_acronym_like(term)

    def numeric_or_ordinal(self, term: str) -> bool:
        return self.normalizer.numeric_or_ordinal(term)

    def terms_match(self, expected: str, actual: str) -> bool:
        return self.normalizer.terms_match(expected, actual)

    def normalize_cardinal_number_words(self, text: str) -> str:
        return self.normalizer.normalize_cardinal_number_words(text)

    def model_code_base(self, term: str):
        return self.normalizer.model_code_base(term)

    def model_code_variants(self, term: str) -> tuple[str, ...]:
        return self.normalizer.model_code_variants(term)

    def ordinal_base(self, term: str) -> Optional[str]:
        return self.normalizer.ordinal_base(term)

    def ordinal_variant(self, term: str) -> str:
        return self.normalizer.ordinal_variant(term)

    def recency_score(self, timestamp: Optional[str]) -> float:
        return self.scorer.recency_score(timestamp)
