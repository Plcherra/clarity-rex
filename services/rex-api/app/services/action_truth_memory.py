"""Truth guard for false Knows/memory success claims without a write."""

from __future__ import annotations

import re

from app.services.action_truth_policy import (
    CHAT_SEARCH_CAPABILITY_FALLBACK,
    DEGRADED_RECALL_FALLBACK,
    EMPTY_RECALL_FALLBACK,
    FILTERED_RECALL_FALLBACK,
    PARTIAL_RECALL_FALLBACK,
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

# Signals that *might* be a write claim — not enough alone (see framing below).
_WRITE_SIGNAL_TERMS = tuple(
    "saved|saving|i'll save|i will save|"
    "i'll update|i will update|i'll change|i will change|"
    "updated|updating|fixed|fixing|changed|changing|deleted|deleting|"
    "created|creating|added|adding|moved|moving|"
    "noted|noting|remembered|remembering|"
    "guardé|guarde|guardado|actualicé|actualice|actualizado|"
    "sauvegardé|enregistré|souviens|"
    "gespeichert|aktualisiert".split("|")
)
_CONFIRMATION_TERMS = tuple(
    "confirm|approve|should i|want me to|before i|pending|proposal|"
    "would you like me to".split("|")
)
# Surfaces / phrases that mark a durable Knows (or person-card) write claim.
_DURABLE_SURFACE_TERMS = (
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
    "memoria guardada",
    "lo guardé",
    "lo he guardado",
    "actualicé",
    "he actualizado",
    "j'ai sauvegardé",
    "j'ai enregistré",
    "ich habe gespeichert",
    "ich habe aktualisiert",
)
_FIRST_PERSON_WRITE_TERMS = (
    "i've saved",
    "i have saved",
    "i saved",
    "i've updated",
    "i have updated",
    "i updated",
)

_DURABLE_OBJECT_WRITE_RE = re.compile(
    r"\b(?:saved|updated|created|added|saving|updating|creating|adding)\s+"
    r"(?:your|the|that|this|a|an)\b.{0,40}\b"
    r"(?:memory|knows|fact|preference|friend|goal|plan)\b",
    re.I,
)
_SAVED_AS_OR_IN_KNOWS_RE = re.compile(
    r"\b(?:saved|saving|updated|updating)\b.{0,40}\b"
    r"(?:as\s+(?:a\s+)?(?:goal|plan|preference|friend|fact)|"
    r"in\s+knows|to\s+knows)\b",
    re.I,
)
_REMEMBERED_DURABLE_RE = re.compile(
    r"\b(?:i(?:'|’)?ve|i have|i)\s+remembered\b.{0,60}\b"
    r"(?:in\s+knows|saved memory|as\s+(?:a\s+)?(?:fact|preference|friend))\b",
    re.I,
)
_PROGRESSIVE_WRITE_RE = re.compile(
    r"\b(?:saving|updating|creating|adding)\s+(?:your|the|that|this|it)\b",
    re.I,
)
_PROMISE_WRITE_RE = re.compile(
    r"\bi(?:'|’| a)?ll\s+(?:save|update|remember|add)\b|"
    r"\bi(?:'|’)?m saving\b|\bi am saving\b",
    re.I,
)
_PAST_TENSE_WRITE_RE = re.compile(
    r"\b(?:i(?:'|’)?ve|i have|i)\s+(?:saved|updated)\b|"
    r"\b(?:saved|updated)\s+(?:your|the|that|it|this)\b|"
    r"\b(?:yes[, ]+)?saved\s*:|"
    r"\b(?:lo guardé|lo he guardado|j'ai (?:sauvegardé|enregistré)|"
    r"ich habe (?:gespeichert|aktualisiert))\b",
    re.I,
)


def _normalized(response: str) -> str:
    return f" {response.lower()} "


def _contains_any(text: str, terms: tuple[str, ...]) -> bool:
    return any(term in text for term in terms)


def _looks_like_saved_memory_claim(text: str) -> bool:
    """Durable Knows/goal write framing — not conversational 'remembered' / 'updated thinking'."""
    if not _contains_any(text, _WRITE_SIGNAL_TERMS):
        return False
    if _contains_any(text, _DURABLE_SURFACE_TERMS):
        return True
    if _contains_any(text, _FIRST_PERSON_WRITE_TERMS):
        return True
    if re.search(r"\b(?:yes[, ]+)?saved\s*:", text):
        return True
    if re.search(r"\bi(?:'| a)?ll save\b.+\bas\b", text):
        return True
    if _DURABLE_OBJECT_WRITE_RE.search(text):
        return True
    if _SAVED_AS_OR_IN_KNOWS_RE.search(text):
        return True
    if _REMEMBERED_DURABLE_RE.search(text):
        return True
    return False


def _has_past_tense_memory_success(text: str) -> bool:
    """Completed durable write claim — scrub even with soft confirm language."""
    if _PAST_TENSE_WRITE_RE.search(text):
        return True
    return bool(_REMEMBERED_DURABLE_RE.search(text))


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


def response_claims_memory_write_in_progress(response: str) -> bool:
    """True when the reply claims a durable save/update is happening now."""
    cleaned = response.strip()
    if not cleaned or cleaned in _CANONICAL_TRUTH_FALLBACKS:
        return False
    text = _normalized(cleaned)
    if _contains_any(text, _CONFIRMATION_TERMS):
        return False
    return bool(_PROGRESSIVE_WRITE_RE.search(text) or _PROMISE_WRITE_RE.search(text))


def safe_unexecuted_memory_response(response: str) -> str:
    cleaned = response.strip()
    if not (
        response_claims_saved_memory_success(cleaned)
        or response_claims_memory_write_in_progress(cleaned)
    ):
        return cleaned
    return UNEXECUTED_MEMORY_FALLBACK


def safe_unexecuted_saved_memory_claim_response(response: str) -> str:
    """Language-agnostic guard: block Knows/memory success claims without a write."""
    cleaned = response.strip()
    if not (
        response_claims_saved_memory_success(cleaned)
        or response_claims_memory_write_in_progress(cleaned)
    ):
        return cleaned
    return UNEXECUTED_MEMORY_FALLBACK
