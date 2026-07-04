"""Shared text normalization helpers for the production assistant pipeline."""

from __future__ import annotations

import re

PROACTIVE_MONITORING_TERMS = (
    "monitor",
    "keep an eye",
    "alert me",
    "notify me",
    "warn me",
    "proactive",
    "automatically",
    "background",
    "every day",
    "daily",
    "weekly",
)


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def contains_any(normalized: str, terms: tuple[str, ...]) -> bool:
    for term in terms:
        if " " in term or "-" in term:
            if term in normalized:
                return True
            continue
        if re.search(rf"\b{re.escape(term)}\b", normalized):
            return True
    return False
