"""Shared text normalization for memory correction and delete parsing."""

from __future__ import annotations

import re


def clean_text(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def trim_text(value: str) -> str:
    value = clean_text(value)
    value = re.sub(r"[.!?]+$", "", value).strip()
    return value.strip("\"'")


def trim_removal_target(value: str) -> str:
    value = trim_text(value)
    value = re.sub(
        r"^(?:please\s+)?(?:about\s+)?(?:that|this|the)\s+",
        "",
        value,
        flags=re.IGNORECASE,
    )
    value = re.sub(
        (
            r"^(?:saved\s+)?"
            r"(?:mention|mentions|memory|memories|record|records)\s*"
            r"(?:of|about|for)?\s+"
        ),
        "",
        value,
        flags=re.IGNORECASE,
    )
    return value.strip()
