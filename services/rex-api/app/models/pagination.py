"""Offset-based opaque cursor pagination helpers."""

from __future__ import annotations

import base64
import binascii
import json
from typing import Generic, Optional, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class PagedResponse(BaseModel, Generic[T]):
    items: list[T] = Field(default_factory=list)
    next_cursor: Optional[str] = None
    has_more: bool = False


def decode_offset_cursor(cursor: Optional[str]) -> int:
    if not cursor:
        return 0
    try:
        padding = "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(cursor + padding).decode())
        offset = payload.get("offset", 0)
        return max(int(offset), 0)
    except (ValueError, TypeError, json.JSONDecodeError, binascii.Error):
        return 0


def encode_offset_cursor(offset: int) -> str:
    token = base64.urlsafe_b64encode(
        json.dumps({"offset": max(offset, 0)}, separators=(",", ":")).encode(),
    ).decode()
    return token.rstrip("=")


def paginate_rows(rows: list[dict], *, limit: int, offset: int) -> tuple[list[dict], Optional[str], bool]:
    page_rows = rows[:limit]
    has_more = len(rows) > limit
    next_cursor = encode_offset_cursor(offset + limit) if has_more else None
    return page_rows, next_cursor, has_more
