from fastapi import APIRouter, Depends, HTTPException, Query, Response

from app.dependencies import get_memory_service
from app.models.conversation import (
    ConversationResponse,
    ConversationSearchResultResponse,
    MessageResponse,
)
from app.services.durable_write_pending import proposal_from_pending_action
from app.services.durable_write_results import pending_memory_changes
from app.services.memory_service import MemoryServiceError, SupabaseMemoryService


router = APIRouter(prefix="/conversations", tags=["conversations"])


@router.get("", response_model=list[ConversationResponse])
async def list_conversations(
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> list[ConversationResponse]:
    try:
        conversations = await memory_service.list_conversations()
    except MemoryServiceError as error:
        raise _memory_http_error(error) from error

    return [
        ConversationResponse(**_public_conversation(conversation))
        for conversation in conversations
    ]


@router.post("", response_model=ConversationResponse, status_code=201)
async def create_conversation(
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> ConversationResponse:
    try:
        conversation = await memory_service.create_conversation_record()
    except MemoryServiceError as error:
        raise _memory_http_error(error) from error

    return ConversationResponse(**conversation)


@router.get("/search", response_model=list[ConversationSearchResultResponse])
async def search_conversation_messages(
    q: str = Query(min_length=1),
    limit: int = Query(default=50, ge=1, le=100),
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> list[ConversationSearchResultResponse]:
    try:
        results = await memory_service.search_conversations(q, limit=limit)
    except MemoryServiceError as error:
        raise _memory_http_error(error) from error

    return [
        ConversationSearchResultResponse(**_public_search_result(result))
        for result in results
    ]


@router.get("/{conversation_id}/messages", response_model=list[MessageResponse])
async def get_conversation_messages(
    conversation_id: str,
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> list[MessageResponse]:
    try:
        messages = await memory_service.get_conversation_messages(conversation_id)
    except MemoryServiceError as error:
        raise _memory_http_error(error) from error

    if messages is None:
        raise HTTPException(status_code=404, detail="Conversation not found.")

    return [MessageResponse(**_public_message(message)) for message in messages]


@router.get("/{conversation_id}/pending-write")
async def get_pending_write_proposal(
    conversation_id: str,
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> dict:
    try:
        pending = await memory_service.get_conversation_pending_action(conversation_id)
    except MemoryServiceError as error:
        raise _memory_http_error(error) from error

    proposal = proposal_from_pending_action(pending)
    if proposal is None:
        return {
            "confirmation_required": 0,
            "write_proposals": [],
            "plan_save_proposals": [],
        }

    from app.services.assistant_settings_repository import AssistantSettingsRepository
    from app.services.assistant_proposal_settings import resolve_assistant_proposal_settings

    user_id = getattr(memory_service, "user_id", None)
    access_token = getattr(memory_service, "access_token", None)
    if user_id and access_token:
        try:
            settings = await AssistantSettingsRepository(
                user_id=user_id,
                access_token=access_token,
            ).fetch_proposal_settings()
        except Exception:
            settings = resolve_assistant_proposal_settings({})
    else:
        settings = resolve_assistant_proposal_settings({})

    return pending_memory_changes(
        proposal=proposal,
        surface_client_cards=settings.uses_confirm_cards(),
    )


@router.delete("/{conversation_id}", status_code=204)
async def delete_conversation(
    conversation_id: str,
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> Response:
    try:
        deleted = await memory_service.delete_conversation(conversation_id)
    except MemoryServiceError as error:
        raise _memory_http_error(error) from error

    if not deleted:
        raise HTTPException(status_code=404, detail="Conversation not found.")

    return Response(status_code=204)


def _memory_http_error(error: MemoryServiceError) -> HTTPException:
    return HTTPException(status_code=error.status_code, detail=error.detail)


def _public_conversation(conversation: dict) -> dict:
    public_conversation = dict(conversation)
    last_message = public_conversation.get("last_message")
    if isinstance(last_message, dict):
        public_conversation["last_message"] = _public_message(last_message)
    return public_conversation


def _public_message(message: dict) -> dict:
    return dict(message)


def _public_search_result(result: dict) -> dict:
    public_result = dict(result)
    message = public_result.get("message")
    if isinstance(message, dict):
        public_result["message"] = _public_message(message)
    return public_result
