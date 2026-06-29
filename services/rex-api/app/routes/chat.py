from typing import Optional
import json

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import ValidationError

from app.dependencies import get_chat_service
from app.models.chat import ChatRequest, ChatResponse
from app.services.ai_service import AIServiceError
from app.services.chat_service import ChatService, ConversationNotFoundError
from app.services.memory_service import MemoryServiceError


router = APIRouter()


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: Request,
    chat_service: ChatService = Depends(get_chat_service),
):
    chat_request, file = await _parse_chat_request(request)
    message = chat_request.message.strip()
    if not message and file is None:
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    if chat_request.stream:
        return StreamingResponse(
            _stream_chat_events(
                chat_service=chat_service,
                message=message,
                conversation_id=chat_request.conversation_id,
                file=file,
                financial_context=chat_request.financial_context,
                user_requested_deep_thinking=chat_request.deep_think,
                locale=chat_request.locale,
            ),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
        )

    try:
        result = await chat_service.send_message(
            message=message,
            conversation_id=chat_request.conversation_id,
            file=file,
            financial_context=chat_request.financial_context,
            user_requested_deep_thinking=chat_request.deep_think,
            locale=chat_request.locale,
        )
    except ConversationNotFoundError as error:
        raise HTTPException(status_code=404, detail="Conversation not found.") from error
    except AIServiceError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error
    except MemoryServiceError as error:
        raise HTTPException(
            status_code=error.status_code,
            detail=error.detail,
        ) from error

    return ChatResponse(
        conversation_id=result["conversation_id"],
        response=result["response"],
        messages=result["messages"],
        memory_correction=result.get("memory_correction"),
        memory_changes=result.get("memory_changes"),
    )


async def _stream_chat_events(
    chat_service: ChatService,
    message: str,
    conversation_id: Optional[str],
    file: Optional[UploadFile],
    financial_context: Optional[dict],
    user_requested_deep_thinking: bool = False,
    locale: Optional[str] = None,
):
    try:
        async for event in chat_service.stream_message(
            message=message,
            conversation_id=conversation_id,
            file=file,
            financial_context=financial_context,
            user_requested_deep_thinking=user_requested_deep_thinking,
            locale=locale,
        ):
            yield _sse_event(event.pop("event"), event)
    except ConversationNotFoundError:
        yield _sse_event("error", {"detail": "Conversation not found."})
    except AIServiceError as error:
        yield _sse_event("error", {"detail": error.detail})
    except MemoryServiceError as error:
        yield _sse_event("error", {"detail": error.detail})


def _sse_event(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data)}\n\n"


async def _parse_chat_request(request: Request) -> tuple[ChatRequest, Optional[UploadFile]]:
    content_type = request.headers.get("content-type", "")
    file: Optional[UploadFile] = None

    try:
        if content_type.startswith("multipart/form-data"):
            form = await request.form()
            message = str(form.get("message") or "")
            conversation_id_value = form.get("conversation_id")
            conversation_id = (
                str(conversation_id_value) if conversation_id_value else None
            )
            stream = _as_bool(form.get("stream"))
            locale_value = form.get("locale")
            locale = str(locale_value).strip() if locale_value else None
            file_value = form.get("file")
            if hasattr(file_value, "filename") and hasattr(file_value, "read"):
                file = file_value

            return (
                ChatRequest(
                    message=message,
                    conversation_id=conversation_id,
                    file=file.filename if file else None,
                    stream=stream,
                    financial_context=_json_dict(form.get("financial_context")),
                    deep_think=_as_bool(form.get("deep_think")),
                    locale=locale or None,
                ),
                file,
            )

        if content_type.startswith("application/json"):
            payload = await request.json()
            return ChatRequest(**payload), None
    except ValidationError as error:
        raise HTTPException(status_code=422, detail=error.errors()) from error
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid JSON body.") from error

    raise HTTPException(
        status_code=415,
        detail="Use application/json or multipart/form-data.",
    )


def _as_bool(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _json_dict(value: object) -> Optional[dict]:
    if value is None:
        return None
    if isinstance(value, dict):
        return value
    text = str(value).strip()
    if not text:
        return None
    try:
        decoded = json.loads(text)
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail="Invalid financial context.",
        ) from error
    if not isinstance(decoded, dict):
        raise HTTPException(
            status_code=422,
            detail="Financial context must be an object.",
        )
    return decoded
