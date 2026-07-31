"""Error type shared by Clarity control writes and the modules they delegate to."""

from __future__ import annotations


class ClarityControlServiceError(Exception):
    def __init__(self, detail: str, status_code: int = 400) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code
