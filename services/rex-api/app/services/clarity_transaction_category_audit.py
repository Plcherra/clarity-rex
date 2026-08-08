"""Attach Activity-friendly category markers on single transaction updates."""

from __future__ import annotations

from typing import Any

from app.services.clarity_category_writes import (
    attach_category_move_audit_markers,
    category_names_by_id,
    RequestFn,
)


async def load_transaction_category_before(
    request: RequestFn,
    record_id: str,
) -> dict[str, Any]:
    rows = await request(
        "GET",
        "transactions",
        query={
            "id": f"eq.{record_id}",
            "select": "id,category_id",
            "limit": "1",
        },
    )
    return rows[0] if rows else {}


async def stamp_transaction_category_audit(
    request: RequestFn,
    *,
    before: dict[str, Any],
    body: dict[str, Any],
    rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    if "category_id" not in body or not rows:
        return rows
    previous_id = str(before.get("category_id") or "").strip()
    new_id = str(body.get("category_id") or "").strip()
    names = await category_names_by_id(request, {previous_id, new_id})
    attach_category_move_audit_markers(
        rows[0],
        previous_category_id=previous_id or None,
        previous_category_name=names.get(previous_id),
        category_id=new_id or None,
        category_name=names.get(new_id),
    )
    return rows
