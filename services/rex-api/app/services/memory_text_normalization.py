import re
from typing import Any, Optional


def clean_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    cleaned = " ".join(str(value).split())
    return cleaned or None


def normalized_text(text: Any) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", str(text).lower()))
