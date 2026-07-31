"""Category naming rules, mirroring the app's `category_normalization.dart`.

Categories created from the assistant must land in the same buckets the manual
UI would produce, otherwise "Fast Food" from chat and "fast food" from the
Categories screen become two rows the user has to merge by hand.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional

MAX_CATEGORY_NAME_LENGTH = 40
_MIN_MEANINGFUL_CHARACTERS = 3

_SEPARATOR_PATTERN = re.compile(r"""[\s\-_.,;:|!?'"()]+""")
_UNSAFE_PATTERN = re.compile(r"[<>{}\[\]\\`~^=]")
_ALPHANUMERIC_PATTERN = re.compile(r"[A-Za-z0-9]")
_KEY_SEPARATOR_PATTERN = re.compile(r"[^a-z0-9]+")


@dataclass(frozen=True)
class NormalizedCategoryName:
    display_name: str
    normalized_name: str


def normalize_category_name(raw: str) -> Optional[NormalizedCategoryName]:
    display_name = normalize_category_display_name(raw)
    if display_name is None:
        return None
    return NormalizedCategoryName(
        display_name=display_name,
        normalized_name=normalized_category_key(display_name),
    )


def normalize_category_display_name(raw: str) -> Optional[str]:
    name = str(raw or "").strip()
    if not name or len(name) > MAX_CATEGORY_NAME_LENGTH:
        return None
    lowered = name.lower()
    if lowered.startswith("http://") or lowered.startswith("https://"):
        return None
    if "@" in lowered:
        return None
    if _UNSAFE_PATTERN.search(name):
        return None
    if not _ALPHANUMERIC_PATTERN.search(name):
        return None

    name = name.replace("&", " and ")
    name = re.sub(r"\s*/\s*", " / ", name)
    name = _SEPARATOR_PATTERN.sub(" ", name)
    name = re.sub(r"\s+", " ", name).strip()
    if not name or len(name) > MAX_CATEGORY_NAME_LENGTH:
        return None
    if len(_ALPHANUMERIC_PATTERN.findall(name)) < _MIN_MEANINGFUL_CHARACTERS:
        return None
    return " ".join(_title_case_word(word) for word in name.split(" "))


def normalized_category_key(raw: str) -> str:
    key = str(raw or "").strip().lower().replace("&", " and ")
    key = _KEY_SEPARATOR_PATTERN.sub(" ", key)
    key = re.sub(r"\band\b", " ", key)
    return re.sub(r"\s+", " ", key).strip()


def _title_case_word(word: str) -> str:
    if not word or word == "/":
        return word
    lowered = word.lower()
    return lowered[0].upper() + lowered[1:]
