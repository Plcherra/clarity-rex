"""Normalize assistant text before TTS so voices do not read markup aloud."""

from __future__ import annotations

import re

# Broad emoji / pictograph ranges plus variation selectors and ZWJ sequences.
_EMOJI_RE = re.compile(
    "["
    "\U0001F1E0-\U0001F1FF"  # flags
    "\U0001F300-\U0001F5FF"  # symbols & pictographs
    "\U0001F600-\U0001F64F"  # emoticons
    "\U0001F680-\U0001F6FF"  # transport
    "\U0001F700-\U0001F77F"
    "\U0001F780-\U0001F7FF"
    "\U0001F800-\U0001F8FF"
    "\U0001F900-\U0001F9FF"
    "\U0001FA00-\U0001FAFF"
    "\U00002600-\U000026FF"  # misc symbols
    "\U00002700-\U000027BF"  # dingbats
    "\U0000FE0E-\U0000FE0F"  # variation selectors
    "\U0000200D"  # zero-width joiner
    "\U000020E3"  # combining enclosing keycap
    "]+",
    flags=re.UNICODE,
)
_MULTI_SPACE_RE = re.compile(r"[ \t]{2,}")


def prepare_spoken_text(text: str) -> str:
    """Strip emojis and tidy whitespace for natural speech playback."""
    cleaned = _EMOJI_RE.sub(" ", str(text or ""))
    cleaned = _MULTI_SPACE_RE.sub(" ", cleaned)
    return cleaned.strip()
