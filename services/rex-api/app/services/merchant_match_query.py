"""Match a merchant the user named against raw bank descriptions.

What a person calls a shop is not what the bank writes down. "sultanas" has to
reach `CHECKCARD 0718 El Valle De La Sultana Somerville MA XXXXX3861...`, and a
single substring never gets there: the card prefix, the store's full legal name,
the city, and the user's own plural all sit between the two strings.

So each meaningful word is matched on its own, and all of them must appear.
Requiring all of them is deliberate — a category move touches rows the user did
not read out, so a term too many finds nothing and says so, while a term too few
would quietly move somebody else's groceries.
"""

from __future__ import annotations

import re
from typing import Any, Optional

MATCHED_COLUMNS = ("description", "merchant")

# A spoken name is short. More terms than this means Grok echoed a whole
# statement line, and every extra word there is one more row that cannot match.
MAX_MATCH_TERMS = 4

_MIN_TERM_LENGTH = 3
_WORD_PATTERN = re.compile(r"[a-z0-9]+")

# Printed on the receipt, skipped when spoken. Shorter articles (el, la, de,
# du, il) fall out on length alone.
_GRAMMAR_WORDS = frozenset(
    {"and", "der", "die", "for", "the", "uma", "una", "uno", "und", "with"}
)

# What the card network wraps around the name; never the merchant itself.
_STATEMENT_NOISE = frozenset(
    {
        "ach",
        "atm",
        "card",
        "cardmember",
        "checkcard",
        "credit",
        "dda",
        "debit",
        "eft",
        "ind",
        "indn",
        "memo",
        "mobile",
        "online",
        "payment",
        "ppd",
        "purchase",
        "recurring",
        "ref",
        "sale",
        "transaction",
        "visa",
        "web",
        "withdrawal",
        "xxxx",
    }
)


def merchant_match_terms(merchant: Any) -> list[str]:
    """The words a description must contain, singularised.

    Matching on the singular stem works in both directions — `%sultana%` finds
    "Sultana" and "Sultanas" alike — so it does not matter whether the user or
    the bank reached for the plural.
    """
    words = _WORD_PATTERN.findall(str(merchant or "").lower())
    terms: list[str] = []
    for word in words:
        term = _singular(word)
        if not _is_meaningful(term) or term in terms:
            continue
        terms.append(term)
        if len(terms) == MAX_MATCH_TERMS:
            break
    if terms:
        return terms
    # A name made only of short or noise-like words is still what the user
    # said, so match it whole rather than refusing to match at all.
    whole = "".join(words)
    return [whole] if whole else []


def merchant_match_query(merchant: Any) -> Optional[dict[str, str]]:
    """A PostgREST filter for rows whose text carries every term."""
    terms = merchant_match_terms(merchant)
    if not terms:
        return None
    if len(terms) == 1:
        return {"or": f"({_column_filters(terms[0])})"}
    groups = ",".join(f"or({_column_filters(term)})" for term in terms)
    return {"and": f"({groups})"}


def _column_filters(term: str) -> str:
    return ",".join(f'{column}.ilike."*{term}*"' for column in MATCHED_COLUMNS)


def _is_meaningful(term: str) -> bool:
    if len(term) < _MIN_TERM_LENGTH or term.isdigit():
        return False
    return term not in _GRAMMAR_WORDS and term not in _STATEMENT_NOISE


def _singular(word: str) -> str:
    """Drop an English or Iberian plural ending, keeping the word recognisable."""
    if len(word) > 4 and word.endswith(("ches", "shes", "ses", "xes", "zes")):
        return word[:-2]
    if len(word) > 3 and word.endswith("s") and not word.endswith("ss"):
        return word[:-1]
    return word
