from dataclasses import dataclass
from typing import Any, Optional


@dataclass(frozen=True)
class KnowsReferenceMatch:
    table: str
    id: str
    title: str
    record: dict[str, Any]
    action: str = "would_archive"
    attribute_key: Optional[str] = None
    attribute_value: Optional[str] = None
    source_memory_ids: tuple[str, ...] = ()
