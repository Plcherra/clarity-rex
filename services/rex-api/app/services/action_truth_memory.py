"""Truth guard for false Knows/memory success claims without a write."""

from __future__ import annotations

import re

from app.services.action_truth_policy import (
    CHAT_SEARCH_CAPABILITY_FALLBACK,
    DEGRADED_RECALL_FALLBACK,
    EMPTY_RECALL_FALLBACK,
    FILTERED_RECALL_FALLBACK,
    PARTIAL_RECALL_FALLBACK,
    response_claims_unconfirmed_success,
)

UNEXECUTED_MEMORY_FALLBACK = (
    "I can help with that, but I don't have a confirmed saved change from this "
    "turn. Tell me the exact fact to save or try again."
)

_CANONICAL_TRUTH_FALLBACKS = frozenset(
    {
        DEGRADED_RECALL_FALLBACK,
        EMPTY_RECALL_FALLBACK,
        FILTERED_RECALL_FALLBACK,
        PARTIAL_RECALL_FALLBACK,
        CHAT_SEARCH_CAPABILITY_FALLBACK,
    }
)

_SUCCESS_TERMS = tuple(
    "saved|saving|i'll save|i will save|"
    "i'll update|i will update|i'll change|i will change|"
    "updated|updating|fixed|fixing|changed|changing|deleted|deleting|"
    "created|creating|moved|moving|sent|sending|categorized|categorizing|"
    "recategorized|recategorizing|noted|noting|remembered|remembering|"
    "completed|done|all set|"
    "guardé|guarde|guardado|actualicé|actualice|actualizado|"
    "sauvegardé|enregistré|souviens|"
    "gespeichert|aktualisiert".split("|")
)
_CONFIRMATION_TERMS = tuple(
    "confirm|approve|should i|want me to|before i|pending|proposal|"
    "would you like me to".split("|")
)
_SAVED_MEMORY_CLAIM_TERMS = (
    "saved memory",
    "clarity knows",
    "in knows",
    "to knows",
    "knows tab",
    "in your knows",
    "your mother's name",
    "your mom's name",
    "your mama's name",
    "updated your mother",
    "updated your mom",
    "updated your mama",
    "remembered that",
    "i remembered",
    "i've saved",
    "i have saved",
    "i've updated",
    "i have updated",
    "i updated",
    "i saved",
    "memoria guardada",
    "lo guardé",
    "lo he guardado",
    "actualicé",
    "he actualizado",
    "je me souviens",
    "j'ai sauvegardé",
    "j'ai enregistré",
    "ich habe gespeichert",
    "ich habe aktualisiert",
)


def _normalized(response: str) -> str:
    return f" {response.lower()} "


def _contains_any(text: str, terms: tuple[str, ...]) -> bool:
    return any(term in text for term in terms)


def _looks_like_saved_memory_claim(text: str) -> bool:
    """Knows/memory framing present (past or soft), ignoring confirm language."""
    if not _contains_any(text, _SUCCESS_TERMS):
        return False
    if _contains_any(text, _SAVED_MEMORY_CLAIM_TERMS):
        return True
    if re.search(r"\b(?:yes[, ]+)?saved\s*:", text):
        return True
    if re.search(r"\bi(?:'| a)?ll save\b.+\bas\b", text):
        return True
    if re.search(
        r"\b(?:saved|updated|remembered)\b.{0,80}\b(?:memory|knows|fact|preference|friend|goal)\b",
        text,
    ):
        return True
    return False


def _has_past_tense_memory_success(text: str) -> bool:
    """Completed Knows write claim — scrub even with soft confirm language."""
    return bool(
        re.search(
            r"\b(?:i(?:'|’)?ve|i have|i)\s+(?:saved|updated|remembered)\b|"
            r"\b(?:saved|updated|remembered)\s+"
            r"(?:your|the|that|it|this)\b|"
            r"\b(?:yes[, ]+)?saved\s*:|"
            r"\b(?:lo guardé|lo he guardado|j'ai (?:sauvegardé|enregistré)|"
            r"ich habe (?:gespeichert|aktualisiert))\b",
            text,
            re.I,
        )
    )


def response_claims_saved_memory_success(response: str) -> bool:
    """True when the reply claims a durable Knows/memory write succeeded."""
    cleaned = response.strip()
    if not cleaned or cleaned in _CANONICAL_TRUTH_FALLBACKS:
        return False
    text = _normalized(cleaned)
    if not _looks_like_saved_memory_claim(text):
        return False
    # Soft confirm-only asks stay allowed; past-tense Knows success does not.
    if _contains_any(text, _CONFIRMATION_TERMS) and not _has_past_tense_memory_success(
        text
    ):
        return False
    return True


def safe_unexecuted_memory_response(response: str) -> str:
    cleaned = response.strip()
    if not (
        response_claims_saved_memory_success(cleaned)
        or response_claims_unconfirmed_success(cleaned)
    ):
        return cleaned
    return UNEXECUTED_MEMORY_FALLBACK


def safe_unexecuted_saved_memory_claim_response(response: str) -> str:
    """Language-agnostic guard: block Knows/memory success claims without a write."""
    cleaned = response.strip()
    if not response_claims_saved_memory_success(cleaned):
        return cleaned
    return UNEXECUTED_MEMORY_FALLBACK
