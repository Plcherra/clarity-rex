"""Safe chat request validation helpers."""

from __future__ import annotations

from typing import Any, Optional

from pydantic import ValidationError

from app.models.chat import ChatRequest


def serializable_validation_errors(error: ValidationError) -> list[dict[str, Any]]:
    """Return Pydantic errors without non-JSON values (e.g. ValueError in ctx)."""
    details: list[dict[str, Any]] = []
    for item in error.errors():
        details.append(
            {
                "type": item.get("type"),
                "loc": list(item.get("loc") or ()),
                "msg": item.get("msg"),
            }
        )
    return details


def is_only_financial_context_size_error(error: ValidationError) -> bool:
    errors = error.errors()
    if len(errors) != 1:
        return False
    item = errors[0]
    loc = tuple(item.get("loc") or ())
    msg = str(item.get("msg") or "")
    return loc == ("financial_context",) and "exceeds maximum size" in msg


def chat_request_dropping_oversized_financial_context(
    payload: dict[str, Any],
    error: ValidationError,
) -> Optional[ChatRequest]:
    """Optional finance pack must not kill the turn when it alone is oversized."""
    if not is_only_financial_context_size_error(error):
        return None
    if "financial_context" not in payload:
        return None
    recovered = dict(payload)
    recovered["financial_context"] = None
    return ChatRequest(**recovered)
