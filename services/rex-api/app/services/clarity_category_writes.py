"""Category writes: reuse-or-create a category, then move transactions into it.

Recategorising by hand means creating a category and editing every transaction
one at a time. A single confirmed Clarity action does both here:

- the category is reused when the user already has one under the same
  normalized name, so the assistant never leaves duplicates behind;
- the move may target a merchant instead of ids, so rows the assistant never
  saw in its context pack are recategorised too (see `merchant_match_query`,
  which bridges what the user calls a shop and what the bank prints).

Nothing runs without confirmation — `ClarityControlService.execute` still gates
these actions.
"""

from __future__ import annotations

from typing import Any, Awaitable, Callable, Optional

from app.services.category_name_normalization import (
    NormalizedCategoryName,
    categories_match,
    category_lookup_keys,
    normalize_category_name,
)
from app.services.clarity_control_errors import ClarityControlServiceError
from app.services.merchant_match_query import merchant_match_query

RequestFn = Callable[..., Awaitable[list[dict[str, Any]]]]

DEFAULT_CATEGORY_TYPE = "expense"


async def resolve_or_create_category(
    request: RequestFn,
    payload: dict[str, Any],
) -> list[dict[str, Any]]:
    """The category under this name, creating it only when it does not exist."""
    normalized = normalize_category_name(payload.get("name") or "")
    if normalized is None:
        raise ClarityControlServiceError("Category name is invalid.", 400)
    existing = await _find_category(request, normalized)
    if existing is not None:
        return [existing]
    category_type = str(payload.get("type") or "").strip() or DEFAULT_CATEGORY_TYPE
    body: dict[str, Any] = {
        "name": normalized.display_name,
        "normalized_name": normalized.normalized_name,
        "type": category_type,
    }
    for key in ("color", "icon"):
        value = payload.get(key)
        if value is not None and str(value).strip():
            body[key] = value
    return await request(
        "POST",
        "categories",
        body=body,
        prefer="return=representation",
    )


def renamed_category_fields(name: Any) -> dict[str, str]:
    """Display name plus the key the app dedupes on, so renames stay matchable."""
    normalized = normalize_category_name(name or "")
    if normalized is None:
        raise ClarityControlServiceError("Category name is invalid.", 400)
    return {
        "name": normalized.display_name,
        "normalized_name": normalized.normalized_name,
    }


async def move_transactions_to_category(
    request: RequestFn,
    payload: dict[str, Any],
) -> list[dict[str, Any]]:
    """Move the named ids — or every row matching a merchant — into a category."""
    category_id = await _target_category_id(request, payload)
    query = _match_query(payload)
    return await request(
        "PATCH",
        "transactions",
        body={"category_id": category_id},
        query={**query, "select": "*"},
        prefer="return=representation",
    )


async def _target_category_id(request: RequestFn, payload: dict[str, Any]) -> str:
    category_id = str(payload.get("category_id") or "").strip()
    if category_id:
        return category_id
    new_category = payload.get("new_category")
    if not isinstance(new_category, dict):
        raise ClarityControlServiceError(
            "category_id or new_category is required for category moves.",
            400,
        )
    rows = await resolve_or_create_category(request, new_category)
    resolved = str((rows[0] if rows else {}).get("id") or "").strip()
    if not resolved:
        raise ClarityControlServiceError(
            "The category could not be created, so nothing was moved.",
            502,
        )
    return resolved


def _match_query(payload: dict[str, Any]) -> dict[str, str]:
    ids = payload.get("ids")
    cleaned_ids = (
        [str(value).strip() for value in ids if str(value).strip()]
        if isinstance(ids, list)
        else []
    )
    if cleaned_ids:
        return {"id": f"in.({','.join(cleaned_ids)})"}
    query = merchant_match_query(payload.get("merchant"))
    if query is not None:
        return query
    raise ClarityControlServiceError(
        "ids or merchant is required for bulk category updates.",
        400,
    )


async def _find_category(
    request: RequestFn,
    normalized: NormalizedCategoryName,
) -> Optional[dict[str, Any]]:
    for key in category_lookup_keys(normalized.normalized_name):
        rows = await request(
            "GET",
            "categories",
            query={
                "normalized_name": f"eq.{key}",
                "select": "*",
                "limit": "1",
            },
        )
        if rows:
            return rows[0]
    rows = await request(
        "GET",
        "categories",
        query={"name": f"eq.{normalized.display_name}", "select": "*", "limit": "1"},
    )
    if rows:
        return rows[0]
    # Last pass: plural/case forms the exact key list may still miss.
    rows = await request(
        "GET",
        "categories",
        query={"select": "*", "limit": "200"},
    )
    for row in rows:
        label = str(row.get("normalized_name") or row.get("name") or "")
        if categories_match(normalized.normalized_name, label):
            return row
    return None
