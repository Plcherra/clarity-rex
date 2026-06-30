from __future__ import annotations

from typing import Awaitable, Callable, Optional, TypeVar

from app.models.pagination import PagedResponse

T = TypeVar("T")


async def list_with_optional_pagination(
    *,
    paginated: bool,
    cursor: Optional[str],
    limit: int,
    list_items: Callable[..., Awaitable[list[dict]]],
    list_paged: Callable[..., Awaitable[tuple[list[dict], Optional[str], bool]]],
    to_response: Callable[[dict], T],
) -> list[T] | PagedResponse[T]:
    if paginated:
        items, next_cursor, has_more = await list_paged(limit=limit, cursor=cursor)
        return PagedResponse(
            items=[to_response(item) for item in items],
            next_cursor=next_cursor,
            has_more=has_more,
        )

    items = await list_items(limit=limit)
    return [to_response(item) for item in items]
