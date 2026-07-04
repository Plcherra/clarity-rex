from typing import Optional, Union

from fastapi import APIRouter, Depends, Query, Response

from app.dependencies import get_open_thread_service
from app.models.open_thread import (
    OpenThreadCreateRequest,
    OpenThreadResponse,
    OpenThreadStatus,
    OpenThreadUpdateRequest,
)
from app.models.pagination import PagedResponse
from app.routes.list_pagination import list_with_optional_pagination
from app.services.open_thread_service import OpenThreadService, OpenThreadServiceError


router = APIRouter(prefix="/open-threads", tags=["open-threads"])


@router.get("")
async def list_open_threads(
    status: Optional[OpenThreadStatus] = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    paginated: bool = Query(default=False),
    cursor: Optional[str] = Query(default=None),
    open_thread_service: OpenThreadService = Depends(get_open_thread_service),
) -> Union[list[OpenThreadResponse], PagedResponse[OpenThreadResponse]]:
    try:
        rows = await open_thread_service.list_threads(status=status, limit=limit)
        return [OpenThreadResponse(**row) for row in rows]
    except OpenThreadServiceError as error:
        raise _open_thread_http_error(error) from error


@router.post("", response_model=OpenThreadResponse, status_code=201)
async def create_open_thread(
    request: OpenThreadCreateRequest,
    open_thread_service: OpenThreadService = Depends(get_open_thread_service),
) -> OpenThreadResponse:
    try:
        thread = await open_thread_service.create_thread(request)
    except OpenThreadServiceError as error:
        raise _open_thread_http_error(error) from error
    return OpenThreadResponse(**thread)


@router.patch("/{thread_id}", response_model=OpenThreadResponse)
async def update_open_thread(
    thread_id: str,
    request: OpenThreadUpdateRequest,
    open_thread_service: OpenThreadService = Depends(get_open_thread_service),
) -> OpenThreadResponse:
    try:
        thread = await open_thread_service.update_thread(thread_id, request)
    except OpenThreadServiceError as error:
        raise _open_thread_http_error(error) from error
    return OpenThreadResponse(**thread)


@router.delete("/{thread_id}", status_code=204)
async def close_open_thread(
    thread_id: str,
    open_thread_service: OpenThreadService = Depends(get_open_thread_service),
) -> Response:
    try:
        await open_thread_service.close_thread(thread_id)
    except OpenThreadServiceError as error:
        raise _open_thread_http_error(error) from error
    return Response(status_code=204)


def _open_thread_http_error(error: OpenThreadServiceError):
    from fastapi import HTTPException

    return HTTPException(status_code=error.status_code, detail=error.detail)
